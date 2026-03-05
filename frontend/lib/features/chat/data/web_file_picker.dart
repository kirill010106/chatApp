import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Result of a file pick operation on web.
class WebFilePickResult {
  final String name;
  final Uint8List bytes;
  final String mimeType;
  final int size;

  WebFilePickResult({
    required this.name,
    required this.bytes,
    required this.mimeType,
    required this.size,
  });
}

/// Pick a file using a native HTML file input.
/// Returns null if user cancels.
Future<WebFilePickResult?> pickFileWeb({
  String accept = 'image/*,video/mp4,video/webm,audio/mpeg,audio/ogg,application/pdf',
}) async {
  final completer = Completer<WebFilePickResult?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;

  // Listen for file selection
  input.addEventListener(
    'change',
    (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        completer.complete(null);
        return;
      }

      final file = files.item(0)!;
      final reader = web.FileReader();

      reader.addEventListener(
        'load',
        (web.Event e) {
          final result = reader.result;
          if (result == null) {
            completer.complete(null);
            return;
          }
          final arrayBuffer = result as JSArrayBuffer;
          final bytes = arrayBuffer.toDart.asUint8List();

          completer.complete(WebFilePickResult(
            name: file.name,
            bytes: bytes,
            mimeType: file.type,
            size: file.size,
          ));
        }.toJS,
      );

      reader.addEventListener(
        'error',
        (web.Event e) {
          completer.complete(null);
        }.toJS,
      );

      reader.readAsArrayBuffer(file);
    }.toJS,
  );

  // Handle cancel (input loses focus without selecting)
  input.addEventListener(
    'cancel',
    (web.Event event) {
      completer.complete(null);
    }.toJS,
  );

  // Trigger file dialog
  input.click();

  return completer.future;
}
