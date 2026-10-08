// Техкарта (позиция меню): название, категория, фото и варианты рецептуры
// (например «Основной» и «С собой»). Модель общая для импорта из Excel,
// локального хранения (JSON) и экранов.

/// Строка рецептуры: ингредиент, единица и количество.
///
/// [amount] хранится в «человеческих» единицах: для гр/мл — граммы/миллилитры,
/// для шт — штуки. В Excel техкарта хранит граммы в кг (0.045 = 45 гр),
/// перевод делает парсер.
class Ingredient {
  final String name;
  final String unit;
  final double amount;

  const Ingredient({required this.name, required this.unit, required this.amount});

  Ingredient copyWith({String? name, String? unit, double? amount}) => Ingredient(
        name: name ?? this.name,
        unit: unit ?? this.unit,
        amount: amount ?? this.amount,
      );

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        name: j['name'] as String? ?? '',
        unit: j['unit'] as String? ?? 'гр',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {'name': name, 'unit': unit, 'amount': amount};
}

/// Вариант рецептуры одной позиции (основной, «С собой» и т.п.).
class CardVariant {
  final String title;
  final String yieldText;
  final List<Ingredient> ingredients;

  /// Заметки без количества: «Экстракция 3 мин», «Объем чашки 0.310» и т.д.
  final List<String> notes;

  const CardVariant({
    required this.title,
    this.yieldText = '',
    this.ingredients = const [],
    this.notes = const [],
  });

  CardVariant copyWith({
    String? title,
    String? yieldText,
    List<Ingredient>? ingredients,
    List<String>? notes,
  }) =>
      CardVariant(
        title: title ?? this.title,
        yieldText: yieldText ?? this.yieldText,
        ingredients: ingredients ?? this.ingredients,
        notes: notes ?? this.notes,
      );

  factory CardVariant.fromJson(Map<String, dynamic> j) => CardVariant(
        title: j['title'] as String? ?? '',
        yieldText: j['yield_text'] as String? ?? '',
        ingredients: (j['ingredients'] as List? ?? [])
            .map((e) => Ingredient.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        notes: (j['notes'] as List? ?? []).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'yield_text': yieldText,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        'notes': notes,
      };
}

class TechCard {
  final String id;

  /// В какой техкарте (сборнике) лежит позиция — см. [TechBook].
  final String bookId;
  final String name;
  final String category;
  final List<CardVariant> variants;

  /// Пути к фото на диске (папка приложения).
  final List<String> photos;

  /// Откуда импортирована: «файл.xlsx / лист». Пусто — создана вручную.
  final String source;
  final DateTime updatedAt;

  const TechCard({
    required this.id,
    required this.bookId,
    required this.name,
    required this.category,
    required this.variants,
    this.photos = const [],
    this.source = '',
    required this.updatedAt,
  });

  String get yieldText => variants.isEmpty ? '' : variants.first.yieldText;

  TechCard copyWith({
    String? id,
    String? bookId,
    String? name,
    String? category,
    List<CardVariant>? variants,
    List<String>? photos,
    String? source,
    DateTime? updatedAt,
  }) =>
      TechCard(
        id: id ?? this.id,
        bookId: bookId ?? this.bookId,
        name: name ?? this.name,
        category: category ?? this.category,
        variants: variants ?? this.variants,
        photos: photos ?? this.photos,
        source: source ?? this.source,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory TechCard.fromJson(Map<String, dynamic> j) => TechCard(
        id: j['id'] as String,
        bookId: j['book_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? '',
        variants: (j['variants'] as List? ?? [])
            .map((e) => CardVariant.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        photos: (j['photos'] as List? ?? []).cast<String>(),
        source: j['source'] as String? ?? '',
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'book_id': bookId,
        'name': name,
        'category': category,
        'variants': variants.map((e) => e.toJson()).toList(),
        'photos': photos,
        'source': source,
        'updated_at': updatedAt.toIso8601String(),
      };
}

/// Один и тот же отдел: без учёта регистра и окончания множественного числа
/// («Лимонад» = «лимонады», «Фреш» = «Фреши»).
bool sameCategory(String a, String b) {
  String norm(String s) => s.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'\s+'), ' ').trim();
  final x = norm(a), y = norm(b);
  if (x == y) return true;
  final (short, long) = x.length < y.length ? (x, y) : (y, x);
  return short.length >= 3 && long.length == short.length + 1 && long.startsWith(short) && 'ыи'.contains(long[long.length - 1]);
}

/// Красивый вывод количества: 45 гр, 7.5 гр, 1 шт.
String formatAmount(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(v.abs() < 1 ? 3 : 1);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Техкарта как документ (один Excel-файл, например «№ 1 Бар Чай Кофе»).
/// На главной странице показывается плиткой с обложкой, внутри — позиции.
class TechBook {
  final String id;
  final String title;

  /// Номер из названия файла («№ 1» → «1»), может быть пустым.
  final String number;

  /// Дата техкарты из названия файла («03.04.2026»), может быть пустой.
  final String date;

  /// Путь к обложке. Пусто — берётся первое фото позиции.
  final String cover;
  final String sourceFile;
  final DateTime createdAt;

  /// Когда техкарту удалили. Удалённая не показывается на главной, а лежит
  /// в «Все техкарты» (скрытые) — её можно вернуть. null — техкарта активна.
  final DateTime? deletedAt;

  const TechBook({
    required this.id,
    required this.title,
    this.number = '',
    this.date = '',
    this.cover = '',
    this.sourceFile = '',
    required this.createdAt,
    this.deletedAt,
  });

  /// [restore] — вернуть удалённую техкарту (сбросить [deletedAt]).
  TechBook copyWith({
    String? title,
    String? number,
    String? date,
    String? cover,
    String? sourceFile,
    DateTime? deletedAt,
    bool restore = false,
  }) =>
      TechBook(
        id: id,
        title: title ?? this.title,
        number: number ?? this.number,
        date: date ?? this.date,
        cover: cover ?? this.cover,
        sourceFile: sourceFile ?? this.sourceFile,
        createdAt: createdAt,
        deletedAt: restore ? null : deletedAt ?? this.deletedAt,
      );

  factory TechBook.fromJson(Map<String, dynamic> j) => TechBook(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        number: j['number'] as String? ?? '',
        date: j['date'] as String? ?? '',
        cover: j['cover'] as String? ?? '',
        sourceFile: j['source_file'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        deletedAt: DateTime.tryParse(j['deleted_at'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'number': number,
        'date': date,
        'cover': cover,
        'source_file': sourceFile,
        'created_at': createdAt.toIso8601String(),
        if (deletedAt != null) 'deleted_at': deletedAt!.toIso8601String(),
      };

  /// «№ 1 Техкарта Бар Чай Кофе 03.04.2026 (2).xlsx» → (Бар Чай Кофе, 1, 03.04.2026).
  static (String, String, String) parseFileName(String fileName) {
    var s = fileName.replaceFirst(RegExp(r'\.xlsx?$', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\(\d+\)'), ' ');
    final number = RegExp(r'№\s*(\d+)').firstMatch(s)?.group(1) ?? '';
    final date = RegExp(r'\d{1,2}\.\d{1,2}\.\d{2,4}').firstMatch(s)?.group(0) ?? '';
    s = s
        .replaceAll(RegExp(r'№\s*\d+'), ' ')
        .replaceAll(RegExp(r'\d{1,2}\.\d{1,2}\.\d{2,4}'), ' ')
        .replaceAll(RegExp(r'тех\.?\s*карт[аы]?', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return (s.isEmpty ? 'Техкарта' : s, number, date);
  }
}
