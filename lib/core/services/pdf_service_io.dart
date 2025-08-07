// Native implementation (iOS, macOS, Windows, Android)
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class PdfServiceImpl {
  static Future<void> savePdf({
    required List<int> bytes,
    required String filename,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$filename');
    await file.writeAsBytes(bytes);
    await OpenFile.open(file.path);
  }
}