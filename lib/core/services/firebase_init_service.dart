import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseInitService {
  static bool _initialized = false;
  
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Firebase Options für verschiedene Plattformen
      const firebaseOptions = FirebaseOptions(
        // Diese Werte kommen aus der Firebase Console
        // Projekt: ESPP Manager
        apiKey: 'AIzaSyDummy-Key-Replace-With-Real', 
        appId: '1:123456789:ios:abcdef',
        messagingSenderId: '123456789',
        projectId: 'espp-manager',
        storageBucket: 'espp-manager.appspot.com',
        
        // iOS specific
        iosBundleId: 'com.miboomers.esppmanager',
        
        // Android specific  
        androidClientId: 'android-client-id',
      );
      
      await Firebase.initializeApp(
        options: firebaseOptions,
      );
      
      _initialized = true;
      debugPrint('✅ Firebase erfolgreich initialisiert');
    } catch (e) {
      debugPrint('❌ Firebase Initialisierung fehlgeschlagen: $e');
      // App funktioniert weiter im Offline-Modus
      _initialized = false;
    }
  }
  
  static bool get isInitialized => _initialized;
}