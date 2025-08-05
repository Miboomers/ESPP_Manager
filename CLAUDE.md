# ESPP Manager - Claude Development Memory

## 🔑 Developer Account Daten
- **APPLE_ID**: miboomers@gmail.com
- **TEAM_ID**: V7QY567836
- **Bundle ID**: com.miboomers.esppmanager

## 📱 Projekt Status (2025-08-01 - FINAL RELEASE!)

### ✅ 100% Production-Ready + EUR-Steuerkonformität:
- **Security**: AES-256 Verschlüsselung, PIN-Auth, Biometrie-ready
- **PIN-UX**: Auto-Focus, besserer Flow
- **Settings**: Vollständige Konfiguration (42% Lohnsteuer, 25% Kapitalsteuer, 15% ESPP)
- **Transaktionen**: Eingabe mit automatischen Berechnungen, Deutsche Zahlenformate
- **Portfolio**: Echte Berechnungen, Live-Übersicht, Bruchteile von Aktien
- **ESPP Features**: Automatische Rabattberechnung, Steuerberechnungen
- **UX**: Deutsche Eingaben (Komma/Punkt), Wechselkurs-Handling
- **Architektur**: Flutter + Riverpod + Hive + AES-256
- **🆕 EUR-Steuerkonformität**: Kursgewinne nach deutschem Recht (EUR-Basis)
- **🆕 Dependency Updates**: Aktuelle Versionen, keine macOS WebView Warnings

### 🖥️ Platform Status:
- **macOS**: ✅ 100% funktional, alle Features getestet
- **iOS**: 🔄 Bereit für Device Testing
- **Web**: ✅ Fallback mit SharedPreferences

### 🚀 Final Features (v1.0 - v1.4 COMPLETE):
- **Bruchteile**: Bis zu 4 Nachkommastellen (z.B. 36.1446 Aktien)
- **Auto-Berechnung**: ESPP Rabatt aus FMV × (1 - Discount%)
- **Settings-Integration**: Steuersätze automatisch geladen
- **Portfolio-Summary**: Echte Berechnungen mit USD/EUR
- **Deutsche Formate**: 100,50 → 100.50 automatisch
- **Persistierung**: Alle Daten werden korrekt gespeichert
- **Verkaufsprozess**: Aktien direkt aus Portfolio verkaufen
- **Teilverkäufe**: Nur einen Teil einer Position verkaufen möglich
- **UI-Konsistenz**: Einheitliche Icons und Workflows
- **Klare Trennung**: Separate Screens für Kauf und Verkauf
- **🆕 EUR-Steuerberechnungen**: Kapitalertragsteuer nach deutschem Recht
- **🆕 Wechselkurs-Dokumentation**: Kauf- und Verkaufskurse gespeichert
- **🆕 Dependency Updates**: printing 5.14.2, share_plus 11.0.0, intl 0.20.2
- **🆕 UI/UX Verbesserungen**: Einheitliche Bottom Action Bar in allen Screens
- **🆕 Sortierung korrigiert**: "Letzte Transaktionen" zeigt neueste zuerst
- **🆕 EUR-First Design**: Portfolio-Werte primär in EUR, USD dezent
- **🆕 Wiederverwendbare Widgets**: PortfolioSummaryWidget in Home & Portfolio
- **🆕 Konsistente Action Bars**: Alle 4 Screens identische Button-Layout
- **🆕 Fidelity CSV Import**: Vollautomatischer Import mit eindeutigen IDs
- **🆕 Yahoo Finance API**: Unbegrenzte Aktienkurse ohne Rate Limits  
- **🆕 Mehrseitige PDF-Berichte**: Automatische Seitenumbrüche bei vielen Transaktionen
- **🆕 Mobile UI Perfekt**: Alle Overflow-Probleme behoben
- **🆕 Daten-Reset Funktion**: Komplettes Löschen aller Daten
- **🆕 API Debug Tools**: Live-Diagnose der Aktienkurs-APIs

### 🗂️ Projektstruktur:
```
lib/
├── core/security/          # Verschlüsselung & Auth
├── data/
│   ├── models/            # TransactionModel (quantity: double), SettingsModel
│   ├── repositories/      # Repository Pattern mit Debug-Logging
│   └── datasources/       # API Services (Mock + Real)
└── presentation/
    ├── screens/           # Login, Home, Settings, Portfolio, AddTransaction  
    ├── widgets/           # Reusable Components
    └── providers/         # Riverpod State Management
```

## 📊 Berechnungslogik (German Tax):
- **Quantity**: `double` für Bruchteile (2.5 Aktien)
- **Purchase Price**: FMV × (1 - Discount%) - automatisch berechnet
- **ESPP Rabatt**: (FMV - Purchase Price) × Quantity
- **Lohnsteuer**: Rabatt × 42% (aus Settings)
- **Kapitalertragsteuer**: Max(Gewinn, 0) × 25%
- **EUR Umrechnung**: USD × 0.92 (Standard Wechselkurs)

## 🔧 Portfolio Berechnungen:
```dart
final totalShares = openPositions.fold<double>(0, (sum, t) => sum + t.quantity);
final totalInvestment = openPositions.fold<double>(0, (sum, t) => sum + (t.purchasePricePerShare * t.quantity));
final totalDiscount = openPositions.fold<double>(0, (sum, t) => sum + ((t.fmvPerShare - t.purchasePricePerShare) * t.quantity));
final incomeTax = totalDiscount * settings.defaultIncomeTaxRate;
```

## 🎯 Vollständige Feature-Liste:
- ✅ **Sichere Speicherung** mit AES-256 Verschlüsselung
- ✅ **PIN-Authentifizierung** mit Auto-Focus  
- ✅ **Transaktions-Management** mit Bruchteilen (bis 4 Nachkommastellen)
- ✅ **Automatische ESPP-Berechnungen**
- ✅ **Deutsche Zahlenformate** (Komma/Punkt)
- ✅ **Portfolio-Übersicht** mit echten Daten
- ✅ **Steuer-Berechnungen** (Lohn-/Kapitalsteuer)
- ✅ **USD/EUR Umrechnung**
- ✅ **Settings-Integration**
- ✅ **Daten-Persistierung**
- ✅ **Verkaufsprozess** aus Portfolio-Positionen
- ✅ **Teilverkäufe** von Positionen möglich
- ✅ **UI-Konsistenz** mit einheitlichen Icons
- ✅ **Klare Workflows** - Kauf und Verkauf getrennt

## 📱 iOS Testing Setup:
```bash
# 1. iOS Device verbinden
flutter devices

# 2. iOS Simulator starten  
open -a Simulator

# 3. App auf iOS testen
flutter run -d ios
```

## 📦 Aktuelle Dependencies (2025-08-01):

### 🔧 Hauptkomponenten:
- **printing**: `^5.14.2` ✅ (behebt macOS WebView Warnings)
- **share_plus**: `^11.0.0` ✅ (Major Update)
- **intl**: `^0.20.2` ✅ (Aktuelle Internationalisierung)
- **fl_chart**: `^0.69.2` ✅ (Kompatible Chart-Version)
- **flutter_lints**: `^6.0.0` ✅ (Neueste Lint-Regeln)

### 📋 Nächste Updates möglich:
- `flutter_secure_storage`: v4.0.0 verfügbar (Breaking Changes)
- `build_runner`: v2.6.0 verfügbar (Wartet auf hive_generator)
- Verschiedene transitive Dependencies können bei nächstem Flutter Update aktualisiert werden

### ⚠️ Bekannte Einschränkungen:
- `hive_generator` limitiert `build_runner` auf v2.4.13
- Einige transitive Dependencies warten auf Flutter SDK Updates
- `js` Package ist discontinued (wird automatisch ersetzt)

## 🚀 FINAL RELEASE FEATURES (v1.5):

### ✅ Kritische Bugfixes behoben:
- **CSV Import ID-Kollisionen**: Eindeutige IDs für alle Transaktionen
- **PDF Tabellen-Layout**: Mehrseitige PDFs bei vielen Transaktionen  
- **Mobile UI Overflows**: Alle Overflow-Probleme behoben
- **API Rate Limits**: Yahoo Finance als Primary API (unbegrenzt)
- **ScrollView Probleme**: Portfolio vollständig scrollbar

### ✅ Production-Ready Features:
- **Fidelity CSV Import**: Automatischer Import aller ESPP-Daten
- **API Debug Tools**: Live-Diagnose und Troubleshooting
- **Daten-Reset**: Complete App-Reset Funktion
- **Mobile UI**: Perfekt optimiert für iPhone
- **PDF-Berichte**: Mehrseitig, Finanzamt-ready

### 🆕 LOOKBACK-DATEN INTEGRATION (v1.5):
- **Mehrsprachiger Parser**: Unterstützt deutsche + englische Fidelity-Formate
- **Copy-Paste Import**: Direkter Import aus Fidelity Lookback-Tabellen
- **Manuelle Eingabe**: Eingabemaske für einzelne Lookback-Einträge
- **Automatische Verknüpfung**: Matching von Verkäufen mit Lookback-Daten
- **Korrekte Steuerberechnung**: Berücksichtigt Lookback-Mechanismus für deutsche Steuer
- **Erweiterte PDF-Berichte**: Inkl. Lookback FMV, Angebotszeiträume und korrekter Lohnsteuer/Kapitalertragsteuer-Trennung
- **Finanzamt-konforme Erklärung**: Neuer Berichtstext erklärt Lookback-Mechanismus und Doppelbesteuerungsvermeidung

### 🔄 Nächste Session:
- **Backup/Restore Funktionen** implementieren
- **TestFlight Beta** Upload vorbereiten
- **App Store** Submission

## 🆕 ESPP STEUERBERECHNUNG FINAL GEKLÄRT (v1.6 - 2025-08-04):

### ✅ KORREKTE ESPP-Kostenbasisregel bestätigt:
- **Kostenbasis für Kapitalertragsteuer**: `fmvPerShare` (FMV am Kaufdatum)
- **NICHT**: MIN(Lookback-FMV, FMV-Kaufdatum)
- **Grund**: Der geldwerte Vorteil wurde bereits mit FMV am Kaufdatum lohnversteuert

### ✅ Korrekte ESPP-Steuerberechnung (nach deutschem Steuerrecht):

#### 📊 ESPP Lookback-Mechanismus verstehen:
1. **Zwei FMV-Werte entscheidend:**
   - FMV am **Anfang** der Angebotsperiode (Lookback FMV)  
   - FMV am **Ende** der Angebotsperiode (Purchase Date FMV)

2. **Kaufpreis-Berechnung:**
   - Nimm den **niedrigeren** der beiden FMV-Werte
   - Ziehe 15% Rabatt ab: `Kaufpreis = MIN(Lookback-FMV, FMV-Kaufdatum) × 0.85`

3. **Lohnversteuerung (Geldwerter Vorteil):**
   ```
   Geldwerter Vorteil = FMV am Kaufdatum - tatsächlicher Kaufpreis
   ```

4. **Kapitalertragsteuer-Kostenbasis:**
   ```
   Kostenbasis = FMV am Kaufdatum
   ```
   Der Lookback-FMV ist nur für die Kaufpreis-Berechnung relevant!

#### 🧮 Beispiel-Berechnung:
```
FMV Start (Lookback): $200.00
FMV Kaufdatum: $240.00  
Tatsächlicher Kaufpreis: $200 × 0.85 = $170.00
Geldwerter Vorteil: $240 - $170 = $70.00 (lohnversteuert)

Bei Verkauf für $300:
Kapitalgewinn = $300 - $240 = $60.00 ✅
(Kostenbasis ist FMV am Kaufdatum, nicht Lookback-FMV!)
```

#### 💻 Finale Code-Implementation:
```dart
// KORREKT - Kostenbasis ist FMV am Kaufdatum:
double? get capitalGainPerShareUSD => 
    salePricePerShare != null ? salePricePerShare! - fmvPerShare : null;

// Geldwerter Vorteil:
double get geldwerterVorteil => fmvPerShare - purchasePricePerShare;

// esppBasisPrice nur für interne Berechnungen:
double get esppBasisPrice => MIN(lookbackFmv, fmvPerShare); // für Kaufpreis-Berechnung
```

#### 📄 PDF-Bericht - Korrekte Darstellung:
- **Formel**: "Veräußerungserlös – FMV am Erwerbsstichtag = steuerpflichtiger Kapitalgewinn"
- **Erklärung**: "Der FMV am Kaufdatum ist die Kostenbasis, da der geldwerte Vorteil bereits lohnversteuert wurde"
- **Verwendung**: `totalGeldwerterVorteil` statt `totalDiscount`

#### 🔄 Import-Logik Korrektur:
- **Geschlossene Positionen CSV**: `freshImport` (ersetzt ALLES)
- **Offene Positionen CSV**: `smartUpdate` (ersetzt nur Käufe, behält Verkäufe)
- **Klarstellung**: Offene Positionen = aktueller Depot-Stand, keine "intelligenten" Dialoge mehr

#### 🎯 Rechtliche Grundlage:
- § 20 EStG i. V. m. R 19.9 Abs. 2 LStR (Doppelbesteuerungsvermeidung)
- § 16 AO (EZB-Referenzkurse für Wechselkurse)
- Lookback-Mechanismus: Der niedrigere FMV ist die steuerliche Kostenbasis

## 🆕 PDF-TABELLEN REDESIGN (v1.7 - 2025-08-04):

### ✅ Revolutionäres doppelzeiliges Tabellen-Design:

#### 📊 Neue Tabellen-Struktur:
**Doppelzeilige Zellen mit maximaler Transparenz:**
```
123.45 EUR    ← EUR-Wert zum jeweiligen Stichtagskurs
194.74 USD    ← Original USD-Wert aus Fidelity
```

#### 🏛️ Spalten-Layout:
1. **Verkaufsdatum** - Datum des Aktienverkaufs
2. **Kaufdatum** - Datum des ESPP-Kaufs  
3. **Angebotszeitraum** - ESPP-Angebotsperiode
4. **Stück** - Anzahl der verkauften Aktien
5. **FMV Start** - FMV am Beginn der Angebotsperiode (EUR/USD)
6. **FMV Kauf** - FMV am Kaufdatum = steuerliche Kostenbasis (EUR/USD)
7. **Kaufpreis** - Tatsächlich gezahlter Preis mit 15% Rabatt (EUR/USD)
8. **Verkaufspreis** - Verkaufspreis pro Aktie (EUR/USD)
9. **Erlös** - Gesamterlös aus Verkauf (EUR/USD)
10. **Lstpfl. Betrag EUR** - Lohnsteuerpflichtiger geldwerter Vorteil
11. **Kapitalgewinn EUR** - Steuerpflichtiger Kapitalgewinn

#### 💡 Intelligente Wechselkurs-Transparenz:
- **Automatische Erkennung**: Nutzer kann verwendete Wechselkurse direkt ablesen
- **Stichtagsgenau**: EUR-Werte basieren auf EZB-Kursen zum jeweiligen Datum
- **Kontrollfunktion**: Vergleich EUR/USD zeigt Plausibilität der Kurse

#### 🎯 Konsistente Steuerbasis-Darstellung:
**VORHER (inkonsistent):**
- Lohnsteuer EUR: **Berechneter Steuerbetrag** (42% von Vorteil)
- Kapitalgewinn EUR: **Steuerpflichtige Basis** (Gewinn vor Steuer)

**NACHHER (konsistent):**
- **Lstpfl. Betrag EUR**: Lohnsteuerpflichtige Basis (geldwerter Vorteil)
- **Kapitalgewinn EUR**: Kapitalertragsteuerpflichtige Basis (Gewinn)

#### 💻 Technische Optimierungen:
```dart
// Doppelzeilige Zelleninhalte:
'${fmvKaufEUR.toStringAsFixed(2)} EUR\n${t.fmvPerShare.toStringAsFixed(2)} USD'

// Angepasste Tabellen-Parameter:
cellHeight: 25,                    // Höhere Zellen
cellStyle: pw.TextStyle(fontSize: 7), // Kleinere Schrift
columnWidths: {
  4: const pw.FixedColumnWidth(60), // Optimierte Breiten
  // ...
}
```

#### 📋 Verbesserte Erklärungen:
- **Klare Beschreibung**: "Alle Preisspalten zeigen oben EUR (zum jeweiligen Stichtagskurs), unten USD (Originalwerte)"
- **ESPP-Mechanismus**: "Kaufpreis = MIN(FMV Start, FMV Kauf) × 85%"
- **Steuerlogik**: "Kapitalgewinn = Verkaufspreis minus FMV Kauf"

#### 🎨 Design-Verbesserungen:
- **Spaltenbreiten**: Optimiert für doppelzeilige Inhalte (60px pro Preisspalte)
- **Lesbarkeit**: Schriftgröße 7px für kompakte aber lesbare Darstellung
- **Alignment**: Zentrierte Ausrichtung für Datum/Periode, rechtsbündig für Zahlen

### 🚀 Vorteile der neuen Tabelle:
1. **Maximale Transparenz**: Alle Original- und Umrechnungswerte sichtbar
2. **Wechselkurs-Kontrolle**: Verwendete Kurse direkt erkennbar
3. **Finanzamt-ready**: EUR-Werte für Steuererklärung + USD-Belege als Nachweis
4. **Konsistente Logik**: Beide Steuerspalten zeigen Bemessungsgrundlagen
5. **Platzsparend**: Alle Informationen in einer kompakten Übersicht

## 🖥️ MULTI-PLATFORM SUPPORT (v1.8 - 2025-08-05):

### ✅ Windows Support implementiert:
- **GitHub Actions**: Automatische Windows-Builds bei jedem Push
- **Dependencies**: Alle Windows-spezifischen Plugins konfiguriert
- **Build Output**: ZIP-Datei mit allen benötigten Dateien

### ✅ GitHub Repository Setup:
- **Repository**: https://github.com/Miboomers/ESPP_Manager
- **Actions Workflow**: `.github/workflows/build.yml`
- **Artifacts**: Windows-Builds als ZIP zum Download

### ⚠️ macOS Build Fixes (Xcode Archive):
1. **Entitlements bereinigt**:
   - `com.apple.security.keychain-access-groups` entfernt
   - `com.apple.security.application-groups` entfernt
   - Nur notwendige Sandbox-Berechtigungen behalten

2. **Info.plist erweitert**:
   - `LSApplicationCategoryType`: `public.app-category.finance` hinzugefügt
   - Erforderlich für App Store Distribution

### 📦 Build-Prozesse:
**macOS (lokal via Xcode):**
1. Product → Clean Build Folder (⇧⌘K)
2. Product → Archive
3. Distribute App → Developer ID → Upload
4. Automatische Notarisierung durch Xcode

**Windows (via GitHub Actions):**
1. Push zu GitHub
2. Automatischer Build
3. Download von Actions → Artifacts

### 🔧 Wichtige Dateien:
- `pubspec.yaml`: SDK-Constraint auf `>=3.0.0 <4.0.0` für Kompatibilität
- `macos/Runner/DebugProfile.entitlements`: Bereinigt
- `macos/Runner/Release.entitlements`: Bereinigt
- `macos/Runner/Info.plist`: App-Kategorie hinzugefügt
- `.github/workflows/build.yml`: Windows Build Workflow

### 💡 Bekannte Einschränkungen:
- **Windows Code Signing**: Ohne Certificate zeigt Windows Sicherheitswarnung
- **Workaround**: Nutzer muss "More info" → "Run anyway" klicken
- **Alternative**: GitHub als vertrauenswürdige Download-Quelle nutzen

---
*Status: 🚀 MULTI-PLATFORM RELEASE v1.8 - 2025-08-05*