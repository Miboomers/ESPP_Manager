import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

// Import Firebase configuration via loader
// The loader will use real config locally or stub for CI/CD
import '../../config/firebase_config_loader.dart' as firebase_config;

class FirebaseInitService {
  static bool _initialized = false;
  
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Use platform-specific Firebase options
      FirebaseOptions firebaseOptions;
      
      // Use Firebase config (real config will override stub if present)
      if (kIsWeb) {
        firebaseOptions = firebase_config.FirebaseConfig.web;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        firebaseOptions = firebase_config.FirebaseConfig.ios;
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        firebaseOptions = firebase_config.FirebaseConfig.macos;
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        firebaseOptions = firebase_config.FirebaseConfig.windows;
      } else {
        throw UnsupportedError('Unsupported platform');
      }
      
      await Firebase.initializeApp(options: firebaseOptions);
      
      // setPersistence is only supported on web platforms
      // macOS handles persistence automatically
      
      _initialized = true;
      debugPrint('✅ Firebase erfolgreich initialisiert für Projekt: espp-manager');
    } catch (e) {
      // App funktioniert weiter im Offline-Modus
      _initialized = false;
    }
  }
  
  static bool get isInitialized => _initialized;

  // Check if real Firebase config is available
  static Future<bool> _hasRealFirebaseConfig() async {
    try {
      // On web, we can't access files - check if we have real API keys
      if (kIsWeb) {
        // Check if web config has real keys (not demo keys)
        final hasRealKeys = !firebase_config.FirebaseConfig.web.apiKey.contains('demo-api-key');
        return hasRealKeys;
      }
      
      // On other platforms, check if the real config file exists
      final configFile = File('lib/config/firebase_config.dart');
      final exists = await configFile.exists();
      
      if (exists) {
        // Also check if it contains real API keys (not demo keys)
        final content = await configFile.readAsString();
        final hasRealKeys = !content.contains('demo-api-key-for-ci-builds');
        return hasRealKeys;
      }
      
      return false;
    } catch (e) {
      // On web or if file access fails, assume we have real config
      if (kIsWeb) return true;
      return false;
    }
  }
}