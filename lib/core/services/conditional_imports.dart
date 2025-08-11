import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Conditional import für native Implementation
// ignore: avoid_web_libraries_in_flutter
import 'conditional_imports_native.dart' if (dart.library.html) 'conditional_imports_web.dart';

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
    if (_storage == null && !kIsWeb) {
      // Nur für native Plattformen
      _storage = _createSecureStorage();
    }
    return _storage;
  }
  
  // Factory-Methode für FlutterSecureStorage
  dynamic _createSecureStorage() {
    if (kIsWeb) {
      return null;
    }
    return _createNativeSecureStorage();
  }
  
  // Diese Methode wird nur für native Plattformen kompiliert
  dynamic _createNativeSecureStorage() {
    return createNativeSecureStorage();
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

// Web-spezifische Hilfsfunktionen
String getWebUserAgent() {
  if (kIsWeb) {
    try {
      // ignore: avoid_web_libraries_in_flutter
      return _getWebUserAgentInternal();
    } catch (e) {
      return 'web-unknown';
    }
  }
  return 'unknown';
}

// Diese Funktion wird nur für Web-Compilation implementiert
String _getWebUserAgentInternal() {
  throw UnsupportedError('Web User Agent wird auf dieser Plattform nicht unterstützt');
}
