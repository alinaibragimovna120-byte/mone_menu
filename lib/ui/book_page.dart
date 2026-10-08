// Техкарта изнутри: обложка, поиск, категории и сетка позиций.
// «+» — новая позиция вручную или дополнить из Excel.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/tech_card.dart';
import '../provider/menu_provider.dart';
import 'card_detail_page.dart';
import 'card_edit_page.dart';
import 'card_photo.dart';
import 'home_page.dart';
import 'import_page.dart';
import 'l10n.dart';
import 'theme.dart';

class BookPage extends StatefulWidget {
  final String bookId;
  const BookPage({super.key, required this.bookId});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  @override
  void initState() {
    super.initState();
    context.read<MenuProvider>().resetFilter();
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final book = menu.bookById(widget.bookId);
    if (book == null || book.deletedAt != null) {
      return Scaffold(body: Center(child: Text(tr('Техкарта скрыта — вернуть её можно в «Все техкарты» (значок «›» на главной)'))));
    }

    final cards = menu.visibleOf(book.id);
    final categories = menu.categoriesOf(book.id);
    final total = menu.countOf(book.id);
    final cover = menu.coverOf(book);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: tr('Добавить позицию'),
        onPressed: () => _addSheet(context, book),
        child: const Icon(Icons.add, size: 28),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'rename':
                      await renameBook(context, book);
                    case 'cover':
                      await changeCover(context, book);
                    case 'excel':
                      await openExcelImport(context, bookId: book.id);
                    case 'replace':
                      await replaceBookFromExcel(context, book);
                    case 'delete':
                      if (await deleteBook(context, book) && context.mounted) Navigator.pop(context);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'rename', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('Переименовать')))),
                  PopupMenuItem(value: 'cover', child: ListTile(leading: const Icon(Icons.image_outlined), title: Text(tr('Сменить обложку')))),
                  PopupMenuItem(value: 'excel', child: ListTile(leading: const Icon(Icons.table_view_rounded), title: Text(tr('Дополнить из Excel')))),
                  PopupMenuItem(value: 'replace', child: ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: Text(tr('Заменить из Excel')))),
                  PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.visibility_off_outlined), title: Text(tr('Скрыть с главной')))),
                ],
              ),
            ],
          ),
          // Обложка — скруглённая карточка с отступами, а не на всю ширину.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                height: 320,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
                clipBehavior: Clip.antiAlias,
                child: Stack(fit: StackFit.expand, children: [
                  WholePhoto(path: cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x10000000), Color(0xE02B1D16)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 20,
                    child: Text(book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28, height: 1.15)),
                  ),
                ]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  [
                    if (book.number.isNotEmpty) '№ ${book.number}',
                    plural(total, 'позиция', 'позиции', 'позиций'),
                    if (book.date.isNotEmpty) tr('от {date}', {'date': book.date}),
                  ].join('  ·  '),
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: menu.setQuery,
                  decoration: InputDecoration(
                    hintText: tr('Поиск по названию или ингредиенту'),
                    prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  ),
                ),
              ]),
            ),
          ),
          if (categories.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  children: [
                    _chip(tr('Все'), menu.category == null, () => menu.setCategory(null)),
                    for (final c in categories)
                      _chip(c, menu.category == c, () => menu.setCategory(c), onEdit: () => _renameCategory(book, c)),
                  ],
                ),
              ),
            ),
          if (cards.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    total == 0 ? tr('Пока нет позиций — нажмите «+»') : tr('Ничего не найдено'),
                    style: const TextStyle(color: AppColors.muted, fontSize: 16),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 230,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.74,
                ),
                itemCount: cards.length,
                itemBuilder: (_, i) => _PositionTile(card: cards[i]),
              ),
            ),
        ],
      ),
    );
  }

  /// Отдел: нажатие — фильтр, удержание / правый клик — переименовать.
  Widget _chip(String label, bool selected, VoidCallback onTap, {VoidCallback? onEdit}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onLongPress: onEdit,
          onSecondaryTap: onEdit,
          child: Tooltip(
            message: onEdit == null ? '' : tr('Удерживайте или нажмите правой кнопкой мыши, чтобы переименовать отдел'),
            waitDuration: const Duration(seconds: 1),
            child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
          ),
        ),
      );

  Future<void> _renameCategory(TechBook book, String category) async {
    final menu = context.read<MenuProvider>();
    final others = menu.categoriesOf(book.id).where((c) => c != category).join(', ');
    final name = await askText(
      context,
      title: tr('Переименовать отдел'),
      initial: category,
      helper: others.isEmpty ? null : tr('Чтобы объединить с другим отделом, введите его название: {list}', {'list': others}),
    );
    if (name == null || name == category) return;
    await menu.renameCategory(book.id, category, name);
  }

  void _addSheet(BuildContext context, TechBook book) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Добавить'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SheetOption(
              icon: Icons.edit_note_rounded,
              title: tr('Новая позиция'),
              subtitle: tr('Название, фото, состав, выход'),
              onTap: () {
                Navigator.pop(sheet);
                Navigator.push(context, MaterialPageRoute(builder: (_) => CardEditPage(bookId: book.id)));
              },
            ),
            const SizedBox(height: 10),
            ExcelDropOption(
              title: tr('Дополнить из Excel'),
              subtitle: tr('Новые позиции добавятся, совпадающие обновятся'),
              onPick: () {
                Navigator.pop(sheet);
                openExcelImport(context, bookId: book.id);
              },
              onFile: (name, read) {
                Navigator.pop(sheet);
                importExcelFile(context, name, read, bookId: book.id);
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _PositionTile extends StatelessWidget {
  final TechCard card;
  const _PositionTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailPage(cardId: card.id))),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Hero(
                    tag: 'photo-${card.id}',
                    child: CardPhoto(path: card.photos.isEmpty ? null : card.photos.first),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(card.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.2)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(
                      child: Text(card.category,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ),
                    if (card.yieldText.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.latte, borderRadius: BorderRadius.circular(8)),
                        child: Text(trData(card.yieldText),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.espresso)),
                      ),
                    ],
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
