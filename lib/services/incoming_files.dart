// Excel-файл, открытый в Mone Menu из другого приложения: на Android в
// Telegram «Открыть с помощью» / «Поделиться» → Mone Menu (см. MainActivity.kt).

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('mone_menu/incoming');

/// Отдаёт в [onFile] файл, с которым программу запустили, и все, что
/// откроют в ней потом. Возвращает функцию, которая снимает подписку.
VoidCallback listenIncomingFiles(void Function(String name, Uint8List bytes) onFile) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return () {};
  void deliver(Object? file) {
    if (file is! Map) return;
    final name = file['name'], bytes = file['bytes'];
    if (name is String && bytes is Uint8List) onFile(name, bytes);
  }

  _channel.setMethodCallHandler((call) async {
    if (call.method == 'file') deliver(call.arguments);
  });
  _channel.invokeMethod<Object?>('take').then(deliver, onError: (_) {});
  return () => _channel.setMethodCallHandler(null);
}
