// Native implementation (iOS, macOS, Windows, Android)
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class FileServiceImpl {
  static Future<String> readFileAsString(dynamic file) async {
    if (file is File) {
      return await file.readAsString(encoding: utf8);
    } else if (file is PlatformFile) {
      if (file.path != null) {
        final ioFile = File(file.path!);
        return await ioFile.readAsString(encoding: utf8);
      } else {
        throw Exception('File path is null on native platform');
      }
    } else {
      throw Exception('Invalid file type for native platform');
    }
  }
  
  static String getFileName(dynamic file) {
    if (file is File) {
      return file.path.split('/').last;
    } else if (file is PlatformFile) {
      return file.name;
    } else {
      throw Exception('Invalid file type for native platform');
    }
  }
}