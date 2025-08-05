# ESPP Lookback-Daten Implementation

## ✅ Implementierte Features

### 1. **Erweitertes TransactionModel**
- Neue Felder für Lookback-Daten:
  - `lookbackFmv`: FMV am Anfang des Angebotszeitraums
  - `offeringPeriod`: Angebotszeitraum (z.B. "MAY/01/2023 - OCT/31/2023")
  - `qualifiedDispositionDate`: Qualifizierter Verkaufszeitpunkt (2 Jahre nach Kauf)
- Angepasste Discount-Berechnung mit Lookback-Preis

### 2. **Lookback Parser**
- Parst Fidelity Lookback-Daten aus Copy-Paste Text
- Unterstützt Format: `MAY/01/2023 - OCT/31/2023    OCT/31/2023    $234.43 USD    $141.22 USD    $120.04 USD    77.693 shares    $9,326.06 USD    MAY/01/2025    Maklerkonto`
- Validierung der geparsten Daten

### 3. **Import Lookback Screen**
- **Option A**: Copy-Paste Import aus Fidelity Portal
- **Option C**: Manuelle Eingabemaske für einzelne Einträge
- Preview der importierten Daten vor dem Speichern
- Deutsche Zahlenformate werden automatisch konvertiert

### 4. **Transaction Matcher**
- Verknüpft Verkaufstransaktionen mit Kauftransaktionen über das Erwerbsdatum
- Aktualisiert Verkäufe mit Lookback-Daten aus passenden Käufen
- Berechnet korrekte Steuern nach deutschem Recht

### 5. **Steuerberechnung nach deutschem Recht**
```
Lohnsteuerpflichtiger Vorteil (bereits versteuert):
(fmvAtPurchase - actualPrice) × soldShares

Kapitalertragsteuerpflichtiger Gewinn bei Verkauf:
proceeds - (fmvAtPurchase × soldShares)
```

## 📋 Verwendung

### Import von Lookback-Daten:
1. Navigiere zu "Import" → "Lookback-Daten importieren"
2. Kopiere die Tabelle aus dem Fidelity Portal
3. Füge sie in das Textfeld ein und klicke "Daten parsen"
4. Überprüfe die Vorschau und klicke "Importieren"

### Manuelle Eingabe:
1. Klicke auf "Option C: Manuelle Eingabe"
2. Fülle alle Felder aus
3. Klicke "Manuellen Eintrag hinzufügen"

### Verkaufsdaten-Import:
- CSV-Import von Verkäufen wird automatisch mit vorhandenen Lookback-Daten verknüpft
- Matching erfolgt über das Erwerbsdatum (acquisition_date)

## 🔧 Technische Details

### Neue Dateien:
- `/lib/core/utils/lookback_parser.dart` - Parser für Fidelity Daten
- `/lib/core/utils/transaction_matcher.dart` - Verknüpfung von Kauf/Verkauf
- `/lib/presentation/screens/import_lookback_screen.dart` - Import UI
- `/lib/presentation/widgets/flexible_bottom_action_bar.dart` - Flexible Action Bar

### Geänderte Dateien:
- `transaction_model.dart` - Erweitert um Lookback-Felder
- `transactions_provider.dart` - Automatisches Matching bei neuen Transaktionen
- `import_screen.dart` - Link zu Lookback Import
- `main.dart` - Neue Route für Lookback Import

## ⚠️ Wichtige Hinweise

- Lookback-Daten sollten VOR dem Import von Verkaufsdaten importiert werden
- Die Verknüpfung erfolgt automatisch über das Erwerbsdatum
- Bei nicht eindeutigen Daten wird das nächstgelegene Datum (±7 Tage) verwendet
- Alle Berechnungen erfolgen nach deutschem Steuerrecht

## 🚀 Nächste Schritte

- [ ] Export der Lookback-Daten in Berichte
- [ ] Visualisierung der Lookback-Rabatte
- [ ] Batch-Import für mehrere Perioden
- [ ] Automatische Erkennung des Angebotszeitraums