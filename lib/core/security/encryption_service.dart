import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' hide Key;
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  static const String _keyAlias = 'espp_encryption_key';
  static const String _ivAlias = 'espp_encryption_iv';
  
  final FlutterSecureStorage? _secureStorage;
  late final Key _key;
  late final IV _iv;
  late final Encrypter _encrypter;
  
  EncryptionService({FlutterSecureStorage? secureStorage})
      : _secureStorage = kIsWeb || defaultTargetPlatform == TargetPlatform.macOS 
          ? null 
          : secureStorage ?? const FlutterSecureStorage();
  
  Future<void> initialize() async {
    if (_secureStorage != null) {
      await _initializeWithSecureStorage();
    } else {
      await _initializeWithSharedPreferences();
    }
    
    _encrypter = Encrypter(AES(_key));
  }
  
  Future<void> _initializeWithSecureStorage() async {
    String? storedKey = await _secureStorage!.read(key: _keyAlias);
    String? storedIV = await _secureStorage!.read(key: _ivAlias);
    
    if (storedKey == null || storedIV == null) {
      _key = Key.fromSecureRandom(32);
      _iv = IV.fromSecureRandom(16);
      
      await _secureStorage!.write(key: _keyAlias, value: _key.base64);
      await _secureStorage!.write(key: _ivAlias, value: _iv.base64);
    } else {
      _key = Key.fromBase64(storedKey);
      _iv = IV.fromBase64(storedIV);
    }
  }
  
  Future<void> _initializeWithSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedKey = prefs.getString(_keyAlias);
    String? storedIV = prefs.getString(_ivAlias);
    
    if (storedKey == null || storedIV == null) {
      _key = Key.fromSecureRandom(32);
      _iv = IV.fromSecureRandom(16);
      
      await prefs.setString(_keyAlias, _key.base64);
      await prefs.setString(_ivAlias, _iv.base64);
    } else {
      _key = Key.fromBase64(storedKey);
      _iv = IV.fromBase64(storedIV);
    }
  }
  
  String encrypt(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }
  
  String decrypt(String encryptedText) {
    final encrypted = Encrypted.fromBase64(encryptedText);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }
  
  Map<String, dynamic> encryptMap(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    return {'encrypted': encrypt(jsonString)};
  }
  
  Map<String, dynamic> decryptMap(Map<String, dynamic> encryptedData) {
    final encryptedString = encryptedData['encrypted'] as String;
    final jsonString = decrypt(encryptedString);
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }
  
  Future<void> clearKeys() async {
    if (_secureStorage != null) {
      await _secureStorage!.delete(key: _keyAlias);
      await _secureStorage!.delete(key: _ivAlias);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAlias);
      await prefs.remove(_ivAlias);
    }
  }
}