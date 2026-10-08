// Вставка файла из буфера обмена по Ctrl+V (⌘V): на компьютере — файл,
// скопированный в Проводнике (или путь к нему), в браузере — событие paste.

export 'paste_files_io.dart' if (dart.library.js_interop) 'paste_files_web.dart';
