# ESPP Manager

Eine Flutter-App zur Verwaltung von Employee Stock Purchase Plan (ESPP) Transaktionen mit automatischen Steuerberechnungen für Deutschland.

## Features

- 🔐 **Sicherer Zugang**: PIN-Authentifizierung mit AES-256 Verschlüsselung
- 📊 **Portfolio-Management**: Übersicht über alle offenen und geschlossenen Positionen
- 💰 **Steuerberechnungen**: Automatische Berechnung von Lohnsteuer und Kapitalertragsteuer
- 📈 **Lookback-Mechanismus**: Vollständige Unterstützung des ESPP Lookback-Features
- 📄 **PDF-Berichte**: Finanzamt-konforme Berichte mit EUR/USD Transparenz
- 📂 **CSV-Import**: Direkter Import von Fidelity-Daten
- 🌍 **Multi-Platform**: macOS, iOS und Windows Support

## Steuerberechnung

Die App berechnet automatisch:
- **Geldwerter Vorteil**: FMV am Kaufdatum - tatsächlicher Kaufpreis
- **Lohnsteuer**: 42% auf den geldwerten Vorteil
- **Kapitalertragsteuer**: 25% auf Kursgewinne (Verkaufspreis - FMV am Kaufdatum)

## Installation

### Voraussetzungen
- Flutter SDK (>= 3.8.1)
- Dart SDK
- Für Windows: Visual Studio mit C++ Desktop Development

### Build-Anweisungen

```bash
# Dependencies installieren
flutter pub get

# macOS Build
flutter build macos --release

# iOS Build  
flutter build ios --release

# Windows Build
flutter build windows --release
```

## Entwicklung

### Projektstruktur
```
lib/
├── core/security/          # Verschlüsselung & Auth
├── data/
│   ├── models/            # Datenmodelle
│   ├── repositories/      # Repository Pattern
│   └── datasources/       # API Services
└── presentation/
    ├── screens/           # UI Screens
    ├── widgets/           # Wiederverwendbare Komponenten
    └── providers/         # State Management (Riverpod)
```

### Key Dependencies
- `flutter_riverpod`: State Management
- `hive`: Lokale Datenspeicherung
- `encrypt`: AES-256 Verschlüsselung
- `pdf`: PDF-Generierung
- `fl_chart`: Portfolio-Charts

## Sicherheit

- Alle Daten werden lokal mit AES-256 verschlüsselt
- PIN-Schutz für App-Zugang
- Keine Cloud-Synchronisation - alle Daten bleiben auf dem Gerät

## Lizenz

Proprietär - Alle Rechte vorbehalten

## Support

Bei Fragen oder Problemen erstellen Sie bitte ein Issue auf GitHub.
