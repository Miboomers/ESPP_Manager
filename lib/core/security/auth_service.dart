import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static const String _pinKey = 'user_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastActivityKey = 'last_activity';
  
  final FlutterSecureStorage? _secureStorage;
  final LocalAuthentication _localAuth;
  
  AuthService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _secureStorage = kIsWeb || defaultTargetPlatform == TargetPlatform.macOS 
          ? null 
          : secureStorage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication();
  
  Future<bool> isPinSet() async {
    if (_secureStorage != null) {
      final pin = await _secureStorage!.read(key: _pinKey);
      return pin != null;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString(_pinKey);
      return pin != null;
    }
  }
  
  Future<void> setPin(String pin) async {
    final hashedPin = _hashPin(pin);
    if (_secureStorage != null) {
      await _secureStorage!.write(key: _pinKey, value: hashedPin);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, hashedPin);
    }
    
    // Initialize PIN path in cloud if user is authenticated
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('🔑 PIN gesetzt, initialisiere PIN-Pfad in der Cloud...');
        await _initializePinPathInCloud(pin, user.uid);
        debugPrint('✅ PIN-Pfad in der Cloud erfolgreich initialisiert');
      } else {
        debugPrint('ℹ️ User nicht bei Firebase angemeldet, PIN-Pfad wird später initialisiert');
      }
    } catch (e) {
      debugPrint('⚠️ Fehler beim Initialisieren des PIN-Pfads in der Cloud: $e');
      // Don't rethrow - PIN setting should still work locally
    }
  }
  
  /// Initialize PIN path in cloud when PIN is set
  Future<void> _initializePinPathInCloud(String pin, String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final pinPath = 'users/$uid/pin';
      
      debugPrint('🔍 Initialisiere PIN-Pfad: $pinPath');
      
      final pinHash = _hashPin(pin);
      final pinVersion = DateTime.now().millisecondsSinceEpoch;
      
      final pinData = {
        'pin_hash': pinHash,
        'pin_version': pinVersion,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'initial_setup': true,
      };
      
      await firestore.doc(pinPath).set(pinData);
      debugPrint('✅ PIN-Dokument in der Cloud erstellt');
      
    } catch (e) {
      debugPrint('❌ Fehler beim Erstellen des PIN-Dokuments: $e');
      rethrow;
    }
  }
  
  Future<bool> verifyPin(String pin) async {
    String? storedHash;
    if (_secureStorage != null) {
      storedHash = await _secureStorage!.read(key: _pinKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      storedHash = prefs.getString(_pinKey);
    }
    
    if (storedHash == null) return false;
    
    final inputHash = _hashPin(pin);
    return storedHash == inputHash;
  }
  
  /// Get the stored PIN (for internal use only)
  Future<String?> getStoredPin() async {
    if (_secureStorage != null) {
      return await _secureStorage!.read(key: _pinKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pinKey);
    }
  }
  
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Prüft, ob Biometrie auf der aktuellen Plattform verfügbar ist
  Future<bool> isBiometricAvailable() async {
    // Web-Plattformen unterstützen keine lokale Biometrie
    if (kIsWeb) {
      return false;
    }
    
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }
  
  /// Gibt verfügbare Biometrie-Typen zurück (nur auf unterstützten Plattformen)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) {
      return [];
    }
    
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  /// Aktiviert/Deaktiviert Biometrie (nur auf unterstützten Plattformen)
  Future<void> setBiometricEnabled(bool enabled) async {
    if (_secureStorage != null) {
      await _secureStorage!.write(
        key: _biometricEnabledKey,
        value: enabled.toString(),
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, enabled);
    }
  }
  
  /// Logout: Reset authentication state without deleting data
  Future<void> logout() async {
    try {
      // Reset last activity timestamp
      if (_secureStorage != null) {
        await _secureStorage!.delete(key: _lastActivityKey);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_lastActivityKey);
      }
      
      // Note: We don't delete the PIN or biometric settings
      // This allows the user to log back in with the same credentials
      // All data remains encrypted and secure
      
      debugPrint('Logout completed - authentication state reset');
    } catch (e) {
      debugPrint('Error during logout: $e');
      rethrow;
    }
  }
  
  /// Prüft, ob Biometrie aktiviert ist
  Future<bool> isBiometricEnabled() async {
    if (_secureStorage != null) {
      final value = await _secureStorage!.read(key: _biometricEnabledKey);
      return value == 'true';
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    }
  }
  
  /// Authentifizierung über Biometrie (nur auf unterstützten Plattformen)
  Future<bool> authenticateWithBiometric() async {
    // Web-Plattformen verwenden PIN-basierte Authentifizierung
    if (kIsWeb) {
      return false;
    }
    
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Bitte authentifizieren Sie sich für den Zugriff auf ESPP Manager',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (authenticated) {
        await updateLastActivity();
      }
      
      return authenticated;
    } catch (e) {
      return false;
    }
  }
  
  /// Hauptauthentifizierungsmethode
  Future<bool> authenticate({String? pin}) async {
    if (pin != null) {
      final verified = await verifyPin(pin);
      if (verified) {
        await updateLastActivity();
      }
      return verified;
    }
    
    // Prüfe Biometrie nur auf unterstützten Plattformen
    if (!kIsWeb) {
      final biometricEnabled = await isBiometricEnabled();
      if (biometricEnabled) {
        return await authenticateWithBiometric();
      }
    }
    
    return false;
  }
  
  Future<void> updateLastActivity() async {
    final now = DateTime.now().toIso8601String();
    if (_secureStorage != null) {
      await _secureStorage!.write(key: _lastActivityKey, value: now);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastActivityKey, now);
    }
  }
  
  Future<bool> shouldAutoLock() async {
    String? lastActivityStr;
    if (_secureStorage != null) {
      lastActivityStr = await _secureStorage!.read(key: _lastActivityKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      lastActivityStr = prefs.getString(_lastActivityKey);
    }
    
    if (lastActivityStr == null) return false;
    
    try {
      final lastActivity = DateTime.parse(lastActivityStr);
      final now = DateTime.now();
      final difference = now.difference(lastActivity);
      
      // Auto-Lock nach 5 Minuten Inaktivität
      return difference.inMinutes >= 5;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> clearLastActivity() async {
    if (_secureStorage != null) {
      await _secureStorage!.delete(key: _lastActivityKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastActivityKey);
    }
  }
  
  /// Plattformspezifische Konfiguration
  Map<String, dynamic> getPlatformConfig() {
    return {
      'isWeb': kIsWeb,
      'supportsBiometrics': !kIsWeb,
      'supportsSecureStorage': _secureStorage != null,
      'platform': _getPlatformString(),
    };
  }
  
  String _getPlatformString() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return 'unknown';
  }
}