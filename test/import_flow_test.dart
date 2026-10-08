// Импорт реального Excel → тех карта → позиции с фото; сохранение и загрузка.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mone_menu/ui/models/tech_card.dart';
import 'package:mone_menu/provider/menu_provider.dart';
import 'package:mone_menu/services/card_storage.dart';
import 'package:mone_menu/services/xlsx_tech_card_parser.dart';
import 'package:path/path.dart' as p;

class _TempStorage extends CardStorage {
  final Directory dir;
  _TempStorage(this.dir);

  @override
  Future<Directory> root() async {
    await Directory(p.join(dir.path, 'photos')).create(recursive: true);
    return dir;
  }
}

void main() {
  test('parseFileName', () {
    final (title, number, date) = TechBook.parseFileName('№ 1 Тех карта Бар Чай Кофе 03.04.2026 (2).xlsx');
    expect(title, 'Бар Чай Кофе');
    expect(number, '1');
    expect(date, '03.04.2026');
  });

  test('удалённая и заменённая тех карта — в «Ранее добавленные», можно вернуть', () async {
    final tmp = await Directory.systemTemp.createTemp('mone_menu_test');
    addTearDown(() => tmp.delete(recursive: true));
    final menu = MenuProvider(_TempStorage(tmp));
    await menu.load();
    final book = await menu.createBook(title: 'Коктейл');
    await menu.upsert(TechCard(id: menu.newId(), bookId: book.id, name: 'Мохито', category: 'Коктейли', variants: const [], updatedAt: DateTime.now()));

    await menu.deleteBook(book.id);
    expect(menu.books, isEmpty);
    expect(menu.deletedBooks.single.id, book.id);

    // после перезапуска удалённая тех карта не теряется
    final menu2 = MenuProvider(_TempStorage(tmp));
    await menu2.load();
    expect(menu2.deletedBooks.single.title, 'Коктейл');
    await menu2.restoreBook(book.id);
    expect(menu2.books.single.id, book.id);
    expect(menu2.countOf(book.id), 1);

    // замена из Excel: прежняя версия уходит в «Ранее добавленные»
    final added = await menu2.replaceBook(book.id, const [], '№ 3 Тех карта Новая 01.01.2026.xlsx');
    expect(added, 0);
    expect(menu2.books.single.title, 'Новая');
    final old = menu2.deletedBooks.single;
    expect(old.title, 'Коктейл');
    expect(menu2.cardsOf(old.id).single.name, 'Мохито');

    await menu2.purgeBook(old.id);
    expect(menu2.deletedBooks, isEmpty);
    expect(menu2.cardsOf(old.id), isEmpty);
  });

  const sample ='№ 1 Тех карта Бар Чай Кофе 03.04.2026 (2).xlsx';
  test('импорт реального файла', () async {
    final tmp = await Directory.systemTemp.createTemp('mone_menu_test');
    addTearDown(() => tmp.delete(recursive: true));

    final parsed = XlsxTechCardParser.parse(File(sample).readAsBytesSync());
    expect(parsed.length, greaterThan(30));
    expect(parsed.any((c) => c.category == 'Лист'), isFalse);

    final menu = MenuProvider(_TempStorage(tmp));
    await menu.load();
    final (title, number, date) = TechBook.parseFileName(sample);
    final book = await menu.createBook(title: title, number: number, date: date);
    final (added, updated) = await menu.importCards(parsed, book.id, sample, coverIndex: 0);
    expect(added, parsed.length);
    expect(updated, 0);
    expect(menu.coverOf(menu.bookById(book.id)!), isNotNull);

    // повторный импорт — обновление, не дубли
    final (added2, updated2) = await menu.importCards(parsed.take(3).toList(), book.id, sample);
    expect(added2, 0);
    expect(updated2, 3);
    expect(menu.countOf(book.id), parsed.length);

    // перезагрузка из файла
    final menu2 = MenuProvider(_TempStorage(tmp));
    await menu2.load();
    expect(menu2.books.single.title, 'Бар Чай Кофе');
    expect(menu2.countOf(book.id), parsed.length);
    final flat = menu2.cardsOf(book.id).firstWhere((c) => c.name == 'Flat White');
    expect(flat.yieldText, '197 гр');
    expect(File(flat.photos.first).existsSync(), isTrue);
  }, skip: File(sample).existsSync() ? false : 'нет файла $sample');
}
