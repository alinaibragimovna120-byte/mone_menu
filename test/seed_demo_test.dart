// Наполняет папку MONE_MENU_DATA демо-данными из Excel (для ручной проверки).
// Без переменной окружения тест пропускается.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mone_menu/ui/models/tech_card.dart';
import 'package:mone_menu/provider/menu_provider.dart';
import 'package:mone_menu/services/card_storage.dart';
import 'package:mone_menu/services/xlsx_tech_card_parser.dart';

void main() {
  final dir = Platform.environment['MONE_MENU_DATA'];
  test('seed', () async {
    final menu = MenuProvider(CardStorage());
    await menu.load();
    for (final f in ['№ 1 Тех карта Бар Чай Кофе 03.04.2026 (2).xlsx', '../№ 2 Тех карта Коктейл   24.03.2026.xlsx']) {
      final parsed = XlsxTechCardParser.parse(File(f).readAsBytesSync());
      final (title, number, date) = TechBook.parseFileName(f.split('/').last);
      final book = await menu.createBook(title: title, number: number, date: date);
      await menu.importCards(parsed, book.id, f, coverIndex: 0);
    }
  }, skip: dir == null ? 'MONE_MENU_DATA не задан' : false);
}
