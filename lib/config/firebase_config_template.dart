// TEMPLATE für firebase_config.dart mit 2 verschiedenen Keys
// Kopieren Sie dies in firebase_config.dart und fügen Sie Ihre Keys ein

import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // WEB: Nutzt den Key mit HTTP Referrer Einschränkungen
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'IHR_WEB_API_KEY_MIT_HTTP_EINSCHRÄNKUNGEN',  // Der erste Key
    appId: '1:521663857148:web:YOUR_WEB_APP_ID',
    messagingSenderId: '521663857148',
    projectId: 'espp-manager',
    authDomain: 'espp-manager.firebaseapp.com',
    storageBucket: 'espp-manager.firebasestorage.app',
  );

  // iOS: Nutzt den Key OHNE Einschränkungen
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'IHR_DESKTOP_MOBILE_API_KEY_OHNE_EINSCHRÄNKUNGEN',  // Der zweite Key
    appId: '1:521663857148:ios:49746c97ffd7067f253279',
    messagingSenderId: '521663857148',
    projectId: 'espp-manager',
    storageBucket: 'espp-manager.firebasestorage.app',
    iosBundleId: 'com.miboomers.esppmanager',
  );

  // macOS: Nutzt den Key OHNE Einschränkungen
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'IHR_DESKTOP_MOBILE_API_KEY_OHNE_EINSCHRÄNKUNGEN',  // Der zweite Key
    appId: '1:521663857148:ios:49746c97ffd7067f253279',
    messagingSenderId: '521663857148',
    projectId: 'espp-manager',
    storageBucket: 'espp-manager.firebasestorage.app',
    iosBundleId: 'com.miboomers.esppmanager',
    authDomain: 'espp-manager.firebaseapp.com',
  );

  // Windows: Nutzt den Key OHNE Einschränkungen
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'IHR_DESKTOP_MOBILE_API_KEY_OHNE_EINSCHRÄNKUNGEN',  // Der zweite Key
    appId: '1:521663857148:web:YOUR_WINDOWS_APP_ID',
    messagingSenderId: '521663857148',
    projectId: 'espp-manager',
    authDomain: 'espp-manager.firebaseapp.com',
    storageBucket: 'espp-manager.firebasestorage.app',
  );
}