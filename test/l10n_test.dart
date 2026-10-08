// У каждой надписи интерфейса, переданной в tr(...), есть узбекский перевод.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mone_menu/ui/l10n.dart';

void main() {
  test('все tr() переведены на узбекский', () {
    // tr('…') или tr('…' '…') — соседние строки Dart склеивает в одну.
    final call = RegExp(r"""tr\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)""");
    final part = RegExp(r"""'((?:[^'\\]|\\.)*)'""");
    final missing = <String>[];
    var found = 0;
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in call.allMatches(f.readAsStringSync())) {
        found++;
        final key = part.allMatches(m[1]!).map((p) => p[1]!.replaceAll(r'\n', '\n')).join();
        if (!hasUzbek(key)) missing.add('${f.path}: $key');
      }
    }
    expect(found, greaterThan(50), reason: 'регулярка должна находить вызовы tr()');
    expect(missing, isEmpty);
  });

  test('склонения и единицы', () {
    appLang = AppLang.ru;
    expect(plural(1, 'позиция', 'позиции', 'позиций'), '1 позиция');
    expect(plural(3, 'позиция', 'позиции', 'позиций'), '3 позиции');
    expect(plural(11, 'позиция', 'позиции', 'позиций'), '11 позиций');
    expect(trData('360 гр'), '360 гр');
    appLang = AppLang.uz;
    expect(plural(5, 'позиция', 'позиции', 'позиций'), '5 ta pozitsiya');
    expect(trData('С собой 2'), 'Olib ketish 2');
    expect(trData('1,293 гр'), '1,293 gr');
    expect(trData('шт'), 'dona');
    expect(tr('Добавлено позиций: {n}', {'n': 3}), "Qo'shilgan pozitsiyalar: 3");
    appLang = AppLang.ru;
  });
}
