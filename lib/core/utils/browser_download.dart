import 'dart:typed_data';

import 'browser_download_stub.dart'
    if (dart.library.html) 'browser_download_web.dart' as impl;

Future<void> downloadBytesForBrowser(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) {
  return impl.downloadBytesForBrowser(
    bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}
