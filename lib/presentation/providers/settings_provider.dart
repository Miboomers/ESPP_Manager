import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/settings_model.dart';
import '../../data/repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsModel>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends AsyncNotifier<SettingsModel> {
  SettingsRepository? _repository;

  SettingsRepository get repository {
    _repository ??= ref.read(settingsRepositoryProvider);
    return _repository!;
  }

  @override
  Future<SettingsModel> build() async {
    return await repository.getSettings();
  }

  Future<void> updateSettings(SettingsModel settings) async {
    state = const AsyncValue.loading();
    try {
      await repository.saveSettings(settings);
      state = AsyncValue.data(settings);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> resetToDefaults() async {
    const defaultSettings = SettingsModel();
    await updateSettings(defaultSettings);
  }
}