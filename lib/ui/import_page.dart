// Импорт из Excel: выбрать файл → сразу создать новую техкарту
// (название из имени файла, обложка — первое фото) или дополнить существующую.

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/tech_card.dart';
import '../provider/menu_provider.dart';
import '../services/paste_files.dart';
import '../services/text_fixes.dart';
import '../services/xlsx_tech_card_parser.dart';
import 'book_page.dart';
import 'home_page.dart' show SheetOption;
import 'l10n.dart';
import 'theme.dart';

/// Выбрать Excel и сразу импортировать все позиции. [bookId] — дополнить эту техкарту,
/// null — создать новую. [replace] — заменить все позиции техкарты [bookId].
Future<void> openExcelImport(BuildContext context, {String? bookId, bool replace = false}) async {
  final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
  if (res.isEmpty || !context.mounted) return;
  await importExcelFile(context, res.first.name, res.first.xFile.readAsBytes, bookId: bookId, replace: replace);
}

/// Импорт уже полученного файла (выбран, перетащен или вставлен по Ctrl+V).
Future<void> importExcelFile(
  BuildContext context,
  String name,
  Future<Uint8List> Function() readBytes, {
  String? bookId,
  bool replace = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final lower = name.toLowerCase();
  if (lower.endsWith('.xls')) {
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(tr('Формат .xls не поддерживается. Откройте файл в Excel → «Сохранить как» → «Книга Excel (*.xlsx)».')),
    ));
    return;
  }
  if (!lower.endsWith('.xlsx')) {
    messenger.showSnackBar(SnackBar(content: Text(tr('«{name}» — не Excel-файл. Нужен файл .xlsx', {'name': name}))));
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: SoftCard(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(tr('Читаю техкарту…'), style: const TextStyle(fontSize: 15, decoration: TextDecoration.none)),
        ]),
      ),
    ),
  );
  List<ParsedCard>? cards;
  Object? error;
  try {
    final bytes = await readBytes();
    cards = await compute(XlsxTechCardParser.parse, bytes);
  } catch (e) {
    error = e;
  }
  if (!context.mounted) return;
  Navigator.pop(context); // закрыть загрузку

  if (error != null || cards == null || cards.isEmpty) {
    messenger.showSnackBar(SnackBar(
      content: Text(error != null ? tr('Не удалось прочитать файл: {error}', {'error': error}) : tr('В файле не найдено техкарт')),
    ));
    return;
  }
  final menu = context.read<MenuProvider>();
  if (replace && bookId != null) {
    final added = await menu.replaceBook(bookId, cards, name);
    messenger.showSnackBar(SnackBar(content: Text(tr('Техкарта заменена · {count}', {'count': plural(added, 'позиция', 'позиции', 'позиций')}))));
    return;
  }
  final String id;
  if (bookId == null) {
    final (rawTitle, number, date) = TechBook.parseFileName(name);
    final title = fixTypos(rawTitle);
    id = (await menu.createBook(title: title, number: number, date: date, sourceFile: name)).id;
  } else {
    id = bookId;
  }
  final cover = cards.indexWhere((c) => c.images.isNotEmpty);
  final (added, updated) = await menu.importCards(
    cards,
    id,
    name,
    coverIndex: bookId == null && cover >= 0 ? cover : null,
  );
  if (!context.mounted) return;
  messenger.showSnackBar(SnackBar(
    content: Text(updated == 0 ? tr('Добавлено позиций: {n}', {'n': added}) : tr('Добавлено: {added}, обновлено: {updated}', {'added': added, 'updated': updated})),
  ));
  if (bookId == null) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BookPage(bookId: id)));
  }
}

/// Пункт «Загрузить из Excel» в окне «+»: нажать — выбрать файл, или
/// перетащить файл на него, или вставить скопированный файл по Ctrl+V.
class ExcelDropOption extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onPick;
  final void Function(String name, Future<Uint8List> Function() readBytes) onFile;

  const ExcelDropOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPick,
    required this.onFile,
  });

  @override
  State<ExcelDropOption> createState() => _ExcelDropOptionState();
}

class _ExcelDropOptionState extends State<ExcelDropOption> {
  bool _over = false;
  late final VoidCallback _stopPaste;

  // Подсказка про перетаскивание и Ctrl+V — там, где есть мышь и клавиатура.
  static final _desktop = kIsWeb ||
      const {TargetPlatform.windows, TargetPlatform.macOS, TargetPlatform.linux}.contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    _stopPaste = listenPastedFiles((name, bytes) => widget.onFile(name, () async => bytes));
  }

  @override
  void dispose() {
    _stopPaste();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paste = defaultTargetPlatform == TargetPlatform.macOS ? '⌘V' : 'Ctrl+V';
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (d) {
        setState(() => _over = false);
        if (d.files.isEmpty) return;
        final f = d.files.first;
        widget.onFile(f.name, f.readAsBytes);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _over ? AppColors.caramel : Colors.transparent, width: 2),
        ),
        child: SheetOption(
          icon: _over ? Icons.file_download_outlined : Icons.table_view_rounded,
          title: _over ? tr('Отпустите файл здесь') : widget.title,
          subtitle: _desktop
              ? tr('{subtitle}\nили перетащите файл сюда · {paste} — вставить', {'subtitle': widget.subtitle, 'paste': paste})
              : widget.subtitle,
          onTap: widget.onPick,
        ),
      ),
    );
  }
}
