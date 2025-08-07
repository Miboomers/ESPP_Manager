# ESPP Manager - Deployment Guide

## 🚀 Quick Start für Deployment

### Repository Public machen:
1. GitHub → Settings → General
2. Change repository visibility → Public
3. Confirm

### GitHub Pages aktivieren:
1. Warten bis erster Web Build erfolgreich
2. Settings → Pages
3. Source: Deploy from branch
4. Branch: `gh-pages` / `root`
5. Save

## 📱 Platform Deployment Status

| Platform | Build Status | Deployment | Download |
|----------|-------------|------------|----------|
| **Web** 🌐 | GitHub Actions | GitHub Pages | https://miboomers.github.io/ESPP_Manager |
| **Windows** 💻 | GitHub Actions | ZIP Artifact | Actions → Latest Run → Artifacts |
| **macOS** 🖥️ | Xcode lokal | Direkt/Notarized | Manual Build via Xcode |
| **iOS** 📱 | Xcode lokal | TestFlight Ready | Requires Apple Developer Account |

## 🔧 Build Prozesse

### Web (Automatisch)
```bash
git push → GitHub Actions → Build → Deploy to GitHub Pages
```
- **URL**: https://miboomers.github.io/ESPP_Manager
- **Updates**: Automatisch bei jedem Push

### Windows (Automatisch)
```bash
git push → GitHub Actions → Build → ZIP in Artifacts
```
- **Download**: GitHub Actions → Artifacts
- **Installation**: ZIP entpacken → espp_manager.exe

### macOS (Manuell)
```bash
1. Xcode öffnen
2. Product → Archive
3. Distribute App → Developer ID
4. Notarization automatisch
```
- **Signiert**: ✅ Mit Developer ID
- **Notarisiert**: ✅ Von Apple geprüft

### iOS (Manuell)
```bash
1. GoogleService-Info.plist hinzufügen
2. Xcode → Generic iOS Device
3. Product → Archive
4. Distribute → App Store Connect
```
- **TestFlight**: Beta Testing
- **App Store**: Nach Review

## 🔑 Sicherheit & Keys

### Firebase Configuration:
```
├── lib/config/
│   ├── firebase_config.dart         # LOKAL - Echte Keys (gitignored)
│   ├── firebase_config_stub.dart    # CI/CD - Demo Keys (committed)
│   └── firebase_config_template.dart # Template für neue Entwickler
```

### API Keys Status:
- ✅ Externalisiert (nicht im Code)
- ✅ Rotiert (alte Keys gelöscht)
- ✅ Platform-spezifisch (Web vs Desktop)
- ✅ CI/CD kompatibel (Stub Config)

## 📊 Feature Verfügbarkeit

| Feature | Web | Windows | macOS | iOS |
|---------|-----|---------|-------|-----|
| Local Storage | ✅ IndexedDB | ✅ Hive | ✅ Hive | ✅ Hive |
| Cloud Sync | ✅ | ✅ | ✅ | ✅ |
| PDF Export | ✅ | ✅ | ✅ | ✅ |
| CSV Import | ✅ | ✅ | ✅ | ✅ |
| Biometric Auth | ❌ | ❌ | ✅ TouchID | ✅ FaceID |
| Auto-Update | ✅ Instant | ❌ Manual | ⚠️ Sparkle | ✅ App Store |

## 🌍 URLs & Endpoints

### Production:
- **Web App**: https://miboomers.github.io/ESPP_Manager
- **GitHub Repo**: https://github.com/Miboomers/ESPP_Manager
- **Actions**: https://github.com/Miboomers/ESPP_Manager/actions
- **Releases**: https://github.com/Miboomers/ESPP_Manager/releases

### Firebase:
- **Project**: espp-manager
- **Console**: https://console.firebase.google.com/project/espp-manager
- **Hosting**: espp-manager.firebaseapp.com (optional)

## 📈 Deployment Metrics

### GitHub Actions:
- **Build Zeit**: ~5-7 Min (Windows), ~3-5 Min (Web)
- **Artifact Retention**: 30 Tage
- **Parallel Builds**: ✅ Enabled
- **Cache**: Flutter SDK gecached

### GitHub Pages:
- **Deploy Zeit**: ~2-3 Min nach Build
- **CDN**: GitHub's global CDN
- **SSL**: ✅ Automatisch
- **Custom Domain**: Möglich

## 🔄 Update Prozess

### Für Entwickler:
1. Code ändern
2. Lokal testen
3. `git commit` & `git push`
4. GitHub Actions builds automatisch
5. Web sofort live, Windows in Artifacts

### Für Nutzer:
- **Web**: Refresh → Neue Version
- **Windows**: Download neueste ZIP
- **macOS**: Download neue DMG/PKG
- **iOS**: TestFlight/App Store Update

## ⚡ Performance Optimierungen

### Web Build:
- Tree-shaking enabled
- Font subsetting (98% reduction)
- Minified JavaScript
- Compressed assets

### Native Builds:
- Release mode optimizations
- AOT compilation
- Strip debug symbols

## 🐛 Troubleshooting

### GitHub Actions Failed:
```bash
# Check logs
https://github.com/Miboomers/ESPP_Manager/actions

# Common fixes:
- Firebase config copy failed → Check workflow order
- Flutter version mismatch → Update workflow version
```

### GitHub Pages nicht erreichbar:
```bash
# Check deployment
https://github.com/Miboomers/ESPP_Manager/deployments

# Settings → Pages → Source must be gh-pages
# First deployment can take 10 minutes
```

### Windows Security Warning:
```
Windows Defender SmartScreen

Fix: "More info" → "Run anyway"
Future: Code signing certificate needed
```

## 📝 Release Checklist

### Vor Release:
- [ ] Version Bump in pubspec.yaml
- [ ] Update CHANGELOG.md
- [ ] Test alle Platforms lokal
- [ ] Verify keine API Keys im Code

### Release:
- [ ] Git tag erstellen: `git tag v1.0.0`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] GitHub Release mit Notes erstellen
- [ ] TestFlight Build für iOS

### Nach Release:
- [ ] Verify Web Deployment
- [ ] Test Download Links
- [ ] Update Documentation
- [ ] Announce to Users

## 🎯 Nächste Schritte

1. **Repository Public machen** ✅
2. **GitHub Pages aktivieren** ⏳ (wartet auf ersten Build)
3. **Custom Domain** (optional)
4. **Code Signing Certificate** für Windows
5. **App Store Submission** für iOS

---
*Deployment Guide - Version 1.0 - 07.08.2025*