// ignore_for_file: avoid_print
// Быстрая проверка парсера: dart run tool/parse_check.dart <файл.xlsx>
import 'dart:io';

import 'package:mone_menu/ui/models/tech_card.dart';
import 'package:mone_menu/services/xlsx_tech_card_parser.dart';

void main(List<String> args) {
  for (final path in args) {
    final cards = XlsxTechCardParser.parse(File(path).readAsBytesSync());
    print('=== $path: ${cards.length} карт');
    for (final c in cards) {
      print('[${c.category}] ${c.name}  (фото: ${c.images.length})');
      for (final v in c.variants) {
        print('   ${v.title} ${v.yieldText}');
        for (final i in v.ingredients) {
          print('     - ${i.name}: ${formatAmount(i.amount)} ${i.unit}');
        }
        for (final n in v.notes) {
          print('     * $n');
        }
      }
    }
  }
}
