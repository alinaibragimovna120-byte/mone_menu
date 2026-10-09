// Состояние приложения: техкарты (сборники-файлы) и их позиции,
// поиск/фильтр внутри техкарты, импорт из Excel.

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../ui/models/tech_card.dart';
import '../services/card_storage.dart';
import '../services/text_fixes.dart';
import '../services/xlsx_tech_card_parser.dart';

class MenuProvider extends ChangeNotifier {
  final CardStorage storage;
  MenuProvider(this.storage);

  /// Вызывается после каждого изменения пользователем (не при загрузке и не
  /// при замене данными с сервера) — для автоотправки на сервер.
  VoidCallback? onChanged;

  List<TechBook> _books = [];
  List<TechCard> _cards = [];
  bool loading = true;

  // Поиск и фильтр — для открытой техкарты.
  String query = '';
  String? category;

  /// Техкарты на главной (без удалённых).
  List<TechBook> get books => _books.where((b) => b.deletedAt == null).toList();

  /// Удалённые и заменённые техкарты — «Все техкарты» (скрытые), свежие сверху.
  List<TechBook> get deletedBooks =>
      _books.where((b) => b.deletedAt != null).toList()..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  TechBook? bookById(String id) {
    for (final b in _books) {
      if (b.id == id) return b;
    }
    return null;
  }

  TechCard? byId(String id) {
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<TechCard> cardsOf(String bookId) => _cards.where((c) => c.bookId == bookId).toList();

  /// Все техкарты (и скрытые) и все позиции — для синхронизации с сервером.
  List<TechBook> get allBooks => List.unmodifiable(_books);
  List<TechCard> get allCards => List.unmodifiable(_cards);

  /// Заменить все данные (загрузка с сервера). Фото, на которые больше никто
  /// не ссылается, удаляются.
  Future<void> replaceAll(List<TechBook> books, List<TechCard> cards) async {
    final keep = {for (final c in cards) ...c.photos, for (final b in books) if (b.cover.isNotEmpty) b.cover};
    final old = {for (final c in _cards) ...c.photos, for (final b in _books) if (b.cover.isNotEmpty) b.cover};
    _books = [...books];
    _cards = [...cards];
    notifyListeners();
    await _persist();
    for (final p in old.difference(keep)) {
      await storage.deletePhoto(p);
    }
  }

  int countOf(String bookId) => _cards.where((c) => c.bookId == bookId).length;

  /// Обложка: выбранное фото или первое фото позиции.
  String? coverOf(TechBook book) {
    if (book.cover.isNotEmpty) return book.cover;
    for (final c in _cards) {
      if (c.bookId == book.id && c.photos.isNotEmpty) return c.photos.first;
    }
    return null;
  }

  List<String> categoriesOf(String bookId) {
    final seen = <String>{};
    return [for (final c in _cards) if (c.bookId == bookId && seen.add(c.category)) c.category];
  }

  List<TechCard> visibleOf(String bookId) {
    final q = query.trim().toLowerCase();
    return _cards.where((c) {
      if (c.bookId != bookId) return false;
      if (category != null && c.category != category) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.variants.any((v) => v.ingredients.any((i) => i.name.toLowerCase().contains(q)));
    }).toList();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final (books, cards) = await storage.load();
      _books = books;
      _cards = cards;
      // Раньше id мог совпасть у нескольких позиций — выдаём повторам новые.
      final seen = <String>{};
      if (_cards.any((c) => !seen.add(c.id))) {
        seen.clear();
        _cards = [for (final c in _cards) seen.add(c.id) ? c : c.copyWith(id: newId())];
        await _persist();
      }
      // Опечатки из Excel («Завтрыки», «очищеный»…) — исправляем и в сохранённом.
      var typos = false;
      for (var i = 0; i < _books.length; i++) {
        final t = fixTypos(_books[i].title);
        if (t != _books[i].title) {
          _books[i] = _books[i].copyWith(title: t);
          typos = true;
        }
      }
      for (var i = 0; i < _cards.length; i++) {
        final c = _cards[i];
        final fixed = c.copyWith(
          name: fixTypos(c.name),
          category: fixTypos(c.category),
          variants: [for (final v in c.variants) fixVariant(v)],
        );
        if (jsonEncode(fixed.toJson()) != jsonEncode(c.toJson())) {
          _cards[i] = fixed;
          typos = true;
        }
      }
      if (typos) await _persist();
      // Похожие отделы в одной техкарте («Лимонад» / «Лимонады») — в один.
      final cats = <String, List<String>>{};
      var changed = false;
      for (var i = 0; i < _cards.length; i++) {
        final c = _cards[i];
        final known = cats.putIfAbsent(c.bookId, () => []);
        final same = known.where((x) => sameCategory(x, c.category)).firstOrNull;
        if (same == null) {
          known.add(c.category);
        } else if (same != c.category) {
          _cards[i] = c.copyWith(category: same);
          changed = true;
        }
      }
      if (changed) await _persist();
      // Позиции из первой версии (без техкарты) — в отдельную техкарту.
      if (_cards.any((c) => bookById(c.bookId) == null)) {
        final misc = TechBook(id: newId(), title: 'Мои позиции', createdAt: DateTime.now());
        _books.add(misc);
        _cards = [
          for (final c in _cards) bookById(c.bookId) == null ? c.copyWith(bookId: misc.id) : c,
        ];
        await _persist();
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Сбросить поиск/фильтр при входе в техкарту.
  void resetFilter() {
    query = '';
    category = null;
  }

  void setQuery(String v) {
    query = v;
    notifyListeners();
  }

  void setCategory(String? v) {
    category = v;
    notifyListeners();
  }

  int _idSeq = 0;

  /// Уникальный id: время + счётчик (позиции без фото создаются в одну
  /// микросекунду, и одного времени не хватает).
  String newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_idSeq++).toRadixString(36)}';

  /// Записать на устройство (без отметки «изменено» — загрузка, данные с сервера).
  Future<void> _persist() => storage.save(_books, _cards);

  /// Записать изменение пользователя: [onChanged] отправит его на сервер.
  Future<void> _save() async {
    await _persist();
    onChanged?.call();
  }

  // ---------- техкарты (сборники) ----------

  Future<TechBook> createBook({required String title, String number = '', String date = '', String sourceFile = ''}) async {
    final book = TechBook(
      id: newId(),
      title: title,
      number: number,
      date: date,
      sourceFile: sourceFile,
      createdAt: DateTime.now(),
    );
    _books.add(book);
    notifyListeners();
    await _save();
    return book;
  }

  Future<void> updateBook(TechBook book) async {
    final i = _books.indexWhere((b) => b.id == book.id);
    if (i < 0) return;
    final old = _books[i];
    _books[i] = book;
    notifyListeners();
    await _save();
    // Своё (загруженное) фото обложки удаляем, фото позиций не трогаем.
    if (old.cover.isNotEmpty && old.cover != book.cover && !_isCardPhoto(old.cover)) {
      await storage.deletePhoto(old.cover);
    }
  }

  /// Удалить техкарту: она уходит в «Все техкарты» (скрытые) вместе с позициями
  /// и фото, оттуда её можно вернуть ([restoreBook]).
  Future<void> deleteBook(String id) async {
    final i = _books.indexWhere((b) => b.id == id);
    if (i < 0) return;
    _books[i] = _books[i].copyWith(deletedAt: DateTime.now());
    notifyListeners();
    await _save();
  }

  /// Вернуть техкарту из «Все техкарты» (скрытые) на главную.
  Future<void> restoreBook(String id) async {
    final i = _books.indexWhere((b) => b.id == id);
    if (i < 0) return;
    _books[i] = _books[i].copyWith(restore: true);
    notifyListeners();
    await _save();
  }

  /// Удалить техкарту навсегда — с позициями и фото.
  Future<void> purgeBook(String id) async {
    final book = bookById(id);
    if (book == null) return;
    final cards = cardsOf(id);
    _books.removeWhere((b) => b.id == id);
    _cards.removeWhere((c) => c.bookId == id);
    notifyListeners();
    await _save();
    for (final c in cards) {
      for (final p in c.photos) {
        await storage.deletePhoto(p);
      }
    }
    if (book.cover.isNotEmpty) await storage.deletePhoto(book.cover);
  }

  /// Заменить содержимое техкарты [bookId] позициями из другого файла:
  /// номер/дата/обложка берутся из нового файла, а прежняя версия со всеми
  /// позициями уходит в «Все техкарты» (скрытые). Возвращает число загруженных позиций.
  Future<int> replaceBook(String bookId, List<ParsedCard> parsed, String fileName) async {
    final book = bookById(bookId);
    if (book == null) return 0;
    final archived = TechBook(
      id: newId(),
      title: book.title,
      number: book.number,
      date: book.date,
      cover: book.cover,
      sourceFile: book.sourceFile,
      createdAt: book.createdAt,
      deletedAt: DateTime.now(),
    );
    _books.add(archived);
    _cards = [for (final c in _cards) c.bookId == bookId ? c.copyWith(bookId: archived.id) : c];
    final (rawTitle, number, date) = TechBook.parseFileName(fileName);
    final title = fixTypos(rawTitle);
    final b = _books.indexWhere((x) => x.id == bookId);
    _books[b] = book.copyWith(title: title, number: number, date: date, cover: '', sourceFile: fileName);
    final cover = parsed.indexWhere((c) => c.images.isNotEmpty);
    final (added, _) = await importCards(parsed, bookId, fileName, coverIndex: cover >= 0 ? cover : null);
    return added;
  }

  bool _isCardPhoto(String path) => _cards.any((c) => c.photos.contains(path));

  // ---------- позиции ----------

  Future<void> upsert(TechCard card) async {
    final i = _cards.indexWhere((c) => c.id == card.id);
    final updated = card.copyWith(updatedAt: DateTime.now());
    if (i >= 0) {
      _cards[i] = updated;
    } else {
      _cards.add(updated);
    }
    notifyListeners();
    await _save();
  }

  Future<void> delete(String id) async {
    final card = byId(id);
    if (card == null) return;
    _cards.removeWhere((c) => c.id == id);
    _clearCoverIfUses(card.photos);
    notifyListeners();
    await _save();
    for (final p in card.photos) {
      await storage.deletePhoto(p);
    }
  }

  /// Переименовать отдел в техкарте. Если отдел [to] уже есть — отделы сливаются.
  Future<void> renameCategory(String bookId, String from, String to) async {
    final target = categoriesOf(bookId).firstWhere((c) => c != from && sameCategory(c, to), orElse: () => to);
    _cards = [
      for (final c in _cards) c.bookId == bookId && c.category == from ? c.copyWith(category: target) : c,
    ];
    if (category == from) category = target;
    notifyListeners();
    await _save();
  }

  void _clearCoverIfUses(List<String> photos) {
    for (var i = 0; i < _books.length; i++) {
      if (photos.contains(_books[i].cover)) _books[i] = _books[i].copyWith(cover: '');
    }
  }

  /// Импорт позиций в техкарту [bookId]. Позиция с тем же названием и
  /// категорией в этой техкарте заменяется, остальные добавляются.
  /// [coverIndex] — индекс в [parsed], чьё первое фото станет обложкой.
  /// Возвращает (добавлено, обновлено).
  Future<(int, int)> importCards(List<ParsedCard> parsed, String bookId, String fileName, {int? coverIndex}) async {
    var added = 0, updated = 0;
    final oldPhotos = <String>[];
    // Сверяем только с тем, что было до импорта: одинаковые названия внутри
    // одного файла («Сироп по вкусу» ×3) — разные позиции.
    final before = {for (final c in _cards) if (c.bookId == bookId) c.id};
    final matched = <String>{};
    final existing = categoriesOf(bookId);
    for (var k = 0; k < parsed.length; k++) {
      final pc = parsed[k];
      // Отдел из нового файла — в уже существующий отдел с тем же названием.
      final category = existing.firstWhere((c) => sameCategory(c, pc.category), orElse: () => pc.category);
      final photos = <String>[];
      for (final img in pc.images) {
        photos.add(await storage.savePhoto(img.bytes, img.ext));
      }
      final i = _cards.indexWhere((c) =>
          before.contains(c.id) &&
          !matched.contains(c.id) &&
          c.name.toLowerCase() == pc.name.toLowerCase() &&
          sameCategory(c.category, category));
      final card = TechCard(
        id: i >= 0 ? _cards[i].id : newId(),
        bookId: bookId,
        name: pc.name,
        category: category,
        variants: pc.variants,
        photos: photos.isEmpty && i >= 0 ? _cards[i].photos : photos,
        source: '$fileName / ${pc.sheet}',
        updatedAt: DateTime.now(),
      );
      if (i >= 0) {
        matched.add(card.id);
        if (photos.isNotEmpty) oldPhotos.addAll(_cards[i].photos);
        _cards[i] = card;
        updated++;
      } else {
        _cards.add(card);
        added++;
      }
      if (k == coverIndex && photos.isNotEmpty) {
        final b = _books.indexWhere((b) => b.id == bookId);
        if (b >= 0) _books[b] = _books[b].copyWith(cover: photos.first);
      }
    }
    _clearCoverIfUses(oldPhotos);
    notifyListeners();
    await _save();
    for (final p in oldPhotos) {
      await storage.deletePhoto(p);
    }
    return (added, updated);
  }
}
