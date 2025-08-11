import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Conditional import für FlutterSecureStorage (nur für native Plattformen)
// ignore: avoid_web_libraries_in_flutter
import 'package:flutter_secure_storage/flutter_secure_storage.dart' if (dart.library.html) 'dart:html';

// Conditional imports für Secure Storage
// Web-Plattform verwendet SharedPreferences
// Native-Plattformen verwenden FlutterSecureStorage

abstract class SecureStorageInterface {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

// Web-Implementation mit SharedPreferences
class WebSecureStorage implements SecureStorageInterface {
  @override
  Future<void> write({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
  
  @override
  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }
  
  @override
  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

// Native-Implementation mit FlutterSecureStorage
class NativeSecureStorage implements SecureStorageInterface {
  // Lazy loading für FlutterSecureStorage
  dynamic _storage;
  
  dynamic get storage {
    if (_storage == null) {
      // Conditional import für FlutterSecureStorage
      if (!kIsWeb) {
        // ignore: avoid_web_libraries_in_flutter
        _storage = const FlutterSecureStorage();
      }
    }
    return _storage;
  }
  
  @override
  Future<void> write({required String key, required String value}) async {
    if (kIsWeb) {
      // Fallback für Web
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await storage.write(key: key, value: value);
    }
  }
  
  @override
  Future<String?> read({required String key}) async {
    if (kIsWeb) {
      // Fallback für Web
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await storage.read(key: key);
    }
  }
  
  @override
  Future<void> delete({required String key}) async {
    if (kIsWeb) {
      // Fallback für Web
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await storage.delete(key: key);
    }
  }
}
