// Platform-agnostic PDF service with conditional imports
import 'pdf_service_stub.dart'
    if (dart.library.io) 'pdf_service_io.dart'
    if (dart.library.js_interop) 'pdf_service_web.dart';

class PdfService {
  static Future<void> savePdf({
    required List<int> bytes,
    required String filename,
  }) {
    return PdfServiceImpl.savePdf(bytes: bytes, filename: filename);
  }
}