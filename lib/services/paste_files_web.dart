import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Слушать вставку (Ctrl+V / ⌘V) и отдавать вставленный файл в [onFile].
/// Возвращает функцию, которая снимает подписку.
VoidCallback listenPastedFiles(void Function(String name, Uint8List bytes) onFile) {
  final listener = ((web.ClipboardEvent e) {
    final files = e.clipboardData?.files;
    if (files == null || files.length == 0) return;
    final file = files.item(0)!;
    file.arrayBuffer().toDart.then((b) => onFile(file.name, b.toDart.asUint8List()));
  }).toJS;
  web.document.addEventListener('paste', listener);
  return () => web.document.removeEventListener('paste', listener);
}
