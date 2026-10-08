// Локальное хранилище техкарт: cards.json + папка photos/ в каталоге
// приложения. Пока без сервера — позже сюда встанет API mone_app.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ui/models/tech_card.dart';

class CardStorage {
  Directory? _root;
  int _seq = 0; // фото, сохранённые в одну микросекунду, не должны затирать друг друга

  Future<Directory> root() async {
    if (_root != null) return _root!;
    // MONE_MENU_DATA — своя папка данных (для проверки, не трогая рабочие данные).
    final override = Platform.environment['MONE_MENU_DATA'];
    final dir = override != null && override.isNotEmpty
        ? Directory(override)
        : Directory(p.join((await getApplicationSupportDirectory()).path, 'mone_menu'));
    await Directory(p.join(dir.path, 'photos')).create(recursive: true);
    return _root = dir;
  }

  Future<File> _file() async => File(p.join((await root()).path, 'cards.json'));

  Future<(List<TechBook>, List<TechCard>)> load() async {
    final f = await _file();
    if (!await f.exists()) return (<TechBook>[], <TechCard>[]);
    final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final books = (data['books'] as List? ?? [])
        .map((e) => TechBook.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final cards = (data['cards'] as List? ?? [])
        .map((e) => TechCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (books, cards);
  }

  Future<void> save(List<TechBook> books, List<TechCard> cards) async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert({
      'version': 2,
      'books': books.map((e) => e.toJson()).toList(),
      'cards': cards.map((e) => e.toJson()).toList(),
    }));
    await tmp.rename(f.path);
  }

  /// Сохраняет фото и возвращает путь к файлу.
  Future<String> savePhoto(Uint8List bytes, String ext) async {
    final dir = p.join((await root()).path, 'photos');
    final name = '${DateTime.now().microsecondsSinceEpoch}_${_seq++}.${ext.isEmpty ? 'png' : ext}';
    final file = File(p.join(dir, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> deletePhoto(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// Картинка для показа фото по пути из [savePhoto].
  ImageProvider? photoImage(String path) => FileImage(File(path));

  Future<File> _settingsFile() async => File(p.join((await root()).path, 'settings.json'));

  /// Настройки (язык интерфейса и т. п.) — отдельно от техкарт.
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final f = await _settingsFile();
      if (await f.exists()) return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async =>
      (await _settingsFile()).writeAsString(jsonEncode(settings));
}
