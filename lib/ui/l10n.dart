// Язык интерфейса: русский или узбекский (латиница). Ключ перевода — сам
// русский текст: tr('Отмена') → «Bekor qilish» на узбекском. Параметры в
// фигурных скобках: tr('Добавлено позиций: {n}', {'n': 5}).
// Тексты из Excel (названия, состав) не переводятся — они как в файле.

import 'package:flutter/foundation.dart';

enum AppLang {
  ru('RU', 'Русский'),
  uz('UZ', "O'zbekcha");

  final String code;
  final String label;
  const AppLang(this.code, this.label);
}

/// Текущий язык. Меняется через [LangController].
AppLang appLang = AppLang.ru;

class LangController extends ChangeNotifier {
  final Future<void> Function(String code)? onSave;
  LangController({String? saved, this.onSave}) {
    appLang = AppLang.values.firstWhere((l) => l.name == saved, orElse: () => AppLang.ru);
  }

  AppLang get lang => appLang;

  void set(AppLang l) {
    if (l == appLang) return;
    appLang = l;
    notifyListeners();
    onSave?.call(l.name);
  }
}

/// Перевод строки интерфейса на текущий язык.
String tr(String ru, [Map<String, Object?> args = const {}]) {
  var s = appLang == AppLang.uz ? (_uz[ru] ?? ru) : ru;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Названия вариантов и единицы, сохранённые по-русски («С собой 2»,
/// «360 гр», «шт»), — для показа на текущем языке.
String trData(String s) {
  if (appLang == AppLang.ru) return s;
  final m = RegExp(r'^С собой(?: (\d+))?$').firstMatch(s);
  if (m != null) return m[1] == null ? 'Olib ketish' : 'Olib ketish ${m[1]}';
  if (_uzData.containsKey(s)) return _uzData[s]!;
  // «1,293 гр», «400 мл» — единица после числа.
  return s.replaceAllMapped(
    RegExp(r'(\d\s*)(гр|мл|шт|кг|л)(?![А-Яа-яЁё])'),
    (m) => '${m[1]}${_uzData[m[2]]}',
  );
}

const _uzData = {
  'Основной': 'Asosiy',
  'гр': 'gr',
  'мл': 'ml',
  'шт': 'dona',
  'кг': 'kg',
  'л': 'l',
};

/// Склонение после числа: 1 позиция, 3 позиции, 5 позиций (по-узбекски — «5 ta pozitsiya»).
String plural(int n, String one, String few, String many) {
  if (appLang == AppLang.uz) return '$n ta ${_uzWords[one] ?? one}';
  final m10 = n % 10, m100 = n % 100;
  final w = m10 == 1 && m100 != 11
      ? one
      : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14))
          ? few
          : many;
  return '$n $w';
}

const _uzWords = {
  'позиция': 'pozitsiya',
  'позицию': 'pozitsiya',
  'техкарта': 'texkarta',
};

const _uz = <String, String>{
  // главная
  'Техкарты и меню': 'Texkartalar va menyu',
  'Добавить техкарту': "Texkarta qo'shish",
  'Все техкарты — выбрать, какие видны на главной': "Barcha texkartalar — bosh sahifada qaysilari ko'rinishini tanlang",
  'Язык': 'Til',
  'Здесь будут ваши техкарты': "Bu yerda sizning texkartalaringiz bo'ladi",
  'Нажмите «+» и выберите Excel-файл техкарты —\nпозиции, состав и фото загрузятся автоматически':
      "«+» tugmasini bosing va texkartaning Excel faylini tanlang —\npozitsiyalar, tarkibi va rasmlari avtomatik yuklanadi",
  'Загрузить из Excel': "Excel'dan yuklash",
  'Создать вручную': "Qo'lda yaratish",
  'Показать скрытые техкарты': "Yashirilgan texkartalarni ko'rsatish",
  'Новая техкарта': 'Yangi texkarta',
  'Файл .xlsx в формате техкарты Mone': 'Mone texkartasi formatidagi .xlsx fayl',
  'Название и позиции заполните сами': "Nomi va pozitsiyalarni o'zingiz to'ldirasiz",
  'Название техкарты': 'Texkarta nomi',
  'Например: Десерты': 'Masalan: Desertlar',
  'Отмена': 'Bekor qilish',
  'Готово': 'Tayyor',
  'Переименовать': "Nomini o'zgartirish",
  'Сменить обложку': 'Muqovani almashtirish',
  'Заменить из Excel': "Excel'dan almashtirish",
  'Дополнить из Excel': "Excel'dan to'ldirish",
  'Скрыть с главной': 'Bosh sahifadan yashirish',
  'Скрыть техкарту?': 'Texkarta yashirilsinmi?',
  '«{title}» ({count}) пропадёт с главной. Вернуть её можно через значок «›» → «Все техкарты».':
      "«{title}» ({count}) bosh sahifadan yo'qoladi. Uni «›» belgisi → «Barcha texkartalar» orqali qaytarish mumkin.",
  'Скрыть': 'Yashirish',
  '«{title}» скрыта с главной': '«{title}» bosh sahifadan yashirildi',
  'Вернуть': 'Qaytarish',
  'Заменить техкарту?': 'Texkarta almashtirilsinmi?',
  'Текущие позиции «{title}» ({count}) уйдут в скрытые, а вместо них загрузятся позиции из нового Excel-файла.':
      "«{title}» ning joriy pozitsiyalari ({count}) yashirilganlarga o'tadi, ularning o'rniga yangi Excel faylidagi pozitsiyalar yuklanadi.",
  'Выбрать файл': 'Faylni tanlash',

  // все техкарты
  'Все техкарты': 'Barcha texkartalar',
  'Включите «На главной», чтобы техкарта была видна на главной странице, или выключите, чтобы скрыть её. Позиции и фото скрытой техкарты сохраняются.':
      "Texkarta bosh sahifada ko'rinishi uchun «Bosh sahifada» ni yoqing, yashirish uchun esa o'chiring. Yashirilgan texkartaning pozitsiyalari va rasmlari saqlanib qoladi.",
  'На главной': 'Bosh sahifada',
  'На главной · {n}': 'Bosh sahifada · {n}',
  'Скрытые · {n}': 'Yashirilganlar · {n}',
  'Пока нет ни одной техкарты': "Hozircha birorta ham texkarta yo'q",
  'Скрыта {date}': 'Yashirilgan: {date}',
  'Удалить навсегда': "Butunlay o'chirish",
  'Удалить навсегда?': "Butunlay o'chirilsinmi?",
  '«{title}» и все её позиции ({count}) вместе с фото будут удалены без возможности восстановления.':
      "«{title}» va uning barcha pozitsiyalari ({count}) rasmlari bilan birga qayta tiklab bo'lmaydigan tarzda o'chiriladi.",
  'Удалить': "O'chirish",

  // техкарта
  'Техкарта скрыта — вернуть её можно в «Все техкарты» (значок «›» на главной)':
      "Texkarta yashirilgan — uni «Barcha texkartalar» bo'limidan qaytarish mumkin (bosh sahifadagi «›» belgisi)",
  'Добавить позицию': "Pozitsiya qo'shish",
  'от {date}': 'sana: {date}',
  'Поиск по названию или ингредиенту': "Nomi yoki ingrediyent bo'yicha qidirish",
  'Все': 'Hammasi',
  'Пока нет позиций — нажмите «+»': "Hozircha pozitsiyalar yo'q — «+» tugmasini bosing",
  'Ничего не найдено': 'Hech narsa topilmadi',
  'Удерживайте или нажмите правой кнопкой мыши, чтобы переименовать отдел':
      "Bo'lim nomini o'zgartirish uchun bosib turing yoki sichqonchaning o'ng tugmasini bosing",
  'Переименовать отдел': "Bo'lim nomini o'zgartirish",
  'Чтобы объединить с другим отделом, введите его название: {list}':
      "Boshqa bo'lim bilan birlashtirish uchun uning nomini kiriting: {list}",
  'Добавить': "Qo'shish",
  'Новая позиция': 'Yangi pozitsiya',
  'Название, фото, состав, выход': 'Nomi, rasmi, tarkibi, chiqishi',
  'Новые позиции добавятся, совпадающие обновятся': "Yangi pozitsiyalar qo'shiladi, mos keladiganlari yangilanadi",

  // позиция
  'Позиция удалена': "Pozitsiya o'chirilgan",
  'Редактировать': 'Tahrirlash',
  'Удалить позицию?': "Pozitsiya o'chirilsinmi?",
  'Нет рецептуры': "Retseptura yo'q",
  'Выход': 'Chiqishi',
  'Состав': 'Tarkibi',
  'Ингредиенты не указаны': "Ingrediyentlar ko'rsatilmagan",
  'Примечания': 'Izohlar',

  // редактирование
  'Редактирование': 'Tahrirlash',
  'Сохранить': 'Saqlash',
  'Фото': 'Rasm',
  'Название': 'Nomi',
  'Введите название': 'Nomini kiriting',
  'Категория': 'Kategoriya',
  'Добавить вариант (например, «С собой»)': "Variant qo'shish (masalan, «Olib ketish»)",
  'Вариант': 'Variant',
  'Удалить вариант': "Variantni o'chirish",
  'Ингредиент': 'Ingrediyent',
  'Примечания (каждое с новой строки)': 'Izohlar (har biri yangi qatordan)',

  // сервер
  'Сервер': 'Server',
  'Вы вошли как {name}': '{name} sifatida kirdingiz',
  'Отправлено на сервер: {n}': 'Serverga yuborildi: {n}',
  'На сервере есть другие изменения': "Serverda boshqa o'zgarishlar bor",
  'После вашей последней синхронизации меню на сервере изменили с другого устройства. Что оставить?':
      "Oxirgi sinxronlashdan keyin serverdagi menyu boshqa qurilmadan o'zgartirilgan. Qaysi birini qoldiramiz?",
  'Загрузить с сервера': 'Serverdan yuklash',
  'Заменить моими': 'Meniki bilan almashtirish',
  'Загрузить с сервера?': 'Serverdan yuklansinmi?',
  'Техкарты на этом устройстве будут заменены версией с сервера.':
      'Bu qurilmadagi texkartalar serverdagi nusxa bilan almashtiriladi.',
  'Загрузить': 'Yuklash',
  'Загружено с сервера: {n}': 'Serverdan yuklandi: {n}',
  'Войдите тем же паролем, что и в приложении Mone, чтобы хранить техкарты на сервере и открывать их на других устройствах.':
      "Texkartalarni serverda saqlash va boshqa qurilmalarda ochish uchun Mone ilovasidagi parol bilan kiring.",
  'Пароль': 'Parol',
  'Адрес сервера': 'Server manzili',
  'Другой сервер': 'Boshqa server',
  'Войти': 'Kirish',
  'Ещё не синхронизировано': 'Hali sinxronlanmagan',
  'Синхронизировано {date}': 'Sinxronlandi: {date}',
  'Выйти': 'Chiqish',
  'Отправить на сервер': 'Serverga yuborish',
  'Все техкарты с этого устройства (и скрытые) вместе с фото сохранятся на сервере.':
      'Bu qurilmadagi barcha texkartalar (yashirilganlari ham) rasmlari bilan serverda saqlanadi.',
  'Отправлять техкарты на сервер могут админ и шеф. Вам доступна загрузка.':
      "Texkartalarni serverga faqat admin va shef yubora oladi. Siz yuklab olishingiz mumkin.",
  'Сервер — вход и синхронизация': 'Server — kirish va sinxronlash',
  'Версия {v}': 'Versiya {v}',
  'Есть изменения, ещё не отправленные на сервер': "Serverga hali yuborilmagan o'zgarishlar bor",
  'Загружаю техкарты с сервера…': 'Texkartalar serverdan yuklanmoqda…',

  // импорт
  'Формат .xls не поддерживается. Откройте файл в Excel → «Сохранить как» → «Книга Excel (*.xlsx)».':
      "«.xls» formati qo'llab-quvvatlanmaydi. Faylni Excel'da oching → «Boshqacha saqlash» → «Excel kitobi (*.xlsx)».",
  '«{name}» — не Excel-файл. Нужен файл .xlsx': '«{name}» — Excel fayli emas. .xlsx fayl kerak',
  'Читаю техкарту…': "Texkarta o'qilmoqda…",
  'Не удалось прочитать файл: {error}': "Faylni o'qib bo'lmadi: {error}",
  'В файле не найдено техкарт': 'Faylda texkarta topilmadi',
  'Техкарта заменена · {count}': 'Texkarta almashtirildi · {count}',
  'Добавлено позиций: {n}': "Qo'shilgan pozitsiyalar: {n}",
  'Добавлено: {added}, обновлено: {updated}': "Qo'shildi: {added}, yangilandi: {updated}",
  'Отпустите файл здесь': "Faylni shu yerga qo'yib yuboring",
  '{subtitle}\nили перетащите файл сюда · {paste} — вставить': "{subtitle}\nyoki faylni shu yerga sudrab olib keling · {paste} — qo'yish",
};

/// Для отладки: перевод есть для каждой строки, которую просили перевести.
@visibleForTesting
bool hasUzbek(String ru) => _uz.containsKey(ru);
