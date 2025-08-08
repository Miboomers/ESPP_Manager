# 📊 ESPP Manager

<div align="center">

[![Web App](https://img.shields.io/badge/Web%20App-Live-success?style=for-the-badge&logo=internet-explorer)](https://miboomers.github.io/ESPP_Manager)
[![GitHub Release](https://img.shields.io/github/v/release/Miboomers/ESPP_Manager?style=for-the-badge&logo=github)](https://github.com/Miboomers/ESPP_Manager/releases)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20Windows%20%7C%20macOS%20%7C%20iOS-lightgrey?style=for-the-badge)](https://github.com/Miboomers/ESPP_Manager)

**🇩🇪 Deutsche ESPP-Steuerverwaltung leicht gemacht**

*Automatisierte Berechnung von ESPP-Transaktionen nach deutschem Steuerrecht mit Lookback-Mechanismus, Wechselkurs-Management und finanzamtskonformen PDF-Berichten.*

[📱 Web App starten](https://miboomers.github.io/ESPP_Manager) • [💾 Windows Download](https://github.com/Miboomers/ESPP_Manager/actions) • [📖 Dokumentation](#-benutzerhandbuch)

</div>

---

## 🎯 Projekt-Übersicht

### Was ist ESPP Manager?

Der **ESPP Manager** ist eine sichere, multi-platform Anwendung zur Verwaltung von **Employee Stock Purchase Plan (ESPP)** Transaktionen speziell für in Deutschland steuerpflichtige Personen. Die App automatisiert die komplexen Steuerberechnungen nach deutschem Recht und erstellt finanzamtskonforme Berichte.

### 🤔 Warum wurde diese App entwickelt?

**Das Problem:**
- ESPP-Steuerberechnung in Deutschland ist extrem komplex
- Lookback-Mechanismus führt zu verschiedenen FMV-Werten
- Deutsche vs. US-Steuerbehandlung unterscheidet sich erheblich
- Wechselkurs-Dokumentation muss EZB-konform sein
- Manuelle Berechnung ist fehleranfällig und zeitaufwändig

**Die Lösung:**
- ✅ **Automatische Berechnungen** nach deutschem Steuerrecht
- ✅ **Lookback-Mechanismus** korrekt implementiert
- ✅ **Wechselkurs-Management** mit EZB-Referenzkursen
- ✅ **Finanzamtskonforme PDF-Berichte** mit allen Details
- ✅ **Sichere lokale Speicherung** mit AES-256 Verschlüsselung

### 👥 Für wen ist sie nützlich?

- **🇩🇪 In Deutschland steuerpflichtige Personen** mit ESPP-Beteiligungen
- **💼 US-Firmen Angestellte** die ESPP-Aktien gekauft haben
- **📈 Investoren** die komplexe Steuerberechnungen automatisieren wollen
- **🧾 Steuerberater** die ESPP-Mandate bearbeiten

---

## 🚀 Features & Funktionen

### 🔐 **Sicherheit & Datenschutz**
- **AES-256 Verschlüsselung** für alle lokalen Daten
- **PIN-Authentifizierung** mit Biometrie-Support
- **Offline-First Design** - keine Datenübertragung ohne Ihre Einwilligung
- **Optionaler Cloud-Sync** mit doppelter Verschlüsselung

### 📊 **ESPP-Management**
- **Automatische Rabattberechnung** aus FMV und Discount-Rate
- **Lookback-Mechanismus** für komplexe Angebotsperioden
- **Teilverkäufe** mit FIFO/LIFO-Methoden
- **Bruchteile von Aktien** (bis zu 4 Nachkommastellen)
- **Portfolio-Übersicht** mit Echtzeitbewertung

### 📥 **Import & Export**
- **Fidelity CSV Import** - vollautomatischer Import
- **Lookback-Daten Import** via Copy-Paste oder CSV
- **PDF-Berichte** mit mehrseitigen Tabellen
- **Excel Export** für weitere Analyse

### 🇩🇪 **Deutsche Steuerkonformität**
- **Lohnsteuer vs. Kapitalertragsteuer** korrekt getrennt
- **EZB-Referenzkurse** für Wechselkurs-Dokumentation  
- **§ 20 EStG konforme Berechnungen**
- **Doppelbesteuerungsvermeidung** nach deutschem Recht

### 🌐 **Multi-Platform Support**
- **Web App** - läuft in jedem modernen Browser
- **Windows Desktop** - native Windows-Anwendung
- **macOS** - optimiert für Mac-Nutzer
- **iOS** - mobile App für iPhone/iPad

---

## 🖥️ Unterstützte Plattformen

| Platform | Status | Installation | Features |
|----------|---------|--------------|----------|
| 🌐 **Web** | ✅ Live | [Direkter Zugriff](https://miboomers.github.io/ESPP_Manager) | Vollständig, PWA-fähig |
| 🪟 **Windows** | ✅ Verfügbar | [GitHub Actions Download](https://github.com/Miboomers/ESPP_Manager/actions) | Native Desktop-App |
| 🍎 **macOS** | ✅ TestFlight | TestFlight Beta | Native macOS-App |
| 📱 **iOS** | ✅ TestFlight | TestFlight Beta | Mobile-optimiert |

### Systemanforderungen

**Web:**
- Moderner Browser (Chrome 90+, Firefox 88+, Safari 14+, Edge 90+)
- JavaScript aktiviert
- IndexedDB-Unterstützung

**Desktop (Windows/macOS):**
- Windows 10/11 oder macOS 10.15+
- 2 GB RAM, 100 MB Speicherplatz

**Mobile (iOS):**
- iOS 12.0 oder höher
- 50 MB Speicherplatz

---

## 📦 Installation & Setup

### 🌐 **Für End-User (Web App)**

1. **Öffnen Sie** [https://miboomers.github.io/ESPP_Manager](https://miboomers.github.io/ESPP_Manager)
2. **PIN erstellen** - wählen Sie eine 4-6-stellige PIN
3. **Einstellungen konfigurieren** - Steuersätze anpassen
4. **Fertig!** - App ist sofort nutzbar

### 💻 **Für Entwickler**

```bash
# Repository klonen
git clone https://github.com/Miboomers/ESPP_Manager.git
cd ESPP_Manager

# Flutter Dependencies installieren
flutter pub get

# Firebase Konfiguration (optional für lokale Entwicklung)
cp lib/config/firebase_config_template.dart lib/config/firebase_config.dart
# API Keys eintragen (vom Projektleiter erhalten)

# Web Version starten
flutter run -d chrome

# Native Version bauen
flutter build windows  # Für Windows
flutter build macos    # Für macOS
```

**Entwicklerumgebung:**
- Flutter 3.32.0+
- Dart 3.9.0+
- Xcode 16+ (für macOS/iOS)
- Visual Studio 2022 (für Windows)

---

## 📖 Benutzerhandbuch

### 🚀 **Erste Schritte**

1. **PIN einrichten**
   - Wählen Sie eine sichere 4-6-stellige PIN
   - Aktivieren Sie optional Biometrie (Touch ID/Face ID)

2. **Grundeinstellungen**
   - **Lohnsteuersatz**: Standard 42% (anpassbar)
   - **Kapitalertragsteuersatz**: Standard 25% (+ Soli)
   - **ESPP Discount**: Standard 15% (firmenspezifisch)
   - **Wechselkurs**: EZB-Referenzkurs oder manuell

### 📈 **ESPP-Transaktionen verwalten**

#### **Neue Transaktion hinzufügen:**
1. **"Transaktion hinzufügen"** tippen
2. **Kaufdatum** und **Verkaufsdatum** eingeben
3. **FMV-Werte** eingeben:
   - FMV am Kaufdatum
   - FMV zu Beginn der Angebotsperiode (Lookback)
4. **Aktienanzahl** (Bruchteile möglich: z.B. 36.1446)
5. **Automatische Berechnung** von Rabatt und Steuern

#### **Portfolio-Übersicht:**
- **Offene Positionen** - noch nicht verkaufte Aktien
- **Geschlossene Positionen** - bereits verkaufte Aktien
- **Gesamtwert** in EUR und USD
- **Steuerübersicht** - Lohn- und Kapitalertragsteuer

### 📥 **CSV-Import von Fidelity**

1. **Bei Fidelity anmelden** und ESPP-Daten als CSV exportieren
2. **"Import" → "CSV Import"** wählen
3. **CSV-Datei auswählen** oder per Drag & Drop
4. **Automatische Erkennung** der Spalten
5. **Import bestätigen** - alle Transaktionen werden importiert

#### **Unterstützte CSV-Formate:**
- Fidelity ESPP Transaction Export
- Custom CSV (mit Spalten-Mapping)
- Lookback-Daten (separater Import)

### 📊 **Lookback-Daten verwalten**

Für korrekte deutsche Steuerberechnung sind Lookback-Daten erforderlich:

1. **"Lookback-Daten" → "Hinzufügen"**
2. **Angebotsperiode** definieren (Start/Ende)
3. **FMV-Werte eingeben:**
   - FMV zu Beginn der Periode
   - FMV am Ende der Periode
4. **Automatische Verknüpfung** mit bestehenden Transaktionen

### 📄 **PDF-Berichte generieren**

1. **"Berichte" → "Steuerbericht generieren"**
2. **Zeitraum auswählen** (Steuerjahr)
3. **Bericht-Optionen:**
   - Detaillierte Transaktionsliste
   - Steuerberechnung nach deutschem Recht
   - Wechselkurs-Dokumentation
   - Finanzamts-Erklärung
4. **PDF herunterladen** oder teilen

#### **Bericht-Inhalte:**
- **Executive Summary** mit Gesamtsteuern
- **Transaktionsliste** mit allen Details
- **Steuerberechnung** nach § 20 EStG
- **Wechselkurs-Nachweis** mit EZB-Kursen
- **Rechtliche Erklärung** für das Finanzamt

### ☁️ **Cloud-Sync einrichten** (Optional)

1. **Einstellungen → Cloud-Sync**
2. **Firebase-Account erstellen** oder anmelden
3. **Automatische Synchronisation** aktivieren
4. **Verschlüsselung:** Daten werden doppelt verschlüsselt
   - Lokal mit Ihrer PIN
   - Zusätzlich für Cloud-Übertragung

**Vorteile:**
- Synchronisation zwischen Geräten
- Automatisches Backup
- Zugriff von überall

---

## 🔧 Technische Details

### 🏗️ **Architektur**

```
ESPP Manager Architektur:
├── 🎨 Presentation Layer (Flutter/Dart)
│   ├── Screens (Home, Portfolio, Settings, etc.)
│   ├── Widgets (Reusable Components)  
│   └── Providers (Riverpod State Management)
├── 💼 Business Logic Layer
│   ├── Services (Tax Calculation, Import/Export)
│   ├── Models (Transaction, Settings, etc.)
│   └── Repositories (Data Access Layer)
├── 🔐 Security Layer
│   ├── AES-256 Encryption
│   ├── PIN Authentication
│   └── Biometric Support
├── 💾 Storage Layer
│   ├── Hive (Local Database)
│   ├── IndexedDB (Web)
│   └── Firebase (Optional Cloud)
└── 🌐 External APIs
    ├── Yahoo Finance (Stock Prices)
    ├── EZB (Exchange Rates)
    └── Firebase (Authentication/Sync)
```

### 🔐 **Sicherheit**

- **Verschlüsselung:** AES-256-GCM für alle lokalen Daten
- **Authentifizierung:** PIN + optional Biometrie (Touch ID, Face ID, Windows Hello)
- **Speicherung:** Lokale Verschlüsselung mit Flutter Secure Storage
- **Cloud-Sync:** Doppelte Ende-zu-Ende-Verschlüsselung
- **Datenschutz:** DSGVO-konform, keine Tracking-Cookies

### 📊 **Datenmodell**

```dart
class TransactionModel {
  String id;
  DateTime purchaseDate;
  DateTime? saleDate;
  double quantity;
  double fmvPerShare;          // FMV am Kaufdatum
  double lookbackFmv;          // FMV zu Beginn der Angebotsperiode
  double purchasePricePerShare; // MIN(lookbackFmv, fmvPerShare) * 0.85
  double? salePricePerShare;   // Verkaufspreis
  double exchangeRatePurchase; // USD/EUR Kurs am Kaufdatum
  double? exchangeRateSale;    // USD/EUR Kurs am Verkaufsdatum
}
```

### 🛠️ **Build-System**

**GitHub Actions CI/CD:**
```yaml
Workflows:
├── Windows Build (Automatisch bei Push)
├── Web Build → GitHub Pages Deployment
├── Test Suite (Unit & Integration Tests)
└── Security Scan (Dependency Check)
```

**Lokale Builds:**
- **Xcode** für macOS/iOS TestFlight
- **Flutter CLI** für alle Plattformen
- **ImageMagick** für Icon-Generation

---

## 🇩🇪 Deutsche Steuerberechnung

### 📋 **Rechtliche Grundlagen**

Die ESPP-Besteuerung in Deutschland folgt spezifischen Regeln nach **§ 20 EStG** in Verbindung mit den **Lohnsteuerrichtlinien (LStR)**:

#### **1. Geldwerter Vorteil (Lohnsteuer)**
```
Geldwerter Vorteil = FMV am Kaufdatum - tatsächlicher Kaufpreis
Lohnsteuer = Geldwerter Vorteil × Lohnsteuersatz (42%)
```

#### **2. Kapitalertragsteuer**
```
Kostenbasis = FMV am Kaufdatum (bereits lohnversteuert)
Kapitalgewinn = Verkaufspreis - FMV am Kaufdatum
Kapitalertragsteuer = Kapitalgewinn × 25% (+ Soli + evtl. Kirchensteuer)
```

### 🔄 **Lookback-Mechanismus**

Der Lookback-Mechanismus ist zentral für die korrekte Besteuerung:

1. **Zwei relevante FMV-Werte:**
   - FMV zu Beginn der Angebotsperiode (Lookback FMV)
   - FMV am Kaufdatum (Purchase FMV)

2. **Kaufpreis-Berechnung:**
   ```
   Kaufpreis = MIN(Lookback FMV, Purchase FMV) × (1 - Discount %)
   ```

3. **Steuerliche Kostenbasis:**
   - **Für Lohnsteuer:** Kaufpreis (tatsächlich gezahlt)
   - **Für Kapitalertragsteuer:** FMV am Kaufdatum (nicht Lookback!)

### 💱 **Wechselkurs-Behandlung**

**EZB-Referenzkurse sind Standard:**
- **Kaufdatum:** USD/EUR Kurs zur Bestimmung des EUR-Werts
- **Verkaufsdatum:** USD/EUR Kurs für Verkaufserlös
- **Dokumentation:** Alle Kurse in PDF-Berichten hinterlegt

**Besonderheit für deutsche Steuer:**
```
EUR-Basis Berechnung:
├── Geldwerter Vorteil = (FMV € - Kaufpreis €)
├── Kapitalgewinn = (Verkaufspreis € - FMV €)
└── Alle Berechnungen in EUR (nicht USD!)
```

### 📄 **Finanzamts-konforme Berichte**

Die PDF-Berichte enthalten alle erforderlichen Informationen:

1. **Executive Summary**
   - Gesamte Lohnsteuer auf geldwerte Vorteile
   - Gesamte Kapitalertragsteuer auf Gewinne
   - Zusammenfassung nach Steuerjahren

2. **Detaillierte Transaktionsliste**
   - Alle Kauf- und Verkaufsdaten
   - FMV-Werte und Wechselkurse
   - Steuerberechnungen pro Transaktion

3. **Rechtliche Erläuterung**
   - Erklärung des Lookback-Mechanismus
   - Doppelbesteuerungsvermeidung
   - Relevante Paragraphen (§ 20 EStG, R 19.9 LStR)

---

## 👩‍💻 Entwickler-Informationen

### 🗂️ **Code-Struktur**

```
lib/
├── core/
│   ├── security/           # AES-256, PIN-Auth, Biometrie
│   ├── services/           # Business Logic Services
│   └── utils/             # Helper Functions
├── data/
│   ├── models/            # Data Models (Transaction, Settings)
│   ├── repositories/      # Data Access Layer  
│   └── datasources/       # External APIs
├── presentation/
│   ├── screens/           # App Screens
│   ├── widgets/           # Reusable UI Components
│   └── providers/         # State Management (Riverpod)
└── config/
    ├── firebase_config_stub.dart    # Demo Config (committed)
    └── firebase_config_template.dart # Template für echte Config
```

### 🔨 **Build-Prozesse**

**Web Deployment (Automatisch):**
```bash
# Wird bei jedem Push zu main ausgeführt
flutter build web --release
# Automatisches Deployment zu GitHub Pages
```

**Windows Build (CI/CD):**
```bash
# GitHub Actions generiert ZIP-Artifact
flutter build windows --release
# Download über GitHub Actions Artifacts
```

**macOS/iOS (Lokal via Xcode):**
```bash
# Workspace öffnen
open macos/Runner.xcworkspace

# In Xcode:
# 1. Product → Archive
# 2. Distribute App → TestFlight
```

### 🤝 **Beitragen zum Projekt**

**Entwicklungssetup:**
1. Repository forken
2. Development branch erstellen
3. Änderungen implementieren
4. Tests ausführen: `flutter test`
5. Pull Request erstellen

**Coding Standards:**
- Flutter/Dart Best Practices
- Riverpod für State Management  
- Automated Testing (Unit & Widget Tests)
- Dokumentation für neue Features

**Issue-Kategorien:**
- 🐛 Bug Reports
- ✨ Feature Requests  
- 📚 Documentation
- 🔐 Security Issues

### 🚀 **CI/CD Pipeline**

```yaml
GitHub Actions Workflows:
├── 🔍 Code Analysis
│   ├── Flutter Analyze
│   ├── Dart Format Check
│   └── Security Scan
├── 🧪 Testing
│   ├── Unit Tests
│   ├── Widget Tests  
│   └── Integration Tests
├── 🏗️ Multi-Platform Build
│   ├── Web → GitHub Pages
│   ├── Windows → Artifacts
│   └── Build Verification
└── 🚀 Deployment
    ├── GitHub Pages (Web)
    ├── Release Creation
    └── Artifact Publishing
```

---

## 📄 Lizenz & Rechtliches

### 📜 **Open Source Lizenz**

Dieses Projekt steht unter der **MIT License** - siehe [LICENSE](LICENSE) Datei für Details.

```
MIT License - Kurzzusammenfassung:
✅ Kommerzielle Nutzung erlaubt
✅ Modifikation erlaubt  
✅ Distribution erlaubt
✅ Private Nutzung erlaubt
❗ Lizenz und Copyright-Hinweis erforderlich
❗ Ohne Gewähr/Garantie
```

### ⚠️ **Haftungsausschluss**

**WICHTIGER RECHTLICHER HINWEIS:**

Diese Software wird "wie besehen" zur Verfügung gestellt, ohne jegliche ausdrückliche oder stillschweigende Gewährleistung. Die Autoren oder Copyright-Inhaber sind nicht haftbar für Schäden jeglicher Art, die aus der Nutzung dieser Software entstehen.

**Steuerliche Haftung:**
- Diese App ist ein **Hilfsmittel** für Steuerberechnungen
- Sie ersetzt **keine professionelle Steuerberatung**
- Nutzer sind **selbst verantwortlich** für die Richtigkeit ihrer Steuererklärungen
- Bei Unsicherheit konsultieren Sie einen **Steuerberater** oder **Steuerexperten**
- Die implementierten Steuerberechnungen basieren auf öffentlich verfügbaren Informationen und können von Ihrem spezifischen Fall abweichen

### 🔒 **Datenschutz**

**DSGVO-Konforme Datenverarbeitung:**

**Lokale Datenspeicherung:**
- Alle Daten werden standardmäßig **lokal auf Ihrem Gerät** gespeichert
- **Keine Übertragung** an Dritte ohne Ihre ausdrückliche Einwilligung
- **AES-256 Verschlüsselung** für alle sensiblen Daten

**Optionaler Cloud-Sync:**
- Nur mit Ihrer **ausdrücklichen Einwilligung** aktiviert
- Daten werden **doppelt verschlüsselt** übertragen
- Sie können den Cloud-Sync **jederzeit deaktivieren**
- **Löschung aller Cloud-Daten** auf Anfrage möglich

**Externe Services:**
- **Yahoo Finance API:** Nur für Aktienkurse, keine persönlichen Daten
- **EZB API:** Nur für Wechselkurse, keine persönlichen Daten
- **Firebase:** Nur bei aktiviertem Cloud-Sync, verschlüsselte Daten

---

## 🤝 Support & Community

### ❓ **Häufige Fragen (FAQ)**

<details>
<summary><strong>🔐 Sind meine Daten sicher?</strong></summary>

Ja! Ihre Daten sind mit militärischer AES-256 Verschlüsselung geschützt. Standardmäßig werden alle Daten nur lokal auf Ihrem Gerät gespeichert. Cloud-Sync ist optional und ebenfalls verschlüsselt.
</details>

<details>
<summary><strong>💰 Sind die Steuerberechnungen korrekt?</strong></summary>

Die Berechnungen basieren auf aktueller deutscher Steuergesetzgebung (§ 20 EStG). Jedoch ersetzt diese App keine professionelle Steuerberatung. Bei komplexen Fällen konsultieren Sie einen Steuerberater.
</details>

<details>
<summary><strong>📱 Funktioniert die App offline?</strong></summary>

Ja! Die App ist offline-first designed. Sie können alle Funktionen ohne Internetverbindung nutzen. Nur für Aktienkurs-Updates und Cloud-Sync ist eine Internetverbindung erforderlich.
</details>

<details>
<summary><strong>💾 Kann ich meine Daten exportieren?</strong></summary>

Ja! Sie können alle Ihre Daten als CSV exportieren oder PDF-Berichte generieren. Ein vollständiger Datenexport ist jederzeit möglich.
</details>

<details>
<summary><strong>🔄 Wie funktioniert der Lookback-Mechanismus?</strong></summary>

Der Lookback-Mechanismus verwendet den niedrigeren FMV-Wert (Anfang vs. Ende der Angebotsperiode) für die Kaufpreis-Berechnung, aber den FMV am Kaufdatum als steuerliche Kostenbasis. Details siehe Dokumentation.
</details>

### 🛠️ **Support erhalten**

**Bei technischen Problemen:**
1. [GitHub Issues](https://github.com/Miboomers/ESPP_Manager/issues) durchsuchen
2. Neues Issue mit detaillierter Beschreibung erstellen
3. Logs und Screenshots beifügen

**Bei steuerlichen Fragen:**
- Konsultieren Sie einen qualifizierten Steuerberater
- Diese App ersetzt keine professionelle Steuerberatung

### 🗓️ **Roadmap**

**Geplante Features:**
- [ ] **Automatische Lookback-Daten** von Brokerage APIs
- [ ] **Mehrere Währungen** Support (CHF, GBP, etc.)
- [ ] **Erweiterte Reporting** Features
- [ ] **Integration mit Steuer-Software**
- [ ] **Mobile Apps** für Android
- [ ] **API für Steuerberater**

**Aktuelle Prioritäten:**
1. Stabilität und Bug-fixes
2. Erweiterte Import-Funktionen
3. Bessere Dokumentation
4. Community-Feedback Integration

### 👥 **Credits**

**Entwickelt mit:**
- [Flutter](https://flutter.dev) - UI Framework
- [Firebase](https://firebase.google.com) - Backend Services  
- [Riverpod](https://riverpod.dev) - State Management
- [Hive](https://hivedb.dev) - Lokale Datenbank
- [GitHub Actions](https://github.com/features/actions) - CI/CD

**Datenquellen:**
- [Yahoo Finance API](https://finance.yahoo.com) - Aktienkurse
- [Europäische Zentralbank](https://ecb.europa.eu) - Wechselkurse
- Deutsche Steuergesetzgebung (EStG, LStR)

---

<div align="center">

**📊 ESPP Manager** - *Deutsche ESPP-Steuerverwaltung leicht gemacht*

[![Web App](https://img.shields.io/badge/Jetzt_starten-Web_App-success?style=for-the-badge&logo=internet-explorer)](https://miboomers.github.io/ESPP_Manager)

*Entwickelt in Deutschland 🇩🇪 | Open Source ❤️ | DSGVO-Konform 🔒*

</div>