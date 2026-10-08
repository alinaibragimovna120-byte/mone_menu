// Главная: сетка техкарт (каждая — отдельный Excel-сборник) с обложками.
// Кнопка «+» — добавить новую техкарту из Excel или пустую.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/tech_card.dart';
import '../provider/menu_provider.dart';
import '../services/menu_sync.dart';
import 'all_books_page.dart';
import 'book_page.dart';
import 'card_photo.dart';
import 'import_page.dart';
import 'l10n.dart';
import 'server_page.dart';
import 'theme.dart';

export 'l10n.dart' show plural;

/// Отступ от краёв главной: на широком экране больше, на телефоне — меньше.
double homeGutter(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= 1000 ? 56 : (w >= 600 ? 36 : 20);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final books = menu.books;
    final total = books.fold<int>(0, (s, b) => s + menu.countOf(b.id));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: tr('Добавить техкарту'),
        onPressed: () => showAddBookSheet(context),
        child: const Icon(Icons.add, size: 28),
      ),
      body: menu.loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(books: books.length, positions: total, deleted: menu.deletedBooks.length)),
                if (books.isEmpty)
                  const SliverFillRemaining(hasScrollBody: false, child: _EmptyHome())
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(homeGutter(context), 4, homeGutter(context), 120),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 18,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: books.length,
                      itemBuilder: (_, i) => _BookTile(book: books[i]),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final int books;
  final int positions;
  final int deleted;
  const _Header({required this.books, required this.positions, required this.deleted});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(homeGutter(context), 24, homeGutter(context), 20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.espresso,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.soft,
              ),
              alignment: Alignment.center,
              child: const Text('M',
                  style: TextStyle(color: AppColors.latte, fontSize: 26, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mone Menu',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text(
                    books == 0
                        ? tr('Техкарты и меню')
                        : '${plural(books, 'техкарта', 'техкарты', 'техкарт')} · ${plural(positions, 'позиция', 'позиции', 'позиций')}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ],
              ),
            ),
            const _LangSwitch(),
            IconButton(
              tooltip: tr('Сервер — вход и синхронизация'),
              onPressed: () => openServerPage(context),
              icon: Icon(
                context.watch<MenuSync>().loggedIn ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                size: 26,
              ),
            ),
            if (books + deleted > 0)
              IconButton(
                tooltip: tr('Все техкарты — выбрать, какие видны на главной'),
                onPressed: () => openAllBooks(context),
                icon: const Icon(Icons.chevron_right_rounded, size: 32),
              ),
          ],
        ),
      ),
    );
  }
}

/// Переключатель языка интерфейса: RU | UZ.
class _LangSwitch extends StatelessWidget {
  const _LangSwitch();

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LangController>();
    return Tooltip(
      message: tr('Язык'),
      child: SegmentedButton<AppLang>(
        segments: [for (final l in AppLang.values) ButtonSegment(value: l, label: Text(l.code))],
        selected: {lang.lang},
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.espresso,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppColors.line),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        onSelectionChanged: (s) => lang.set(s.first),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final TechBook book;
  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final cover = menu.coverOf(book);
    final count = menu.countOf(book.id);

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: AppShadows.soft),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: AppColors.espresso,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookPage(bookId: book.id))),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CardPhoto(path: cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Colors.transparent, Color(0xE62B1D16)],
                    ),
                  ),
                ),
                if (book.number.isNotEmpty)
                  Positioned(
                    left: 14,
                    top: 14,
                    child: _Badge(text: '№ ${book.number}'),
                  ),
                Positioned(right: 6, top: 6, child: _BookMenu(book: book)),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.15),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [plural(count, 'позиция', 'позиции', 'позиций'), if (book.date.isNotEmpty) book.date]
                            .join('  ·  '),
                        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.espresso)),
      );
}

class _BookMenu extends StatelessWidget {
  final TechBook book;
  const _BookMenu({required this.book});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
      ),
      onSelected: (v) => switch (v) {
        'rename' => renameBook(context, book),
        'cover' => changeCover(context, book),
        'replace' => replaceBookFromExcel(context, book),
        'delete' => deleteBook(context, book),
        _ => null,
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'rename', child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('Переименовать')))),
        PopupMenuItem(value: 'cover', child: ListTile(leading: const Icon(Icons.image_outlined), title: Text(tr('Сменить обложку')))),
        PopupMenuItem(value: 'replace', child: ListTile(leading: const Icon(Icons.swap_horiz_rounded), title: Text(tr('Заменить из Excel')))),
        PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.visibility_off_outlined), title: Text(tr('Скрыть с главной')))),
      ],
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(color: AppColors.latte, shape: BoxShape.circle),
              child: const Icon(Icons.coffee_rounded, size: 52, color: AppColors.espresso),
            ),
            const SizedBox(height: 22),
            Text(tr('Здесь будут ваши техкарты'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              tr('Нажмите «+» и выберите Excel-файл техкарты —\nпозиции, состав и фото загрузятся автоматически'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => openExcelImport(context),
              icon: const Icon(Icons.upload_file),
              label: Text(tr('Загрузить из Excel')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => createBookManually(context),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(tr('Создать вручную')),
            ),
            if (context.watch<MenuProvider>().deletedBooks.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => openAllBooks(context),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(tr('Показать скрытые техкарты')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------- действия с техкартой ----------

Future<void> showAddBookSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Новая техкарта'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ExcelDropOption(
              title: tr('Загрузить из Excel'),
              subtitle: tr('Файл .xlsx в формате техкарты Mone'),
              onPick: () {
                Navigator.pop(sheet);
                openExcelImport(context);
              },
              onFile: (name, read) {
                Navigator.pop(sheet);
                importExcelFile(context, name, read);
              },
            ),
            const SizedBox(height: 10),
            SheetOption(
              icon: Icons.edit_note_rounded,
              title: tr('Создать вручную'),
              subtitle: tr('Название и позиции заполните сами'),
              onTap: () {
                Navigator.pop(sheet);
                createBookManually(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Новая техкарта без Excel: спросить название и открыть её — позиции через «+».
Future<void> createBookManually(BuildContext context) async {
  final title = await askText(context, title: tr('Название техкарты'), hint: tr('Например: Десерты'));
  if (title == null || !context.mounted) return;
  final book = await context.read<MenuProvider>().createBook(title: title);
  if (context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BookPage(bookId: book.id)));
  }
}

/// Заменить все позиции техкарты позициями из другого Excel-файла
/// (прежняя версия уходит в скрытые).
Future<void> replaceBookFromExcel(BuildContext context, TechBook book) async {
  final menu = context.read<MenuProvider>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('Заменить техкарту?')),
      content: Text(tr(
        'Текущие позиции «{title}» ({count}) уйдут в скрытые, а вместо них загрузятся позиции из нового Excel-файла.',
        {'title': book.title, 'count': menu.countOf(book.id)},
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Отмена'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Выбрать файл'))),
      ],
    ),
  );
  if (ok == true && context.mounted) await openExcelImport(context, bookId: book.id, replace: true);
}

class SheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SheetOption({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.latte, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.espresso),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ]),
          ),
        ),
      );
}

Future<String?> askText(BuildContext context,
    {required String title, String initial = '', String? hint, String? helper}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint, helperText: helper, helperMaxLines: 3),
        onSubmitted: (v) => Navigator.pop(c, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Отмена'))),
        FilledButton(
          onPressed: () => Navigator.pop(c, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
          child: Text(tr('Готово')),
        ),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}

Future<void> renameBook(BuildContext context, TechBook book) async {
  final title = await askText(context, title: tr('Переименовать'), initial: book.title);
  if (title == null || !context.mounted) return;
  await context.read<MenuProvider>().updateBook(book.copyWith(title: title));
}

Future<void> changeCover(BuildContext context, TechBook book) async {
  final menu = context.read<MenuProvider>();
  final res = await FilePicker.pickFiles(type: FileType.image);
  if (res.isEmpty) return;
  final bytes = await res.first.xFile.readAsBytes();
  final path = await menu.storage.savePhoto(bytes, (res.first.extension ?? 'png').replaceFirst('.', ''));
  await menu.updateBook(book.copyWith(cover: path));
}

/// Скрыть техкарту с главной (вернуть можно в «Все техкарты»). true — скрыли.
Future<bool> deleteBook(BuildContext context, TechBook book) async {
  final menu = context.read<MenuProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('Скрыть техкарту?')),
      content: Text(tr(
        '«{title}» ({count}) пропадёт с главной. Вернуть её можно через значок «›» → «Все техкарты».',
        {'title': book.title, 'count': plural(menu.countOf(book.id), 'позиция', 'позиции', 'позиций')},
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Отмена'))),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(tr('Скрыть')),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await menu.deleteBook(book.id);
  messenger.showSnackBar(SnackBar(
    content: Text(tr('«{title}» скрыта с главной', {'title': book.title})),
    action: SnackBarAction(label: tr('Вернуть'), onPressed: () => menu.restoreBook(book.id)),
  ));
  return true;
}
