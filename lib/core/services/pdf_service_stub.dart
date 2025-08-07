// Stub implementation - fallback for unsupported platforms
class PdfServiceImpl {
  static Future<void> savePdf({
    required List<int> bytes,
    required String filename,
  }) async {
    throw UnimplementedError('PDF service not available on this platform');
  }
}