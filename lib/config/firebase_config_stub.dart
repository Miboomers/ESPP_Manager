import 'package:firebase_core/firebase_core.dart';

/// Stub Firebase configuration for CI/CD builds and development
/// The real firebase_config.dart file will override this when present
class FirebaseConfig {
  // Demo configuration for CI/CD builds
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-api-key-for-ci-builds',
    authDomain: 'espp-manager.firebaseapp.com',
    projectId: 'espp-manager',
    storageBucket: 'espp-manager.appspot.com',
    messagingSenderId: '123456789',
    appId: 'demo-app-id-web',
    measurementId: 'G-DEMO123',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo-api-key-for-ci-builds',
    appId: 'demo-app-id-ios',
    messagingSenderId: '123456789',
    projectId: 'espp-manager',
    storageBucket: 'espp-manager.appspot.com',
    iosBundleId: 'com.miboomers.esppmanager',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'demo-api-key-for-ci-builds',
    appId: 'demo-app-id-macos',
    messagingSenderId: '123456789',
    projectId: 'espp-manager',
    storageBucket: 'espp-manager.appspot.com',
    iosBundleId: 'com.miboomers.esppmanager',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'demo-api-key-for-ci-builds',
    appId: 'demo-app-id-windows',
    messagingSenderId: '123456789',
    projectId: 'espp-manager',
    storageBucket: 'espp-manager.appspot.com',
  );
}