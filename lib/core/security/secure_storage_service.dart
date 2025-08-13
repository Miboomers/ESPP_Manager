import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'encryption_service.dart';

class SecureStorageService {
  static const String _boxName = 'espp_secure_box';
  
  final EncryptionService _encryptionService;
  late Box<String> _box;
  
  SecureStorageService(this._encryptionService);
  
  Future<void> initialize() async {
    try {
      // Hive is already initialized in main.dart
      if (!_box.isOpen) {
        _box = await Hive.openBox<String>(_boxName);
      }
    } catch (e) {
      // Bei Fehlern neu öffnen
      try {
        await _box.close();
      } catch (_) {}
      _box = await Hive.openBox<String>(_boxName);
    }
  }
  
  Future<void> _ensureBoxOpen() async {
    if (!_box.isOpen) {
      await initialize();
    }
  }
  
  Future<void> saveData(String key, Map<String, dynamic> data) async {
    await _ensureBoxOpen();
    final encryptedData = _encryptionService.encryptMap(data);
    final jsonString = jsonEncode(encryptedData);
    await _box.put(key, jsonString);
  }
  
  Future<Map<String, dynamic>?> getData(String key) async {
    await _ensureBoxOpen();
    final jsonString = _box.get(key);
    if (jsonString == null) return null;
    
    try {
      final encryptedData = jsonDecode(jsonString) as Map<String, dynamic>;
      return _encryptionService.decryptMap(encryptedData);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> deleteData(String key) async {
    await _ensureBoxOpen();
    await _box.delete(key);
  }
  
  Future<void> clearAll() async {
    await _box.clear();
  }
  
  Future<List<String>> getAllKeys() async {
    return _box.keys.cast<String>().toList();
  }
  
  Future<void> close() async {
    await _box.close();
  }
}