// Хранилище техкарт в браузере: IndexedDB (база mone_menu, таблица kv).
// cards.json лежит под ключом «cards.json», фото — под «photos/<имя>».
// Фото при загрузке читаются в память, чтобы показывать их без ожидания.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

import '../ui/models/tech_card.dart';

class CardStorage {
  static const _store = 'kv';
  static const _dataKey = 'cards.json';
  static const _settingsKey = 'settings.json';

  web.IDBDatabase? _db;
  final Map<String, Uint8List> _photos = {};
  int _seq = 0;

  Future<web.IDBDatabase> _open() async {
    if (_db != null) return _db!;
    final req = web.window.indexedDB.open('mone_menu', 1);
    req.onupgradeneeded = ((web.Event _) {
      (req.result as web.IDBDatabase).createObjectStore(_store);
    }).toJS;
    await _done(req);
    return _db = req.result as web.IDBDatabase;
  }

  /// Дождаться завершения запроса IndexedDB.
  static Future<void> _done(web.IDBRequest req) {
    final c = Completer<void>();
    req.onsuccess = ((web.Event _) => c.complete()).toJS;
    req.onerror = ((web.Event _) => c.completeError(req.error?.message ?? 'IndexedDB error')).toJS;
    return c.future;
  }

  Future<web.IDBObjectStore> _table(String mode) async =>
      (await _open()).transaction(_store.toJS, mode).objectStore(_store);

  Future<(List<TechBook>, List<TechCard>)> load() async {
    final store = await _table('readonly');
    final keysReq = store.getAllKeys();
    final valuesReq = store.getAll();
    // Подписаться на оба запроса сразу: второй может закончиться раньше первого.
    await Future.wait([_done(keysReq), _done(valuesReq)]);
    final keys = (keysReq.result as JSArray<JSAny?>).toDart;
    final values = (valuesReq.result as JSArray<JSAny?>).toDart;
    String? json;
    for (var i = 0; i < keys.length; i++) {
      final key = (keys[i] as JSString).toDart;
      if (key == _dataKey) {
        json = (values[i] as JSString).toDart;
      } else if (key.startsWith('photos/')) {
        _photos[key] = (values[i] as JSUint8Array).toDart;
      }
    }
    if (json == null) return (<TechBook>[], <TechCard>[]);
    final data = jsonDecode(json) as Map<String, dynamic>;
    final books = (data['books'] as List? ?? [])
        .map((e) => TechBook.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final cards = (data['cards'] as List? ?? [])
        .map((e) => TechCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (books, cards);
  }

  Future<void> save(List<TechBook> books, List<TechCard> cards) async {
    final json = jsonEncode({
      'version': 2,
      'books': books.map((e) => e.toJson()).toList(),
      'cards': cards.map((e) => e.toJson()).toList(),
    });
    await _done((await _table('readwrite')).put(json.toJS, _dataKey.toJS));
  }

  /// Сохраняет фото и возвращает его ключ.
  Future<String> savePhoto(Uint8List bytes, String ext) async {
    final key = 'photos/${DateTime.now().microsecondsSinceEpoch}_${_seq++}.${ext.isEmpty ? 'png' : ext}';
    await _done((await _table('readwrite')).put(bytes.toJS, key.toJS));
    _photos[key] = bytes;
    return key;
  }

  Future<void> deletePhoto(String key) async {
    _photos.remove(key);
    await _done((await _table('readwrite')).delete(key.toJS));
  }

  /// Байты фото (для отправки на сервер); null — фото нет.
  Future<Uint8List?> readPhoto(String key) async => _photos[key];

  /// Настройки (язык интерфейса и т. п.) — отдельно от техкарт.
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final req = (await _table('readonly')).get(_settingsKey.toJS);
      await _done(req);
      final v = req.result;
      if (v != null) return jsonDecode((v as JSString).toDart) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async =>
      _done((await _table('readwrite')).put(jsonEncode(settings).toJS, _settingsKey.toJS));

  /// Картинка для показа фото по ключу из [savePhoto]; null — фото нет.
  ImageProvider? photoImage(String key) {
    final bytes = _photos[key];
    return bytes == null ? null : MemoryImage(bytes);
  }
}
