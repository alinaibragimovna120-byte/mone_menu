// «Все техкарты»: все техкарты, которые когда-либо добавляли, — и те, что на
// главной, и скрытые (удалённые или заменённые). Переключатель «На главной»
// показывает техкарту на главной или скрывает её обратно; скрытую можно
// удалить навсегда.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/tech_card.dart';
import '../provider/menu_provider.dart';
import 'card_photo.dart';
import 'l10n.dart';
import 'theme.dart';

Future<void> openAllBooks(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AllBooksPage()));

class AllBooksPage extends StatelessWidget {
  const AllBooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuProvider>();
    final shown = menu.books;
    final hidden = menu.deletedBooks;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Все техкарты'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              Text(
                tr('Включите «На главной», чтобы техкарта была видна на главной странице, '
                    'или выключите, чтобы скрыть её. Позиции и фото скрытой техкарты сохраняются.'),
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
              if (shown.isNotEmpty) ...[
                const SizedBox(height: 20),
                SectionTitle(tr('На главной · {n}', {'n': shown.length})),
                for (final b in shown) ...[_BookRow(book: b), const SizedBox(height: 10)],
              ],
              if (hidden.isNotEmpty) ...[
                const SizedBox(height: 20),
                SectionTitle(tr('Скрытые · {n}', {'n': hidden.length})),
                for (final b in hidden) ...[_BookRow(book: b), const SizedBox(height: 10)],
              ],
              if (shown.isEmpty && hidden.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(tr('Пока нет ни одной техкарты'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final TechBook book;
  const _BookRow({required this.book});

  @override
  Widget build(BuildContext context) {
    final menu = context.read<MenuProvider>();
    final count = menu.countOf(book.id);
    final visible = book.deletedAt == null;
    String? hiddenAt;
    if (!visible) {
      final d = book.deletedAt!.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      hiddenAt = tr('Скрыта {date}', {'date': '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}'});
    }

    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Opacity(
            opacity: visible ? 1 : 0.55,
            child: SizedBox(width: 64, height: 64, child: CardPhoto(path: menu.coverOf(book))),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              [if (book.number.isNotEmpty) '№ ${book.number}', book.title].join('  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              [plural(count, 'позиция', 'позиции', 'позиций'), if (book.date.isNotEmpty) book.date].join('  ·  '),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (hiddenAt != null) Text(hiddenAt, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Switch(
            value: visible,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.espresso,
            onChanged: (on) => on ? menu.restoreBook(book.id) : menu.deleteBook(book.id),
          ),
          Text(tr('На главной'), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
        if (!visible)
          IconButton(
            tooltip: tr('Удалить навсегда'),
            onPressed: () => _purge(context, menu, count),
            icon: const Icon(Icons.delete_forever_outlined, color: Color(0xFFB3412E)),
          ),
      ]),
    );
  }

  Future<void> _purge(BuildContext context, MenuProvider menu, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Удалить навсегда?')),
        content: Text(tr('«{title}» и все её позиции ({count}) вместе с фото будут удалены без возможности восстановления.', {'title': book.title, 'count': count})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Отмена'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3412E)),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Удалить')),
          ),
        ],
      ),
    );
    if (ok == true) await menu.purgeBook(book.id);
  }
}
