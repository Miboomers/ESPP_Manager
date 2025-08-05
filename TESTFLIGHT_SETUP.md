# 🚀 TestFlight Setup Guide - ESPP Manager

## 📱 **iOS TestFlight Deployment**

### Voraussetzungen:
- ✅ Apple Developer Account (Team ID: V7QY567836)
- ✅ Xcode installiert 
- ✅ Bundle ID: com.miboomers.esppmanager
- ✅ Version: 1.0.0 (Build 4)

### Schritt-für-Schritt Anleitung:

#### 1. **Xcode Archive erstellen:**
```bash
# Xcode Workspace ist bereits geöffnet
# In Xcode:
# 1. Device auf "Any iOS Device (arm64)" setzen
# 2. Menü: Product > Archive
# 3. Warten bis Archive fertig ist
```

#### 2. **App Store Connect Upload:**
```bash
# Nach erfolgreichem Archive:
# 1. Organizer öffnet sich automatisch
# 2. "Distribute App" klicken
# 3. "App Store Connect" wählen
# 4. "Upload" wählen
# 5. Distribution Certificate auswählen
# 6. "Upload" bestätigen
```

#### 3. **TestFlight Konfiguration:**
- App Store Connect öffnen: https://appstoreconnect.apple.com
- "Apps" → "ESPP Manager" auswählen
- "TestFlight" Tab öffnen
- Build wird automatisch erscheinen (ca. 5-10 Min)
- "Test Information" ausfüllen:
  - **App Name**: ESPP Manager
  - **App Description**: Deutsche ESPP-Verwaltung mit automatischen Steuerberechnungen
  - **Test Notes**: Beta-Version mit vollständiger EUR/USD Unterstützung

#### 4. **Beta-Tester hinzufügen:**
- "Internal Testing" → "+" klicken
- Tester per E-Mail einladen
- TestFlight App auf iPhone installieren
- Einladung akzeptieren

---

## 🖥️ **macOS TestFlight Deployment**

### Besonderheiten für macOS:
- ✅ Native macOS App (nicht Catalyst)
- ✅ Build erfolgreich: 51.8MB
- ✅ Alle Features funktional

### Schritt-für-Schritt Anleitung:

#### 1. **macOS Archive erstellen:**
```bash
# Xcode für macOS:
# 1. Scheme auf "Runner (macOS)" setzen
# 2. Device auf "My Mac" setzen
# 3. Menü: Product > Archive
# 4. Archive erstellen lassen
```

#### 2. **Notarisierung (erforderlich für macOS):**
```bash
# Nach Archive:
# 1. "Distribute App" → "Developer ID"
# 2. "Upload" für Notarisierung wählen
# 3. Apple ID: miboomers@gmail.com
# 4. App-spezifisches Passwort verwenden
```

#### 3. **TestFlight für macOS:**
- Gleicher Prozess wie iOS
- Separate macOS-Version in App Store Connect
- Tester benötigen TestFlight für Mac

---

## 📋 **Pre-Flight Checklist:**

### ✅ **Funktionale Tests:**
- [ ] PIN-Authentifizierung
- [ ] CSV Import (Fidelity Format)
- [ ] Portfolio-Berechnungen
- [ ] PDF-Export
- [ ] EUR/USD Umrechnungen
- [ ] Steuerberechnungen (42% Lohn, 25% Kapital)
- [ ] Datenexport/Teilen

### ✅ **UI/UX Tests:**
- [ ] Alle Screens navigierbar
- [ ] Portfolio-Übersicht mit blauem Hintergrund
- [ ] Konsistente EUR/USD Anzeige
- [ ] Responsive Design
- [ ] Dark Mode Support (falls aktiviert)

### ✅ **Performance Tests:**
- [ ] App-Start unter 3 Sekunden
- [ ] Smooth Scrolling im Portfolio
- [ ] CSV Import unter 5 Sekunden
- [ ] PDF Generation unter 10 Sekunden

---

## 🔧 **Build-Informationen:**

### **Aktuelle Version:**
- **Version**: 1.0.0
- **Build**: 4
- **Bundle ID**: com.miboomers.esppmanager
- **Team ID**: V7QY567836

### **Größen:**
- **iOS**: 25.0MB
- **macOS**: 51.8MB

### **Features:**
- 🔐 AES-256 Verschlüsselung
- 📱 Biometrische Authentifizierung
- 💰 Deutsche Steuerberechnung
- 📊 Live-Aktienkurse (Yahoo Finance)
- 📄 PDF-Berichte
- 💱 EUR/USD Wechselkurse
- 📤 Datenexport (CSV, Excel, PDF)

---

## 🚨 **Troubleshooting:**

### **Häufige Archive-Probleme:**
1. **"No Developer Account"**: Xcode → Preferences → Accounts → Team hinzufügen
2. **"Code Signing Error"**: Bundle ID in Apple Developer Portal prüfen
3. **"Missing Entitlements"**: Info.plist Permissions prüfen

### **TestFlight Upload-Probleme:**
1. **"Invalid Binary"**: App Store Connect Richtlinien prüfen
2. **"Missing Icons"**: App Icons in allen Größen bereitstellen
3. **"Processing Timeout"**: 30-60 Minuten warten

---

## 📞 **Support:**

**Apple Developer Support**: https://developer.apple.com/support/
**App Store Connect**: https://appstoreconnect.apple.com
**TestFlight**: https://developer.apple.com/testflight/

---
*Status: 🚀 Ready for TestFlight - iOS & macOS - 2025-08-05*