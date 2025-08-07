# GitHub Actions Setup & Deployment

## 🎯 Ziel
Automatische Builds und Deployment für Windows und Web bei jedem Push zu GitHub.

## 🔧 Implementierte Workflows

### 1. Windows Build (`build-windows`)
- **Trigger**: Bei jedem Push zu `main` Branch
- **Output**: Windows ZIP mit `.exe` und allen Dependencies
- **Download**: Über GitHub Actions Artifacts

### 2. Web Build (`build-web`)
- **Trigger**: Bei jedem Push zu `main` Branch
- **Output**: Optimierte Web App
- **Auto-Deploy**: Zu GitHub Pages (wenn aktiviert)

## 📋 Workflow Struktur

```yaml
name: Windows & Web Build

on:
  push:
    branches: [ main ]
  workflow_dispatch:  # Manueller Start möglich

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      1. Checkout Code
      2. Setup Firebase Config (Stub für CI/CD)
      3. Setup Flutter
      4. Enable Windows Desktop
      5. Install Dependencies
      6. Build Windows Release
      7. Package als ZIP
      8. Upload Artifact

  build-web:
    runs-on: ubuntu-latest
    steps:
      1. Checkout Code
      2. Setup Firebase Config (Stub für CI/CD)
      3. Setup Flutter
      4. Enable Web
      5. Install Dependencies
      6. Build Web Release
      7. Deploy to GitHub Pages
```

## 🚨 Wichtige Fixes Applied

### Problem 1: Firebase Config nicht gefunden
**Fehler**: `lib/config/firebase_config.dart: error: Target of URI doesn't exist`

**Ursache**: 
- firebase_config.dart ist in .gitignore (enthält echte API Keys)
- CI/CD Build hat keinen Zugriff auf diese Datei

**Lösung**:
1. Stub Config erstellt (`firebase_config_stub.dart`) mit Demo Keys
2. Workflow kopiert Stub → firebase_config.dart vor Build
3. **WICHTIG**: Muss VOR `flutter pub get` passieren!

### Problem 2: Workflow Timing
**Fehler**: Flutter Analysis schlägt fehl bevor Config kopiert wird

**Lösung**: Firebase Setup als ERSTEN Schritt nach Checkout
```yaml
- name: Checkout code
- name: Setup Firebase config for CI/CD  # MUSS ZUERST!
- name: Setup Flutter                    # DANN Flutter
```

### Problem 3: Deprecated Flutter Web Flags
**Fehler**: `Could not find an option named "--web-renderer"`

**Lösung**: Flag entfernt, Flutter wählt automatisch besten Renderer

## 🌐 GitHub Pages Deployment

### Automatische Aktivierung:
1. Workflow erstellt `gh-pages` Branch beim ersten erfolgreichen Build
2. Gehen Sie zu: Settings → Pages
3. Source: `gh-pages` Branch auswählen
4. Save

### Web App URL:
```
https://miboomers.github.io/ESPP_Manager
```

## 📦 Build Artifacts

### Windows:
- **Name**: `ESPP_Manager_Windows_[DATUM].zip`
- **Inhalt**: 
  - `espp_manager.exe`
  - Alle DLLs und Dependencies
  - README.txt
- **Download**: Actions → Workflow Run → Artifacts

### Web:
- **Live**: GitHub Pages URL
- **Download**: Als ZIP verfügbar in Artifacts

## 🔑 Secrets & Configuration

### Benötigte Secrets: KEINE!
- Workflow nutzt `GITHUB_TOKEN` (automatisch bereitgestellt)
- Firebase Keys über Stub Config (keine echten Keys in CI/CD)

### Firebase Config Management:
```
Lokal (Entwicklung):
lib/config/firebase_config.dart → Echte API Keys

CI/CD (GitHub Actions):
lib/config/firebase_config_stub.dart → Demo Keys (kopiert zu firebase_config.dart)
```

## 🚀 Verwendung

### Automatischer Build:
```bash
git add .
git commit -m "Neue Features"
git push
# → Builds starten automatisch
```

### Manueller Build:
1. Gehen zu: Actions Tab
2. Wählen: "Windows & Web Build"
3. Klicken: "Run workflow"
4. Branch: `main` auswählen
5. Run workflow

### Build Status prüfen:
```bash
# Browser öffnen
open https://github.com/Miboomers/ESPP_Manager/actions

# Oder Badge in README:
![Build Status](https://github.com/Miboomers/ESPP_Manager/actions/workflows/build-deploy.yml/badge.svg)
```

## 📊 Performance

- **Windows Build**: ~5-7 Minuten
- **Web Build**: ~3-5 Minuten
- **Parallel**: Beide Builds laufen gleichzeitig
- **Cache**: Flutter SDK wird gecached für schnellere Builds

## 🐛 Troubleshooting

### Build Failed?
1. Check Actions Tab für Error Details
2. Häufige Probleme:
   - Firebase Config nicht kopiert → Check Workflow Order
   - Flutter Version mismatch → Update workflow Flutter version
   - Windows spezifische Fehler → Check PowerShell Syntax

### Artifacts nicht verfügbar?
- Retention: 30 Tage (dann automatisch gelöscht)
- Max Size: 2GB pro Artifact

### GitHub Pages nicht erreichbar?
1. Settings → Pages → Source muss `gh-pages` sein
2. Erste Deployment kann 10 Minuten dauern
3. Check: https://github.com/Miboomers/ESPP_Manager/deployments

## ✅ Vorteile

1. **Automatisierung**: Keine manuellen Builds mehr nötig
2. **Konsistenz**: Jeder Build identisch konfiguriert
3. **Verfügbarkeit**: Team kann Builds direkt downloaden
4. **Web Deployment**: Automatisch live bei jedem Push
5. **Keine lokalen Dependencies**: Builds laufen in Cloud

## 🔮 Zukünftige Verbesserungen

- [ ] macOS Build hinzufügen (benötigt macOS Runner)
- [ ] iOS Build über Xcode Cloud
- [ ] Automatische Version Bumps
- [ ] Release Notes Generation
- [ ] Code Signing für Windows (Certificate benötigt)

---
*Setup dokumentiert am 07.08.2025*