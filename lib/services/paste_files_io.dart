import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Слушать Ctrl+V (⌘V) и отдавать вставленный файл в [onFile].
/// Возвращает функцию, которая снимает подписку.
VoidCallback listenPastedFiles(void Function(String name, Uint8List bytes) onFile) {
  bool handler(KeyEvent e) {
    final keys = HardwareKeyboard.instance;
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.keyV &&
        (keys.isControlPressed || keys.isMetaPressed)) {
      _readPasted().then((f) {
        if (f != null) onFile(f.$1, f.$2);
      });
    }
    return false; // не мешаем вставке текста в поля
  }

  HardwareKeyboard.instance.addHandler(handler);
  return () => HardwareKeyboard.instance.removeHandler(handler);
}

Future<(String, Uint8List)?> _readPasted() async {
  final paths = Platform.isWindows ? _windowsClipboardFiles() : <String>[];
  if (paths.isEmpty) {
    // «Копировать как путь» в Проводнике: "C:\...\файл.xlsx"
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text != null && text.isNotEmpty && !text.contains('\n')) paths.add(text.replaceAll('"', ''));
  }
  for (final path in paths) {
    final f = File(path);
    if (await f.exists()) return (p.basename(path), await f.readAsBytes());
  }
  return null;
}

// --- Windows: файлы, скопированные в Проводнике (формат CF_HDROP) ---

const _cfHdrop = 15;

final _user32 = DynamicLibrary.open('user32.dll');
final _shell32 = DynamicLibrary.open('shell32.dll');
final _openClipboard = _user32.lookupFunction<Int32 Function(Pointer), int Function(Pointer)>('OpenClipboard');
final _closeClipboard = _user32.lookupFunction<Int32 Function(), int Function()>('CloseClipboard');
final _getClipboardData =
    _user32.lookupFunction<Pointer Function(Uint32), Pointer Function(int)>('GetClipboardData');
final _dragQueryFile = _shell32.lookupFunction<Uint32 Function(Pointer, Uint32, Pointer<Utf16>, Uint32),
    int Function(Pointer, int, Pointer<Utf16>, int)>('DragQueryFileW');

List<String> _windowsClipboardFiles() {
  if (_openClipboard(nullptr) == 0) return [];
  try {
    final drop = _getClipboardData(_cfHdrop);
    if (drop == nullptr) return [];
    final count = _dragQueryFile(drop, 0xFFFFFFFF, nullptr, 0);
    final buf = calloc<Uint16>(1024).cast<Utf16>();
    try {
      return [
        for (var i = 0; i < count; i++) buf.toDartString(length: _dragQueryFile(drop, i, buf, 1024)),
      ];
    } finally {
      calloc.free(buf);
    }
  } finally {
    _closeClipboard();
  }
}
