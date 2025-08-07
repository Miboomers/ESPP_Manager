// Stub implementation for unsupported platforms
class FileServiceImpl {
  static Future<String> readFileAsString(dynamic file) async {
    throw UnsupportedError('File service not supported on this platform');
  }
  
  static String getFileName(dynamic file) {
    throw UnsupportedError('File service not supported on this platform');
  }
}