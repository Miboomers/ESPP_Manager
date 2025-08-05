import '../models/settings_model.dart';
import '../../core/security/secure_storage_service.dart';
import '../../core/security/encryption_service.dart';

class SettingsRepository {
  static const String _settingsKey = 'app_settings';
  
  SecureStorageService? _storageService;
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      final encryptionService = EncryptionService();
      await encryptionService.initialize();
      _storageService = SecureStorageService(encryptionService);
      await _storageService!.initialize();
      _isInitialized = true;
    }
  }

  Future<SettingsModel> getSettings() async {
    await _ensureInitialized();
    
    final data = await _storageService!.getData(_settingsKey);
    if (data != null) {
      return SettingsModel.fromJson(data);
    }
    
    // Return default settings if none exist
    const defaultSettings = SettingsModel();
    await saveSettings(defaultSettings);
    return defaultSettings;
  }

  Future<void> saveSettings(SettingsModel settings) async {
    await _ensureInitialized();
    await _storageService!.saveData(_settingsKey, settings.toJson());
  }

  Future<void> clearSettings() async {
    await _ensureInitialized();
    await _storageService!.deleteData(_settingsKey);
  }
}