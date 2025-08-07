import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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

}