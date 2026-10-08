// Хранилище техкарт: на Windows / Android / iOS / macOS / Linux — файлы
// (cards.json + photos/), в браузере — IndexedDB. API у обоих одинаковый.

export 'card_storage_io.dart' if (dart.library.js_interop) 'card_storage_web.dart';
