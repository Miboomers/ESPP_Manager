import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'dart:io' if (dart.library.html) 'dart:html';

/// Zentrale Plattform-Abstraktion für alle plattformspezifischen Funktionen
class PlatformService {
  static const PlatformService _instance = PlatformService._internal();
  factory PlatformService() => _instance;
  const PlatformService._internal();

  /// Plattform-Erkennung
  bool get isWeb => kIsWeb;
  bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  bool get isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
  bool get isMobile => isIOS || isAndroid;
  bool get isDesktop => isMacOS || isWindows || isLinux;

  /// Datei-Operationen
  Future<String?> getTemporaryDirectory() async {
    if (isWeb) {
      throw UnsupportedError('Temporary directory wird auf Web-Plattformen nicht unterstützt');
    }
    final dir = await path_provider.getTemporaryDirectory();
    return dir.path;
  }

  Future<String?> getApplicationDocumentsDirectory() async {
    if (isWeb) {
      throw UnsupportedError('Application documents directory wird auf Web-Plattformen nicht unterstützt');
    }
    final dir = await path_provider.getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String?> getDownloadsDirectory() async {
    if (isWeb) {
      throw UnsupportedError('Downloads directory wird auf Web-Plattformen nicht unterstützt');
    }
    if (isMacOS) {
      final home = Platform.environment['HOME'];
      return '$home/Downloads';
    } else if (isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      return '$userProfile\\Downloads';
    } else if (isLinux) {
      final home = Platform.environment['HOME'];
      return '$home/Downloads';
    }
    return null;
  }

  /// File Picker Abstraktion
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false,
    String? dialogTitle,
  }) async {
    return await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: withData,
      dialogTitle: dialogTitle,
    );
  }

  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    if (isWeb) {
      throw UnsupportedError('Datei speichern wird auf Web-Plattformen nicht unterstützt');
    }
    return await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: type,
      allowedExtensions: allowedExtensions,
    );
  }

  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    if (isWeb) {
      throw UnsupportedError('Verzeichnisauswahl wird auf Web-Plattformen nicht unterstützt');
    }
    return await FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle,
      initialDirectory: initialDirectory,
    );
  }

  /// Datei-Öffnen
  Future<void> openFile(String filePath) async {
    if (isWeb) {
      throw UnsupportedError('Datei öffnen wird auf Web-Plattformen nicht unterstützt');
    }
    await OpenFile.open(filePath);
  }

  /// Share-Funktionalität
  Future<void> shareFiles(List<String> filePaths, {
    String? subject,
    String? text,
  }) async {
    if (isWeb) {
      throw UnsupportedError('Datei-Sharing wird auf Web-Plattformen nicht unterstützt');
    }
    
    if (isMobile) {
      // Mobile: Share über native Share-Funktion
      final xFiles = filePaths.map((path) => XFile(path)).toList();
      await Share.shareXFiles(
        xFiles,
        subject: subject,
        text: text,
      );
    } else {
      // Desktop: Datei öffnen
      for (final path in filePaths) {
        await openFile(path);
      }
    }
  }

  /// Plattformspezifische Pfadtrenner
  String get pathSeparator {
    if (isWeb) return '/'; // Web verwendet immer Forward Slash
    if (isWindows) return '\\';
    return '/';
  }

  /// Umgebungsvariablen
  String? getEnvironmentVariable(String name) {
    if (isWeb) {
      // Web hat keine Umgebungsvariablen
      return null;
    }
    return Platform.environment[name];
  }

  /// Plattformspezifische Konfiguration
  Map<String, dynamic> getPlatformConfig() {
    return {
      'isWeb': isWeb,
      'isMobile': isMobile,
      'isDesktop': isDesktop,
      'platform': _getPlatformString(),
      'pathSeparator': pathSeparator,
      'supportsFileSystem': !isWeb,
      'supportsSecureStorage': !isWeb,
      'supportsBiometrics': isMobile,
    };
  }

  String _getPlatformString() {
    if (isWeb) return 'web';
    if (isIOS) return 'ios';
    if (isAndroid) return 'android';
    if (isMacOS) return 'macos';
    if (isWindows) return 'windows';
    if (isLinux) return 'linux';
    return 'unknown';
  }
}

/// Erweiterte Plattform-spezifische Hilfsfunktionen
extension PlatformServiceExtensions on PlatformService {
  /// Plattformspezifische Export-Strategie
  Future<void> exportData({
    required String fileName,
    required String data,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    if (isWeb) {
      // Web: Download über Blob
      await _downloadOnWeb(fileName, data, mimeType);
    } else if (isMobile) {
      // Mobile: Share über temporäre Datei
      await _shareOnMobile(fileName, data, mimeType, subject, text);
    } else {
      // Desktop: Datei speichern
      await _saveOnDesktop(fileName, data);
    }
  }

  Future<void> _downloadOnWeb(String fileName, String data, String mimeType) async {
    if (!isWeb) return;
    
    try {
      // Web-spezifische Download-Implementierung
      // Da dart:html nicht direkt verfügbar ist, verwenden wir einen Fallback
      throw UnsupportedError('Web-Download wird derzeit nicht unterstützt. Verwenden Sie die native App für Export-Funktionen.');
    } catch (e) {
      throw Exception('Web-Download fehlgeschlagen: $e');
    }
  }

  Future<void> _shareOnMobile(String fileName, String data, String mimeType, String? subject, String? text) async {
    if (!isMobile) return;
    
    final tempDir = await getTemporaryDirectory();
    if (tempDir == null) {
      throw Exception('Temporäres Verzeichnis nicht verfügbar');
    }
    
    final tempPath = '$tempDir/$fileName';
    
    // Temporäre Datei erstellen
    final file = File(tempPath);
    await file.writeAsString(data);
    
    // Über Share teilen
    await shareFiles([tempPath], subject: subject, text: text);
    
    // Temporäre Datei löschen
    await file.delete();
  }

  Future<void> _saveOnDesktop(String fileName, String data) async {
    if (!isDesktop) return;
    
    final outputPath = await saveFile(fileName: fileName);
    if (outputPath != null) {
      final file = File(outputPath);
      await file.writeAsString(data);
      await openFile(outputPath);
    }
  }
}
