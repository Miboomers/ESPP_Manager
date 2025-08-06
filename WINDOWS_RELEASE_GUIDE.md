# 🪟 ESPP Manager - Windows Release Guide

## 📋 Übersicht
Komplette Anleitung für die Windows-Veröffentlichung der ESPP Manager App mit Firebase Cloud Sync.

## ⚡ Quick Start - Windows Build

### 🔧 Lokaler Windows Build
```bash
# 1. Dependencies installieren
flutter pub get

# 2. Windows Build erstellen
flutter build windows --release

# 3. Executable finden
# Pfad: build/windows/runner/Release/espp_manager.exe
```

### 📦 Distribution Package erstellen
```bash
# Komplettes Package mit allen Dependencies
cd build/windows/runner/Release
7z a "ESPP_Manager_Windows_v1.0.0.zip" ./*

# Oder manuell:
# 1. Kompletten Release-Ordner kopieren
# 2. Als ZIP verpacken
# 3. Hochladen/verteilen
```

## 🚀 GitHub Actions - Automatische Builds

### 📂 Setup Dateien
**`.github/workflows/windows-build.yml`:**
```yaml
name: Windows Build

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build-windows:
    runs-on: windows-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.32.0'
        channel: 'stable'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build Windows
      run: flutter build windows --release
    
    - name: Create distribution package
      run: |
        cd build/windows/runner/Release
        7z a "ESPP_Manager_Windows.zip" ./*
    
    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: windows-build
        path: build/windows/runner/Release/ESPP_Manager_Windows.zip
```

### 📥 Build Download
1. **GitHub Repository** → Actions Tab
2. **Neuesten Workflow** auswählen
3. **Artifacts** → `windows-build` herunterladen
4. **ZIP entpacken** → `espp_manager.exe` ausführen

## 🔐 Firebase Konfiguration

### 📱 Firebase Console Setup
1. **Firebase Console** öffnen: https://console.firebase.google.com
2. **Projekt auswählen**: `espp-manager`
3. **Settings** → Projekteinstellungen
4. **Allgemein** → Apps → **Windows-App hinzufügen**

### 🔑 Windows Firebase Config
**`windows/firebase_options.dart`** wird automatisch generiert:
```dart
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return windows;
      // ...
    }
  }
  
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY_HERE',
    appId: '1:521663857148:web:your-windows-app-id',
    projectId: 'espp-manager',
    // weitere Konfiguration...
  );
}
```

### 🔄 Cloud Sync Features
**Unterstützte Features auf Windows:**
- ✅ **Firebase Authentication** (Email/Passwort)
- ✅ **Cloud Firestore** (Daten-Synchronisation)
- ✅ **Automatische Anmeldung**
- ✅ **Offline-First** (lokale Hive-Datenbank)
- ✅ **Cross-Platform Sync** (macOS ↔ Windows ↔ iOS)

## ⚠️ Windows-spezifische Überlegungen

### 🛡️ Sicherheitswarnungen
**Problem:** Windows zeigt Sicherheitswarnung bei unsigned executables
```
Windows protected your PC
Microsoft Defender SmartScreen prevented an unrecognized app from starting.
```

**Lösung für Nutzer:**
1. **"More info"** klicken
2. **"Run anyway"** wählen
3. **Alternative**: Als vertrauenswürdiger Publisher kennzeichnen

**Professionelle Lösung (optional):**
- **Code Signing Certificate** erwerben ($100-400/Jahr)
- **Windows Store** Distribution (App Store Review erforderlich)

### 📁 Installation & Daten
**Installations-Pfad:**
- Beliebiger Ordner (portable App)
- Empfohlung: `C:\Users\[Username]\AppData\Local\ESPP_Manager`

**Daten-Speicherort:**
- **Hive Database**: `%APPDATA%\espp_manager\boxes`
- **Secure Storage**: Windows Credential Manager
- **Settings**: Registry oder lokale Dateien

### 🔧 Dependencies Windows
**Automatisch eingebunden:**
- **Visual C++ Redistributable**
- **Hive Database** (lokale SQLite-Alternative)
- **Firebase SDK** (Cloud Sync)
- **AES-Verschlüsselung**
- **Secure Storage** (Windows Credential Manager)

## 📊 Build-Konfiguration

### 🎯 pubspec.yaml - Windows spezifische Deps
```yaml
dependencies:
  # Cross-platform packages funktionieren automatisch
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  firebase_core: ^2.27.0
  firebase_auth: ^4.17.8
  cloud_firestore: ^4.15.8
  flutter_secure_storage: ^9.0.0
  
dev_dependencies:
  hive_generator: ^1.1.3
  build_runner: ^2.4.7

flutter:
  uses-material-design: true
  
# Windows-spezifische Konfiguration (automatisch)
msix_config:
  display_name: ESPP Manager
  publisher_display_name: Miboomers
  identity_name: com.miboomers.esppmanager
  logo_path: assets/images/app_icon.png
```

### 🏗️ Build Varianten
**Debug Build:**
```bash
flutter build windows --debug
# → build/windows/runner/Debug/espp_manager.exe
# Größer, mit Debug-Symbolen
```

**Release Build:**
```bash
flutter build windows --release
# → build/windows/runner/Release/espp_manager.exe  
# Optimiert, kleiner, production-ready
```

**Profile Build:**
```bash
flutter build windows --profile
# → build/windows/runner/Profile/espp_manager.exe
# Performance-Profiling aktiviert
```

## 🚚 Distribution Strategien

### 📦 Option 1: ZIP Distribution
**Vorteile:**
- ✅ Einfach und schnell
- ✅ Keine Installation erforderlich
- ✅ Portable zwischen PCs
- ✅ Direkt von GitHub Actions

**Process:**
1. GitHub Actions Build herunterladen
2. ZIP an Nutzer verteilen
3. Nutzer entpackt ZIP
4. `espp_manager.exe` direkt ausführen

### 🏪 Option 2: Windows Store (MSIX)
**Vorteile:**
- ✅ Automatische Updates
- ✅ Vertrauenswürdige Quelle
- ✅ Einfache Installation
- ❌ Store Review erforderlich
- ❌ Jährliche Entwicklergebühr ($19)

**Setup:**
```bash
flutter pub global activate msix
flutter pub get
flutter build windows
flutter pub global run msix:create
```

### 🌐 Option 3: Website Download
**Setup:**
1. **GitHub Releases** nutzen
2. **Automatische Releases** bei Tags
3. **Download-Link** bereitstellen
4. **Versioning** automatisch

## 📋 Pre-Release Checklist

### ✅ Funktionalität testen
- [ ] **App startet** ohne Fehler
- [ ] **PIN-Authentifizierung** funktioniert
- [ ] **ESPP-Berechnungen** sind korrekt
- [ ] **PDF-Export** funktioniert
- [ ] **CSV-Import** funktioniert (Fidelity)
- [ ] **Cloud Sync** An-/Abmelden
- [ ] **Daten-Persistierung** zwischen App-Starts
- [ ] **Settings** werden gespeichert

### 🔐 Cloud Sync testen
- [ ] **Firebase Anmeldung** Email/Passwort
- [ ] **Daten hochladen** zu Firestore
- [ ] **Daten synchronisieren** zwischen Geräten
- [ ] **Offline-Betrieb** ohne Internet
- [ ] **Wieder-Anmeldung** nach Neustart

### 📊 Performance testen  
- [ ] **Startup-Zeit** unter 3 Sekunden
- [ ] **CSV-Import** große Dateien (>100 Transaktionen)
- [ ] **PDF-Generation** viele Transaktionen
- [ ] **Memory Usage** stabil
- [ ] **UI-Responsiveness** auch bei Berechnungen

## 🐛 Troubleshooting

### ❌ Häufige Build-Fehler
**"Flutter SDK not found":**
```bash
# Flutter PATH prüfen
flutter doctor -v

# Windows PATH erweitern
set PATH=%PATH%;C:\flutter\bin
```

**"Missing Visual Studio components":**
```bash
# Visual Studio Installer öffnen
# "Desktop development with C++" installieren
flutter doctor
```

**"Firebase configuration missing":**
```bash
# Firebase CLI installieren
npm install -g firebase-tools

# Konfiguration generieren
flutterfire configure
```

### 🔧 Runtime-Fehler
**"DLL not found":**
- Visual C++ Redistributable installieren
- Alle .dll-Dateien aus Release-Ordner kopieren

**"Firebase Auth failed":**
- Internet-Verbindung prüfen
- Firebase-Projekt Status überprüfen
- Credential Manager leeren (Windows)

**"Hive Database error":**
- `%APPDATA%\espp_manager` Ordner löschen
- App neu starten (erstellt neue DB)

## 📈 Post-Release

### 📊 Analytics & Monitoring
- **Firebase Analytics** (optional)
- **Crashlytics** für Error Reporting
- **User Feedback** über GitHub Issues
- **Usage Metrics** in Firebase Console

### 🔄 Update-Strategie
1. **GitHub Releases** für neue Versionen
2. **In-App Update-Hinweis** (optional)
3. **Backward Compatibility** für Datenbank
4. **Migration Scripts** bei Breaking Changes

### 👥 Support & Documentation
- **README** mit Installation Instructions
- **FAQ** für häufige Fragen
- **Issue Templates** in GitHub
- **Screenshots** für Windows-spezifische UI

---
**Status**: ✅ **Windows Build Ready** - Alle Konfigurationen abgeschlossen
**Nächste Schritte**: iOS TestFlight Preparation + App Store Review