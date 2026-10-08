// Импорт техкарт из Excel (.xlsx). Без Flutter-зависимостей — можно гонять
// через `dart test`.
//
// Формат техкарты Mone (как в «№ 1 Техкарта Бар Чай Кофе»):
//   * на листе несколько карт, каждая занимает 3 колонки (обычно B–D и F–H);
//   * шапка — объединённая ячейка «Название  415 гр» (название + выход);
//   * ниже строки: ингредиент | ед. (гр/шт/мл) | количество в КГ (0.045 = 45 гр);
//   * строки без количества — заметки («Экстракция 3 мин», «Объем чашки …»);
//   * шапка «С собой 477 гр» — второй вариант той же позиции;
//   * фото лежат над картой в той же колонке.
//
// xlsx читаем сами (zip + xml), т.к. готовые пакеты не отдают картинки.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../ui/models/tech_card.dart';
import 'text_fixes.dart';

class ParsedImage {
  final Uint8List bytes;
  final String ext;
  const ParsedImage(this.bytes, this.ext);
}

class ParsedCard {
  final String name;
  final String category;
  final String sheet;
  final List<CardVariant> variants;
  final List<ParsedImage> images;

  ParsedCard({
    required this.name,
    required this.category,
    required this.sheet,
    required this.variants,
    required this.images,
  });
}

class XlsxTechCardParser {
  static const _units = {
    'гр': 'гр',
    'г': 'гр',
    'gr': 'гр',
    'мл': 'мл',
    'ml': 'мл',
    'шт': 'шт',
    'дона': 'шт',
    'кг': 'кг',
    'л': 'л',
  };

  /// Разбирает файл и возвращает найденные карты по всем листам.
  static List<ParsedCard> parse(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    final book = _Book(zip);
    final result = <ParsedCard>[];
    String? lastCategory;
    for (final sheet in book.sheets) {
      // Лист без имени («Лист3», «Sheet2») — продолжение предыдущей категории.
      final unnamed = RegExp(r'^\s*(лист|sheet)\s*\d*\s*$', caseSensitive: false).hasMatch(sheet.name);
      var category = unnamed && lastCategory != null ? lastCategory : _categoryFromSheet(sheet.name);
      // «Лимонад» / «Лимонады» / «лимонады (2)» — один отдел.
      for (final c in result) {
        if (sameCategory(c.category, category)) {
          category = c.category;
          break;
        }
      }
      final cards = _parseSheet(book, sheet, category);
      if (cards.isNotEmpty) lastCategory = category;
      result.addAll(cards);
    }
    return _mergeSplit(result);
  }

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  static final _takeawaySuffix = RegExp(r'[\s(–-]*(с\s*собой|на\s*вынос)\)?\s*$', caseSensitive: false);

  static String _nameKey(String s) => s
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'\s*-\s*'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Один напиток, разбитый в Excel на несколько карт, — в одну карту с вариантами:
  /// «Фруктово-ванильный с собой» → вариант «С собой 2» у «Фруктово-ванильный»;
  /// «МОХИТО» 1,4 кг и «МОХИТО» 453 гр (кувшин / стакан) → варианты по выходу.
  /// Без фото и с другим названием, но тем же составом на том же листе
  /// («Морковно-яблочный» 220 мл к «Яблочный-морковный фреш» 400 мл) — тоже.
  static List<ParsedCard> _mergeSplit(List<ParsedCard> cards) {
    final out = <ParsedCard>[];
    Set<String> ingredients(ParsedCard c) => {for (final i in c.variants.first.ingredients) _nameKey(i.name)};
    for (final c in cards) {
      final takeaway = _takeawaySuffix.hasMatch(c.name);
      final key = _nameKey(c.name.replaceFirst(_takeawaySuffix, ''));
      var target = out.where((o) => o.category == c.category && _nameKey(o.name) == key).firstOrNull;
      if (target == null && !takeaway && c.images.isEmpty) {
        final same = out.where((o) =>
            o.sheet == c.sheet &&
            o.images.isNotEmpty &&
            o.variants.length == 1 &&
            o.variants.first.yieldText != c.variants.first.yieldText &&
            _sameSet(ingredients(o), ingredients(c)));
        if (same.length == 1) target = same.first;
      }
      if (target == null) {
        out.add(c);
        continue;
      }
      final variants = target.variants;
      if (takeaway) {
        for (final v in c.variants) {
          final n = variants.where((x) => x.title.startsWith('С собой')).length;
          variants.add(v.copyWith(title: n == 0 ? 'С собой' : 'С собой ${n + 1}'));
        }
      } else {
        // Варианты одного напитка разного объёма называем по выходу.
        final first = variants.first;
        if (first.title == 'Основной' && first.yieldText.isNotEmpty) variants[0] = first.copyWith(title: first.yieldText);
        for (final v in c.variants) {
          final title = v.title == 'Основной' ? (v.yieldText.isEmpty ? 'Вариант ${variants.length + 1}' : v.yieldText) : v.title;
          variants.add(v.copyWith(title: title));
        }
      }
      target.images.addAll(c.images);
    }
    return out;
  }

  static List<ParsedCard> _parseSheet(_Book book, _SheetRef ref, String category) {
    final doc = book.xml(ref.path);
    if (doc == null) return [];

    final grid = <int, Map<int, Object>>{};
    var maxRow = 0;
    for (final c in _all(doc.rootElement, 'c')) {
      final pos = _cellPos(c.getAttribute('r') ?? '');
      if (pos == null) continue;
      final value = _cellValue(c, book.sharedStrings);
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      grid.putIfAbsent(pos.$1, () => {})[pos.$2] = value;
      if (pos.$1 > maxRow) maxRow = pos.$1;
    }

    String text(int r, int c) {
      final v = grid[r]?[c];
      if (v == null) return '';
      if (v is double) return formatAmount(v);
      return _clean(v.toString());
    }

    double? number(int r, int c) {
      final v = grid[r]?[c];
      if (v is double) return v;
      if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
      return null;
    }

    String? unit(int r, int c) => _units[text(r, c).toLowerCase().replaceAll('.', '')];

    bool isIngredientRow(int r, int c) =>
        text(r, c).isNotEmpty && unit(r, c + 1) != null && number(r, c + 2) != null;

    // --- шапки карт ---
    final headers = <(int, int)>{};
    for (final m in _all(doc.rootElement, 'mergeCell')) {
      final parts = (m.getAttribute('ref') ?? '').split(':');
      if (parts.length != 2) continue;
      final a = _cellPos(parts[0]), b = _cellPos(parts[1]);
      if (a == null || b == null) continue;
      if (a.$1 == b.$1 && b.$2 - a.$2 >= 2 && _isHeaderText(text(a.$1, a.$2))) {
        headers.add((a.$1, a.$2));
      }
    }
    // Запасной вариант без объединения: текст, справа пусто, ниже — ингредиент.
    grid.forEach((r, row) {
      row.forEach((c, _) {
        if (_isHeaderText(text(r, c)) &&
            text(r, c + 1).isEmpty &&
            text(r, c + 2).isEmpty &&
            isIngredientRow(r + 1, c)) {
          headers.add((r, c));
        }
      });
    });
    if (headers.isEmpty) return [];

    final byColumn = <int, List<int>>{};
    for (final h in headers) {
      byColumn.putIfAbsent(h.$2, () => []).add(h.$1);
    }

    // карты по колонкам: (строка шапки, builder)
    final cardsByColumn = <int, List<(int, _CardBuilder)>>{};
    for (final entry in byColumn.entries) {
      final col = entry.key;
      final rows = entry.value..sort();
      final cards = <(int, _CardBuilder)>[];
      for (var i = 0; i < rows.length; i++) {
        final hr = rows[i];
        final end = i + 1 < rows.length ? rows[i + 1] - 1 : maxRow;
        final (title, yieldText) = _splitHeader(text(hr, col));

        final ingredients = <Ingredient>[];
        final notes = <String>[];
        var empty = 0;
        for (var r = hr + 1; r <= end; r++) {
          final name = text(r, col);
          if (name.isEmpty) {
            if (++empty >= 6) break;
            continue;
          }
          empty = 0;
          final u = unit(r, col + 1);
          final q = number(r, col + 2);
          if (u != null && q != null) {
            ingredients.add(Ingredient(name: name, unit: u, amount: _toDisplayAmount(u, q)));
          } else {
            final extra = [text(r, col + 1), text(r, col + 2)].where((s) => s.isNotEmpty);
            notes.add([name, ...extra].join(' '));
          }
        }

        final isTakeaway = RegExp(r'^(с\s*собой|на\s*вынос)', caseSensitive: false).hasMatch(title);
        if (isTakeaway && cards.isNotEmpty) {
          final n = cards.last.$2.variants.where((v) => v.title.startsWith('С собой')).length;
          cards.last.$2.variants.add(CardVariant(
            title: n == 0 ? 'С собой' : 'С собой ${n + 1}',
            yieldText: yieldText,
            ingredients: ingredients,
            notes: notes,
          ));
        } else {
          cards.add((
            hr,
            _CardBuilder(title, [
              CardVariant(
                title: 'Основной',
                yieldText: yieldText,
                ingredients: ingredients,
                notes: notes,
              ),
            ]),
          ));
        }
      }
      cardsByColumn[col] = cards;
    }

    // --- фото: в ближайшую колонку, к первой карте под картинкой ---
    // Шапка, которую картинка закрывает собой (старый блок под фото), — не её карта:
    // берём первую карту ниже нижнего края картинки (с запасом в строку).
    for (final img in book.images(ref)) {
      int? bestCol;
      for (final col in cardsByColumn.keys) {
        if (bestCol == null || (img.col - col).abs() < (img.col - bestCol).abs()) bestCol = col;
      }
      final cards = cardsByColumn[bestCol];
      if (cards == null || cards.isEmpty) continue;
      final target = cards.firstWhere((c) => c.$1 >= img.bottom - 1,
          orElse: () => cards.firstWhere((c) => c.$1 >= img.row, orElse: () => cards.last));
      target.$2.images.add(img.image);
    }

    final out = <ParsedCard>[];
    final cols = cardsByColumn.keys.toList()..sort();
    // Порядок как в Excel: сверху вниз, слева направо.
    final all = [
      for (final col in cols)
        for (final c in cardsByColumn[col]!) (c.$1, col, c.$2),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    for (final c in all) {
      final b = c.$3;
      if (b.name.isEmpty) continue;
      if (b.variants.every((v) => v.ingredients.isEmpty)) continue;
      out.add(ParsedCard(
        name: fixTypos(b.name),
        category: fixTypos(category),
        sheet: ref.name.trim(),
        variants: [for (final v in b.variants) fixVariant(v)],
        images: b.images,
      ));
    }
    return out;
  }

  /// В техкарте гр/мл записаны в кг/л (0.045 = 45 гр). Если число уже
  /// большое (≥ 5) — считаем, что записано в граммах.
  static double _toDisplayAmount(String unit, double v) {
    if ((unit == 'гр' || unit == 'мл') && v < 5) {
      return (v * 1000 * 100).roundToDouble() / 100;
    }
    return v;
  }

  // Строки «Объем чашки …», «Экстракция …» бывают объединены как шапка — это заметки.
  // «Сироп по вкусу» — подзаголовок внутри карты напитка: сиропы под ним идут в её состав.
  static final _noteLike = RegExp(r'^(объ[её]м|обём|экстракц|паровая)|по\s*вкусу', caseSensitive: false);

  static bool _isHeaderText(String s) =>
      s.isNotEmpty && !_noteLike.hasMatch(s) && double.tryParse(s.replaceAll(',', '.')) == null && RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(s);

  /// «Фруктово-ванильный  955 гр» → («Фруктово-ванильный», «955 гр»).
  static (String, String) _splitHeader(String s) {
    final m = RegExp(r'^(.*?)[\s.,]*(\d+(?:[.,]\d+)?)\s*(гр|г|мл|ml|gr|шт)\.?\s*$', caseSensitive: false)
        .firstMatch(s);
    if (m == null) {
      // «Flat White 197» — выход без единицы, считаем граммами.
      final n = RegExp(r'^(.*\D)\s+(\d{2,4})$').firstMatch(s);
      if (n != null && n.group(1)!.trim().length > 1) return (n.group(1)!.trim(), '${n.group(2)} гр');
      return (s, '');
    }
    if (m.group(1)!.trim().isEmpty) return (s, '');
    final unit = _units[m.group(3)!.toLowerCase()] ?? m.group(3)!;
    return (m.group(1)!.trim(), '${m.group(2)} $unit');
  }

  /// «Чайник 3,» → «Чайник», «кофе 1» → «Кофе».
  static String _categoryFromSheet(String sheet) {
    var s = sheet.replaceAll(RegExp(r'[\s\d,.;_()№#-]+$'), '').trim();
    if (s.isEmpty) s = sheet.trim();
    return s.isEmpty ? 'Без категории' : s[0].toUpperCase() + s.substring(1);
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static Object? _cellValue(XmlElement c, List<String> shared) {
    final t = c.getAttribute('t');
    if (t == 'inlineStr') {
      return _all(c, 't').map((e) => e.innerText).join();
    }
    final v = _first(c, 'v')?.innerText;
    if (v == null) return null;
    if (t == 's') {
      final i = int.tryParse(v);
      return i != null && i < shared.length ? shared[i] : null;
    }
    if (t == 'str' || t == 'e' || t == 'b') return v;
    return double.tryParse(v) ?? v;
  }

  /// «AB12» → (row 11, col 27), 0-based.
  static (int, int)? _cellPos(String ref) {
    final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(ref.replaceAll(r'$', ''));
    if (m == null) return null;
    var col = 0;
    for (final ch in m.group(1)!.codeUnits) {
      col = col * 26 + (ch - 64);
    }
    return (int.parse(m.group(2)!) - 1, col - 1);
  }
}

class _CardBuilder {
  final String name;
  final List<CardVariant> variants;
  final List<ParsedImage> images = [];
  _CardBuilder(this.name, this.variants);
}

class _SheetRef {
  final String name;
  final String path;
  _SheetRef(this.name, this.path);
}

class _AnchoredImage {
  final int row;
  final int col;
  final int bottom; // строка, где кончается картинка
  final ParsedImage image;
  _AnchoredImage(this.row, this.col, this.bottom, this.image);
}

/// Обёртка над zip-архивом xlsx.
class _Book {
  final Archive zip;
  late final List<String> sharedStrings = _loadShared();
  late final List<_SheetRef> sheets = _loadSheets();

  _Book(this.zip);

  XmlDocument? xml(String path) {
    final f = zip.findFile(path);
    if (f == null) return null;
    return XmlDocument.parse(utf8.decode(f.content, allowMalformed: true));
  }

  List<String> _loadShared() {
    final doc = xml('xl/sharedStrings.xml');
    if (doc == null) return [];
    return [
      for (final si in _all(doc.rootElement, 'si'))
        // rPh — фонетические подсказки, их не берём
        si.descendantElements
            .where((e) => e.name.local == 't' && e.parentElement?.name.local != 'rPh')
            .map((e) => e.innerText)
            .join(),
    ];
  }

  Map<String, String> _rels(String relsPath, String baseDir) {
    final doc = xml(relsPath);
    if (doc == null) return {};
    return {
      for (final r in _all(doc.rootElement, 'Relationship'))
        r.getAttribute('Id') ?? '': _resolve(baseDir, r.getAttribute('Target') ?? ''),
    };
  }

  List<_SheetRef> _loadSheets() {
    final doc = xml('xl/workbook.xml');
    if (doc == null) return [];
    final rels = _rels('xl/_rels/workbook.xml.rels', 'xl');
    return [
      for (final s in _all(doc.rootElement, 'sheet'))
        if (rels[_rid(s)] != null) _SheetRef(s.getAttribute('name') ?? '', rels[_rid(s)]!),
    ];
  }

  List<_AnchoredImage> images(_SheetRef sheet) {
    final dir = sheet.path.substring(0, sheet.path.lastIndexOf('/'));
    final file = sheet.path.substring(sheet.path.lastIndexOf('/') + 1);
    final sheetDoc = xml(sheet.path);
    if (sheetDoc == null) return [];
    final sheetRels = _rels('$dir/_rels/$file.rels', dir);
    final size = _CellSizes(sheetDoc);
    final out = <_AnchoredImage>[];
    for (final d in _all(sheetDoc.rootElement, 'drawing')) {
      final drawingPath = sheetRels[_rid(d)];
      if (drawingPath == null) continue;
      final dDir = drawingPath.substring(0, drawingPath.lastIndexOf('/'));
      final dFile = drawingPath.substring(drawingPath.lastIndexOf('/') + 1);
      final drawing = xml(drawingPath);
      if (drawing == null) continue;
      final dRels = _rels('$dDir/_rels/$dFile.rels', dDir);
      for (final anchor in drawing.rootElement.childElements) {
        final from = _first(anchor, 'from');
        final blip = _first(anchor, 'blip');
        if (from == null || blip == null) continue;
        final embed = blip.attributes
            .firstWhere((a) => a.name.local == 'embed', orElse: () => XmlAttribute(XmlName.parts('x'), ''))
            .value;
        final media = dRels[embed];
        final f = media == null ? null : zip.findFile(media);
        if (f == null) continue;
        int num(XmlElement e, String tag) => int.tryParse(_first(e, tag)?.innerText ?? '') ?? 0;
        // Картинка может быть привязана к A1 с большим сдвигом (rowOff/colOff в EMU) —
        // переводим сдвиг в настоящую строку и колонку по размерам ячеек листа.
        final row = _skip(num(from, 'row'), num(from, 'rowOff'), size.rowEmu);
        final col = _skip(num(from, 'col'), num(from, 'colOff'), size.colEmu);
        // Нижний край: по <to> (twoCellAnchor) или по высоте картинки <ext cy> (oneCellAnchor).
        final to = _first(anchor, 'to');
        final height = int.tryParse(_first(anchor, 'ext')?.getAttribute('cy') ?? '') ?? 0;
        final bottom = to != null
            ? _skip(num(to, 'row'), num(to, 'rowOff'), size.rowEmu)
            : _skip(num(from, 'row'), num(from, 'rowOff') + height, size.rowEmu);
        final ext = media!.split('.').last.toLowerCase();
        out.add(_AnchoredImage(row, col, bottom, ParsedImage(Uint8List.fromList(f.content), ext)));
      }
    }
    return out;
  }

  /// Строка/колонка [index], сдвинутая на [offset] EMU вперёд по размерам [sizeOf].
  static int _skip(int index, int offset, int Function(int) sizeOf) {
    while (offset > 0 && index < 10000) {
      final s = sizeOf(index);
      if (offset < s) break;
      offset -= s;
      index++;
    }
    return index;
  }

  static String _rid(XmlElement e) =>
      e.attributes.firstWhere((a) => a.name.local == 'id' && a.name.prefix == 'r',
          orElse: () => XmlAttribute(XmlName.parts('x'), '')).value;

  static String _resolve(String baseDir, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final parts = baseDir.split('/');
    for (final p in target.split('/')) {
      if (p == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (p != '.') {
        parts.add(p);
      }
    }
    return parts.join('/');
  }
}

Iterable<XmlElement> _all(XmlElement root, String local) =>
    root.descendantElements.where((e) => e.name.local == local);

XmlElement? _first(XmlElement root, String local) {
  for (final e in root.descendantElements) {
    if (e.name.local == local) return e;
  }
  return null;
}


/// Высоты строк и ширины колонок листа в EMU (для пересчёта сдвига картинок).
class _CellSizes {
  static const _emuPerPt = 12700;
  static const _emuPerPx = 9525;

  final Map<int, double> _rowPt = {};
  final Map<int, double> _colWidth = {};
  double _defaultRowPt = 15;
  double _defaultColWidth = 8.43;

  _CellSizes(XmlDocument sheet) {
    for (final e in sheet.rootElement.descendantElements) {
      switch (e.name.local) {
        case 'sheetFormatPr':
          _defaultRowPt = double.tryParse(e.getAttribute('defaultRowHeight') ?? '') ?? _defaultRowPt;
          _defaultColWidth = double.tryParse(e.getAttribute('defaultColWidth') ?? '') ?? _defaultColWidth;
        case 'row':
          final r = int.tryParse(e.getAttribute('r') ?? '');
          final ht = double.tryParse(e.getAttribute('ht') ?? '');
          if (r != null && ht != null) _rowPt[r - 1] = ht;
        case 'col':
          final min = int.tryParse(e.getAttribute('min') ?? ''), max = int.tryParse(e.getAttribute('max') ?? '');
          final w = double.tryParse(e.getAttribute('width') ?? '');
          if (min != null && max != null && w != null) {
            for (var c = min - 1; c < max && c < 1000; c++) {
              _colWidth[c] = w;
            }
          }
      }
    }
  }

  int rowEmu(int row) => ((_rowPt[row] ?? _defaultRowPt) * _emuPerPt).round();

  // Ширина колонки в «символах» → пиксели (как в Excel: ×7 + 5) → EMU.
  int colEmu(int col) => (((_colWidth[col] ?? _defaultColWidth) * 7 + 5) * _emuPerPx).round();
}
