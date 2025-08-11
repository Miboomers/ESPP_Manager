import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';

// Conditional import für Secure Storage
import '../services/conditional_imports.dart';

class CloudPasswordService {
  static const String _cloudPasswordKey = 'cloud_encryption_password';
  static const String _cloudPasswordHashKey = 'cloud_encryption_password_hash';
  
  late final SecureStorageInterface _secureStorage;
  
  CloudPasswordService() {
    _initializeSecureStorage();
  }
  
  void _initializeSecureStorage() {
    if (kIsWeb) {
      _secureStorage = WebSecureStorage();
    } else {
      _secureStorage = NativeSecureStorage();
    }
  }
  
  /// Check if cloud password is set
  Future<bool> isCloudPasswordSet() async {
    try {
      final passwordHash = await _secureStorage.read(key: _cloudPasswordHashKey);
      return passwordHash != null && passwordHash.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ Error checking cloud password: $e');
      return false;
    }
  }
  
  /// Set cloud password for data encryption
  Future<void> setCloudPassword(String password) async {
    try {
      if (password.isEmpty) {
        throw Exception('Cloud password cannot be empty');
      }
      
      // Hash the password for secure storage
      final passwordHash = _hashPassword(password);
      
      // Store the hashed password
      await _secureStorage.write(key: _cloudPasswordHashKey, value: passwordHash);
      
      // Store the actual password (encrypted) for encryption operations
      final encryptedPassword = _encryptPassword(password);
      await _secureStorage.write(key: _cloudPasswordKey, value: encryptedPassword);
      
      debugPrint('✅ Cloud password set successfully');
    } catch (e) {
      debugPrint('❌ Error setting cloud password: $e');
      rethrow;
    }
  }
  
  /// Get cloud password for encryption (decrypted)
  Future<String?> getCloudPassword() async {
    try {
      final encryptedPassword = await _secureStorage.read(key: _cloudPasswordKey);
      if (encryptedPassword == null) return null;
      
      // Decrypt the password
      return _decryptPassword(encryptedPassword);
    } catch (e) {
      debugPrint('❌ Error getting cloud password: $e');
      return null;
    }
  }
  
  /// Verify cloud password
  Future<bool> verifyCloudPassword(String password) async {
    try {
      final storedHash = await _secureStorage.read(key: _cloudPasswordHashKey);
      if (storedHash == null) return false;
      
      final inputHash = _hashPassword(password);
      return storedHash == inputHash;
    } catch (e) {
      debugPrint('❌ Error verifying cloud password: $e');
      return false;
    }
  }
  
  /// Change cloud password
  Future<void> changeCloudPassword(String oldPassword, String newPassword) async {
    try {
      // Verify old password first
      final isValid = await verifyCloudPassword(oldPassword);
      if (!isValid) {
        throw Exception('Old cloud password is incorrect');
      }
      
      // Set new password
      await setCloudPassword(newPassword);
      
      debugPrint('✅ Cloud password changed successfully');
    } catch (e) {
      debugPrint('❌ Error changing cloud password: $e');
      rethrow;
    }
  }
  
  /// Clear cloud password
  Future<void> clearCloudPassword() async {
    try {
      await _secureStorage.delete(key: _cloudPasswordKey);
      await _secureStorage.delete(key: _cloudPasswordHashKey);
      debugPrint('✅ Cloud password cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cloud password: $e');
    }
  }
  
  /// Generate encryption key from password and user UID
  String generateEncryptionKey(String password, String userUid) {
    final bytes = utf8.encode('$password:$userUid');
    final hash = sha256.convert(bytes);
    return base64.encode(hash.bytes);
  }
  
  /// Hash password for secure storage
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Simple encryption for password storage (not for data)
  String _encryptPassword(String password) {
    // Simple base64 encoding for now - in production, use proper encryption
    final bytes = utf8.encode(password);
    return base64.encode(bytes);
  }
  
  /// Simple decryption for password retrieval
  String _decryptPassword(String encryptedPassword) {
    // Simple base64 decoding for now - in production, use proper decryption
    final bytes = base64.decode(encryptedPassword);
    return utf8.decode(bytes);
  }
}

// Provider für Cloud Password Service
final cloudPasswordServiceProvider = Provider<CloudPasswordService>((ref) {
  return CloudPasswordService();
});
