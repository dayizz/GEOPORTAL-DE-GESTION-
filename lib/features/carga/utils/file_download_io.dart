import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadBytes(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  final downloadsDir = await getDownloadsDirectory();
  final directory = downloadsDir ?? await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);

  if (downloadsDir == null) {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      text: 'Archivo exportado: $fileName',
    );
  }
}
