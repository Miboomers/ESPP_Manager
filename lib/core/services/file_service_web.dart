// Web implementation using bytes
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class FileServiceImpl {
  static Future<String> readFileAsString(dynamic file) async {
    if (file is PlatformFile) {
      if (file.bytes == null) {
        throw Exception('File bytes are null on web platform');
      }
      
      // Decode bytes to string with UTF-8
      final bytes = file.bytes!;
      String content = utf8.decode(bytes);
      
      // Remove BOM if present
      if (content.startsWith('\ufeff')) {
        content = content.substring(1);
      }
      
      return content;
    } else {
      throw Exception('Invalid file type for web platform');
    }
  }
  
  static String getFileName(dynamic file) {
    if (file is PlatformFile) {
      return file.name;
    } else {
      throw Exception('Invalid file type for web platform');
    }
  }
}