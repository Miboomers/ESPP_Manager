# 🚀 GitHub Repository Setup für ESPP Manager

## 📋 Schnellstart

### 1. Repository erstellen (falls noch nicht vorhanden)
```bash
# Lokales Git initialisieren
git init

# Alle Dateien hinzufügen
git add .

# Initial Commit
git commit -m "Initial commit: ESPP Manager v1.0.0"

# GitHub Repository verknüpfen
git remote add origin https://github.com/Miboomers/ESPP_Manager.git

# Push zum Repository
git branch -M main
git push -u origin main
```

### 2. GitHub Actions aktivieren
1. Gehe zu **Settings** → **Actions** → **General**
2. Wähle **Allow all actions and reusable workflows**
3. Unter **Workflow permissions**: **Read and write permissions**
4. Save

### 3. GitHub Pages aktivieren (für Web-Version)
1. Gehe zu **Settings** → **Pages**
2. **Source**: Deploy from a branch
3. **Branch**: `gh-pages` / `root`
4. Save
5. Nach ~5 Minuten verfügbar unter: `https://miboomers.github.io/ESPP_Manager`

## 🔄 Automatische Builds

### Windows & Web Builds bei jedem Push
```bash
# Änderungen pushen
git add .
git commit -m "Feature: Neue Funktion"
git push

# Build-Status prüfen
# GitHub → Actions Tab → Workflow läuft automatisch
```

### Release erstellen
```bash
# Version in pubspec.yaml erhöhen
# version: 1.0.1+5

# Tag erstellen und pushen
git tag v1.0.1
git push origin v1.0.1

# Automatisch:
# - Windows Build
# - Web Build  
# - GitHub Release mit Downloads
```

## 📦 Build-Artefakte

### Download von GitHub Actions
1. Repository → **Actions** Tab
2. Gewünschten Workflow-Run auswählen
3. **Artifacts** Section → Download
   - `windows-build`: Windows Executable
   - `web-build`: Web-Deployment-Dateien

### Automatische Web-Deployment
- **Live Version**: https://miboomers.github.io/ESPP_Manager
- **Updates**: Automatisch bei Push zu `main`
- **PWA**: Installierbar als Desktop-App

## 🛠️ Lokale Builds (Alternative)

### Windows Build (lokal)
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

### Web Build (lokal)
```bash
flutter build web --release
# Output: build/web/

# Lokal testen
cd build/web
python3 -m http.server 8000
# Öffnen: http://localhost:8000
```

## 🔐 Secrets Setup (optional)

### Für erweiterte Features
1. **Settings** → **Secrets and variables** → **Actions**
2. Mögliche Secrets:
   - `FIREBASE_TOKEN`: Für automatisches Firebase Deployment
   - `WINDOWS_CERTIFICATE`: Für Code Signing (optional)

## 📊 Build Status Badge

Füge zu README.md hinzu:
```markdown
[![Build Status](https://github.com/Miboomers/ESPP_Manager/actions/workflows/build-deploy.yml/badge.svg)](https://github.com/Miboomers/ESPP_Manager/actions)
```

## 🎯 Deployment-Übersicht

| Platform | Build-Methode | Distribution | Auto-Deploy |
|----------|--------------|--------------|-------------|
| **Windows** | GitHub Actions | GitHub Releases | ✅ Bei Tags |
| **Web** | GitHub Actions | GitHub Pages | ✅ Bei Push |
| **macOS** | Lokal (Xcode) | TestFlight/Direct | ❌ Manuell |
| **iOS** | Lokal (Xcode) | TestFlight | ❌ Manuell |

## 📈 Monitoring

### Build-Historie
- **Actions Tab**: Alle Build-Läufe
- **Insights → Actions**: Build-Statistiken
- **Email-Benachrichtigungen**: Bei Build-Fehlern

### Web-Analytics (optional)
```html
<!-- In web/index.html hinzufügen -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
```

## 🐛 Troubleshooting

### Build fehlgeschlagen
1. **Actions Tab** → Fehlgeschlagener Run
2. Logs prüfen für Details
3. Häufige Probleme:
   - `flutter pub get` failed → Dependencies prüfen
   - Windows Build Error → Flutter version prüfen
   - Web Build Error → JavaScript Fehler checken

### GitHub Pages nicht erreichbar
- Warten Sie 5-10 Minuten nach Aktivierung
- Prüfen: Settings → Pages → Deployment Status
- Cache leeren: `Ctrl+F5` im Browser

### Artifacts zu groß
- Windows Build ~50MB ist normal
- Web Build ~10MB ist normal
- Retention auf 7-30 Tage setzen

---

## 📞 Support

**Issues**: https://github.com/Miboomers/ESPP_Manager/issues
**Discussions**: https://github.com/Miboomers/ESPP_Manager/discussions