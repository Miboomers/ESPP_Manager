// Platform-agnostic file service with conditional imports
import 'file_service_stub.dart'
    if (dart.library.io) 'file_service_io.dart'
    if (dart.library.js_interop) 'file_service_web.dart';

class FileService {
  static Future<String> readFileAsString(dynamic file) {
    return FileServiceImpl.readFileAsString(file);
  }
  
  static String getFileName(dynamic file) {
    return FileServiceImpl.getFileName(file);
  }
}