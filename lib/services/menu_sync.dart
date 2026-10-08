// Синхронизация с сервером Mone (mone_app_backend, /api/menu): вход по паролю,
// «Отправить на сервер» (фото загружаются через /api/upload, в меню уходят их
// адреса) и «Загрузить с сервера» (фото скачиваются в локальное хранилище).
//
// На сервере количество хранится целым числом в тысячных: amount_milli
// (7,5 гр → 7500) — правило проекта «float не сохраняется».

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../provider/menu_provider.dart';
import '../ui/models/tech_card.dart';
import 'card_storage.dart';

const defaultServerUrl = 'https://moneapp.monebakeryuz.uz';

/// Сервер изменён с другого устройства после нашей последней синхронизации.
class MenuConflict implements Exception {
  final int serverRevision;
  MenuConflict(this.serverRevision);
}

class MenuSyncException implements Exception {
  final String message;
  MenuSyncException(this.message);
  @override
  String toString() => message;
}

/// Состояние входа и синхронизации; хранится в настройках (settings.json).
class MenuSync extends ChangeNotifier {
  final CardStorage storage;
  final MenuProvider menu;
  final http.Client _http;
  Map<String, dynamic> _settings;

  MenuSync({required this.storage, required this.menu, required Map<String, dynamic> settings, http.Client? client})
      : _settings = {...settings},
        _http = client ?? http.Client();

  bool busy = false;

  String get serverUrl => (_settings['server_url'] as String?) ?? defaultServerUrl;
  String? get token => _settings['server_token'] as String?;
  String get userName => (_settings['server_user'] as String?) ?? '';
  bool get canEdit => _settings['server_can_edit'] == true;
  int get revision => (_settings['server_revision'] as num?)?.toInt() ?? 0;
  DateTime? get lastSync => DateTime.tryParse(_settings['server_synced_at'] as String? ?? '');
  bool get loggedIn => token != null;

  /// Локальный путь фото → адрес на сервере ("/static/…").
  Map<String, String> get _photoUrls => Map<String, String>.from(_settings['photo_urls'] as Map? ?? {});

  Future<void> _saveSettings(Map<String, dynamic> patch) async {
    final fresh = await storage.loadSettings(); // язык меняется в другом месте — берём свежие
    _settings = {...fresh, ...patch}..removeWhere((_, v) => v == null);
    await storage.saveSettings(_settings);
    notifyListeners();
  }

  Uri _u(String path) => Uri.parse('${serverUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Qty-Unit': 'milli',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _decode(http.Response r) {
    try {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw MenuSyncException('Сервер ответил ${r.statusCode}');
    }
  }

  Future<T> _run<T>(Future<T> Function() job) async {
    busy = true;
    notifyListeners();
    try {
      return await job();
    } on MenuSyncException {
      rethrow;
    } on MenuConflict {
      rethrow;
    } catch (e) {
      throw MenuSyncException('Нет связи с сервером: $e');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Вход по паролю (как в приложении Mone). Редактировать меню на сервере
  /// могут админ и шеф.
  Future<void> login(String url, String password) => _run(() async {
        await _saveSettings({'server_url': url.trim().isEmpty ? defaultServerUrl : url.trim()});
        final r = await _http.post(_u('/api/v1/login'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode({'password': password}));
        final body = _decode(r);
        if (r.statusCode != 200 || body['success'] != true) {
          throw MenuSyncException(body['message'] as String? ?? 'Не удалось войти');
        }
        final data = body['data'] as Map<String, dynamic>;
        final user = data['user'] as Map<String, dynamic>? ?? {};
        await _saveSettings({
          'server_token': data['token'],
          'server_user': user['name'] ?? '',
          'server_can_edit': user['is_admin'] == true || user['role'] == 'shef',
        });
      });

  Future<void> logout() => _saveSettings({
        'server_token': null,
        'server_user': null,
        'server_can_edit': null,
      });

  // ---------- отправка ----------

  /// Отправить все техкарты (и скрытые) на сервер. [force] — перезаписать,
  /// даже если там есть чужие изменения.
  Future<int> push({bool force = false}) => _run(() async {
        final urls = _photoUrls;
        Future<String> upload(String path) async {
          if (path.isEmpty) return '';
          final known = urls[path];
          if (known != null) return known;
          final bytes = await storage.readPhoto(path);
          if (bytes == null) return '';
          final url = await _uploadPhoto(path, bytes);
          urls[path] = url;
          return url;
        }

        final books = <Map<String, dynamic>>[];
        for (final b in menu.allBooks) {
          books.add({...b.toJson(), 'cover': await upload(b.cover)});
        }
        final cards = <Map<String, dynamic>>[];
        for (final c in menu.allCards) {
          cards.add(_cardToServer(c, [for (final p in c.photos) await upload(p)]));
        }
        await _saveSettings({'photo_urls': urls});

        final r = await _http.put(_u('/api/menu'),
            headers: _headers,
            body: jsonEncode({'base_revision': revision, 'force': force, 'books': books, 'cards': cards}));
        final body = _decode(r);
        if (r.statusCode == 409) {
          throw MenuConflict(((body['data'] as Map?)?['revision'] as num?)?.toInt() ?? 0);
        }
        _checkAuth(r, body);
        if (r.statusCode != 200 || body['success'] != true) {
          throw MenuSyncException(body['message'] as String? ?? 'Ошибка сервера ${r.statusCode}');
        }
        final rev = ((body['data'] as Map)['revision'] as num).toInt();
        await _saveSettings({'server_revision': rev, 'server_synced_at': DateTime.now().toIso8601String()});
        return cards.length;
      });

  Future<String> _uploadPhoto(String path, Uint8List bytes) async {
    // Имя файла уникальное: сервер кладёт фото в uploads/<имя>_resized.jpg.
    final name = 'menu_${path.split(RegExp(r'[\\/]')).last}';
    final req = http.MultipartRequest('POST', _u('/api/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('image', bytes, filename: name));
    final r = await http.Response.fromStream(await _http.send(req));
    final body = _decode(r);
    _checkAuth(r, body);
    final url = body['url'] as String?;
    if (r.statusCode != 200 || url == null) throw MenuSyncException('Фото не загрузилось: ${r.statusCode}');
    return url;
  }

  // ---------- загрузка ----------

  /// Загрузить меню с сервера и заменить им локальные данные.
  Future<int> pull() => _run(() async {
        final r = await _http.get(_u('/api/menu'), headers: _headers);
        final body = _decode(r);
        _checkAuth(r, body);
        if (r.statusCode != 200 || body['success'] != true) {
          throw MenuSyncException(body['message'] as String? ?? 'Ошибка сервера ${r.statusCode}');
        }
        final data = body['data'] as Map<String, dynamic>;
        final urls = _photoUrls;
        final byUrl = {for (final e in urls.entries) e.value: e.key};
        Future<String> local(String url) async {
          if (url.isEmpty) return '';
          final have = byUrl[url];
          if (have != null && await storage.readPhoto(have) != null) return have;
          final res = await _http.get(_u(url));
          if (res.statusCode != 200) return '';
          final path = await storage.savePhoto(res.bodyBytes, 'jpg');
          byUrl[url] = path;
          urls[path] = url;
          return path;
        }

        final books = <TechBook>[];
        for (final j in (data['books'] as List).cast<Map<String, dynamic>>()) {
          books.add(TechBook.fromJson({...j, 'cover': await local(j['cover'] as String? ?? '')}));
        }
        final cards = <TechCard>[];
        for (final j in (data['cards'] as List).cast<Map<String, dynamic>>()) {
          final photos = [for (final u in (j['photos'] as List? ?? []).cast<String>()) await local(u)]
            ..removeWhere((p) => p.isEmpty);
          cards.add(_cardFromServer(j, photos));
        }
        await menu.replaceAll(books, cards);
        urls.removeWhere((path, _) => !{for (final c in cards) ...c.photos, for (final b in books) b.cover}.contains(path));
        await _saveSettings({
          'photo_urls': urls,
          'server_revision': (data['revision'] as num).toInt(),
          'server_synced_at': DateTime.now().toIso8601String(),
        });
        return cards.length;
      });

  void _checkAuth(http.Response r, Map<String, dynamic> body) {
    if (r.statusCode == 401) {
      logout();
      throw MenuSyncException('Сессия истекла — войдите снова');
    }
    if (r.statusCode == 403) {
      throw MenuSyncException(body['message'] as String? ?? 'Нет прав на изменение меню');
    }
  }
}

/// Позиция в формате сервера: фото — адреса, количество — amount_milli.
Map<String, dynamic> _cardToServer(TechCard c, List<String> photoUrls) {
  final j = c.toJson();
  j['photos'] = photoUrls.where((u) => u.isNotEmpty).toList();
  j['variants'] = [
    for (final v in c.variants)
      {
        ...v.toJson(),
        'ingredients': [
          for (final i in v.ingredients) {'name': i.name, 'unit': i.unit, 'amount_milli': (i.amount * 1000).round()},
        ],
      },
  ];
  return j;
}

TechCard _cardFromServer(Map<String, dynamic> j, List<String> photos) {
  final variants = [
    for (final v in (j['variants'] as List? ?? []).cast<Map<String, dynamic>>())
      {
        ...v,
        'ingredients': [
          for (final i in (v['ingredients'] as List? ?? []).cast<Map<String, dynamic>>())
            {'name': i['name'], 'unit': i['unit'], 'amount': ((i['amount_milli'] as num?) ?? 0) / 1000},
        ],
      },
  ];
  return TechCard.fromJson({...j, 'variants': variants, 'photos': photos});
}

@visibleForTesting
Map<String, dynamic> cardToServerForTest(TechCard c, List<String> urls) => _cardToServer(c, urls);
@visibleForTesting
TechCard cardFromServerForTest(Map<String, dynamic> j, List<String> photos) => _cardFromServer(j, photos);
