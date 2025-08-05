# Windows Build Documentation

## GitHub Actions Setup

### Workflow-Datei: `.github/workflows/build.yml`

```yaml
name: Build ESPP Manager

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build-windows:
    runs-on: windows-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        channel: 'stable'
    
    - name: Get Dependencies
      run: flutter pub get
    
    - name: Build Windows App
      run: flutter build windows --release
    
    - name: Create Windows ZIP
      run: |
        cd build/windows/x64/runner/Release
        Compress-Archive -Path * -DestinationPath ../../../../../ESPP-Manager-Windows.zip
        cd ../../../../../
    
    - name: Upload Windows Build
      uses: actions/upload-artifact@v4
      with:
        name: windows-release
        path: ESPP-Manager-Windows.zip
        retention-days: 30
```

## Wichtige Anpassungen

### 1. Dart SDK Version (`pubspec.yaml`)
```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'  # Kompatibel mit GitHub Actions Flutter
```

### 2. Windows-spezifische Plugins
Automatisch erkannt in `windows/flutter/generated_plugins.cmake`:
- flutter_secure_storage_windows
- local_auth_windows
- printing
- share_plus
- url_launcher_windows

## Build-Prozess

### Lokal (auf Windows-PC):
```bash
flutter pub get
flutter build windows --release
```

### Via GitHub Actions:
1. Code zu GitHub pushen
2. Workflow startet automatisch
3. Build-Artifact herunterladen von Actions Tab

## Installation ohne Code Signing

### Für Endnutzer:
1. ZIP-Datei herunterladen und entpacken
2. `espp_manager.exe` ausführen
3. Bei Windows Defender SmartScreen:
   - "More info" klicken
   - "Run anyway" wählen

### Dokumentation für Nutzer:
```markdown
## Windows Installation

Da die App nicht mit einem teuren Code Signing Certificate signiert ist, 
zeigt Windows beim ersten Start eine Sicherheitswarnung.

**So installieren Sie die App:**
1. Download der ZIP-Datei von GitHub Releases
2. ZIP entpacken in einen Ordner Ihrer Wahl
3. `espp_manager.exe` doppelklicken
4. Bei der Windows-Warnung:
   - Klicken Sie auf "More info"
   - Dann auf "Run anyway"

Die App ist sicher - der Quellcode ist vollständig auf GitHub einsehbar.
```

## Mögliche Verbesserungen

### 1. Self-Hosted Runner
Für mehr Kontrolle über den Build-Prozess kann ein eigener Windows-PC als GitHub Actions Runner konfiguriert werden.

### 2. Installer erstellen
Mit Tools wie Inno Setup oder NSIS kann ein professioneller Installer erstellt werden:
- Startmenü-Einträge
- Desktop-Verknüpfung
- Deinstallations-Routine

### 3. Code Signing (kostenpflichtig)
Optionen für Code Signing Certificates:
- Sectigo: ~200€/Jahr
- DigiCert: ~300€/Jahr
- Certum: ~120€/Jahr (Open Source)

## Troubleshooting

### Build-Fehler auf GitHub Actions
1. Logs prüfen unter Actions Tab
2. Häufige Probleme:
   - Dart SDK Version Mismatch
   - Missing Windows SDK
   - Plugin-Kompatibilität

### Lokale Build-Probleme
1. `flutter doctor -v` ausführen
2. Visual Studio mit C++ Tools installiert?
3. Windows SDK vorhanden?

## Dateien und Pfade

### Build-Output:
- Debug: `build/windows/x64/runner/Debug/`
- Release: `build/windows/x64/runner/Release/`

### Wichtige Dateien:
- `windows/runner/main.cpp`: Entry Point
- `windows/runner/Runner.rc`: App-Metadaten
- `windows/runner/resources/app_icon.ico`: App-Icon

### Icon ändern:
1. Neues Icon als `app_icon.ico` erstellen (256x256px empfohlen)
2. Ersetzen in `windows/runner/resources/`
3. Neu builden