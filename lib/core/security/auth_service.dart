import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _pinKey = 'espp_pin_hash';
  static const String _biometricEnabledKey = 'espp_biometric_enabled';
  static const String _lastActivityKey = 'espp_last_activity';
  static const int autoLockMinutes = 5;
  
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
  
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }
  
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
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
  
  Future<bool> isBiometricEnabled() async {
    if (_secureStorage != null) {
      final value = await _secureStorage!.read(key: _biometricEnabledKey);
      return value == 'true';
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    }
  }
  
  Future<bool> authenticateWithBiometric() async {
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
  
  Future<bool> authenticate({String? pin}) async {
    if (pin != null) {
      final verified = await verifyPin(pin);
      if (verified) {
        await updateLastActivity();
      }
      return verified;
    }
    
    final biometricEnabled = await isBiometricEnabled();
    if (biometricEnabled) {
      return await authenticateWithBiometric();
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
    
    if (lastActivityStr == null) return true;
    
    final lastActivity = DateTime.parse(lastActivityStr);
    final now = DateTime.now();
    final difference = now.difference(lastActivity);
    
    return difference.inMinutes >= autoLockMinutes;
  }
  
  Future<void> clearAuth() async {
    if (_secureStorage != null) {
      await _secureStorage!.delete(key: _pinKey);
      await _secureStorage!.delete(key: _biometricEnabledKey);
      await _secureStorage!.delete(key: _lastActivityKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey);
      await prefs.remove(_biometricEnabledKey);
      await prefs.remove(_lastActivityKey);
    }
  }
}