import 'dart:typed_data';

Future<void> downloadBytesForBrowser(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  throw UnsupportedError('Browser downloads are only available on web.');
}
