import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
// Try to import private config, fall back to example if not exists
import '../../config/firebase_config.dart' if (dart.library.html) '../../config/firebase_config.dart';

class FirebaseInitService {
  static bool _initialized = false;
  
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Use platform-specific Firebase options from config file
      FirebaseOptions firebaseOptions;
      
      if (kIsWeb) {
        firebaseOptions = FirebaseConfig.web;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        firebaseOptions = FirebaseConfig.ios;
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        firebaseOptions = FirebaseConfig.macos;
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        firebaseOptions = FirebaseConfig.windows;
      } else {
        throw UnsupportedError('Unsupported platform');
      }
      
      await Firebase.initializeApp(options: firebaseOptions);
      
      // setPersistence is only supported on web platforms
      // macOS handles persistence automatically
      
      _initialized = true;
      debugPrint('✅ Firebase erfolgreich initialisiert für Projekt: espp-manager');
    } catch (e) {
      debugPrint('❌ Firebase Initialisierung fehlgeschlagen: $e');
      // App funktioniert weiter im Offline-Modus
      _initialized = false;
    }
  }
  
  static bool get isInitialized => _initialized;
}