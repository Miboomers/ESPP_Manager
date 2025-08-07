// Web implementation using printing package
import 'dart:typed_data';
import 'package:printing/printing.dart';

class PdfServiceImpl {
  static Future<void> savePdf({
    required List<int> bytes,
    required String filename,
  }) async {
    final uint8bytes = Uint8List.fromList(bytes);
    await Printing.sharePdf(bytes: uint8bytes, filename: filename);
  }
}