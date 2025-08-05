import '../../data/models/transaction_model.dart';

enum ImportAction {
  skip,        // Duplikat überspringen
  update,      // Bestehende Transaktion aktualisieren  
  createNew,   // Neue Transaktion erstellen (trotz Ähnlichkeit)
}

enum ImportStrategy {
  freshImport,     // Alle alten Daten löschen, komplett neu importieren
  smartUpdate,     // Duplikat-Erkennung und Updates (aktuelles Verhalten)
  incrementalOnly, // Nur neue Transaktionen hinzufügen
}

class DuplicateMatch {
  final TransactionModel existingTransaction;
  final TransactionModel newTransaction;
  final double similarityScore;
  final List<String> differences;

  DuplicateMatch({
    required this.existingTransaction,
    required this.newTransaction,
    required this.similarityScore,
    required this.differences,
  });
}

class DuplicateDetector {
  /// Findet potentielle Duplikate basierend auf Kaufdatum und Aktienanzahl
  static List<DuplicateMatch> findDuplicates(
    List<TransactionModel> existingTransactions,
    List<TransactionModel> newTransactions,
  ) {
    final duplicates = <DuplicateMatch>[];
    
    for (final newTx in newTransactions) {
      final match = _findBestMatch(existingTransactions, newTx);
      if (match != null) {
        duplicates.add(match);
      }
    }
    
    return duplicates;
  }
  
  static DuplicateMatch? _findBestMatch(
    List<TransactionModel> existingTransactions,
    TransactionModel newTransaction,
  ) {
    DuplicateMatch? bestMatch;
    double bestScore = 0.0;
    
    for (final existing in existingTransactions) {
      final score = _calculateSimilarityScore(existing, newTransaction);
      if (score > 0.7 && score > bestScore) { // 70% Ähnlichkeit als Schwellwert
        final differences = _findDifferences(existing, newTransaction);
        bestMatch = DuplicateMatch(
          existingTransaction: existing,
          newTransaction: newTransaction,
          similarityScore: score,
          differences: differences,
        );
        bestScore = score;
      }
    }
    
    return bestMatch;
  }
  
  static double _calculateSimilarityScore(
    TransactionModel existing,
    TransactionModel newTx,
  ) {
    double score = 0.0;
    int totalFactors = 0;
    
    // 1. Kaufdatum (sehr wichtig - 40% Gewichtung)
    totalFactors += 4;
    if (_isSameDate(existing.purchaseDate, newTx.purchaseDate)) {
      score += 4.0;
    }
    
    // 2. Aktienanzahl (sehr wichtig - 30% Gewichtung)  
    totalFactors += 3;
    if (_isNumberSimilar(existing.quantity, newTx.quantity, 0.001)) {
      score += 3.0;
    }
    
    // 3. Transaktionstyp (wichtig - 20% Gewichtung)
    totalFactors += 2;
    if (existing.type == newTx.type) {
      score += 2.0;
    }
    
    // 4. Verkaufsdatum (falls vorhanden - 10% Gewichtung)
    totalFactors += 1;
    if (existing.saleDate != null && newTx.saleDate != null) {
      if (_isSameDate(existing.saleDate!, newTx.saleDate!)) {
        score += 1.0;
      }
    } else if (existing.saleDate == null && newTx.saleDate == null) {
      score += 1.0; // Beide haben kein Verkaufsdatum
    }
    
    return score / totalFactors;
  }
  
  static List<String> _findDifferences(
    TransactionModel existing,
    TransactionModel newTx,
  ) {
    final differences = <String>[];
    
    // FMV Unterschiede
    if (!_isNumberSimilar(existing.fmvPerShare, newTx.fmvPerShare, 0.01)) {
      differences.add('FMV: ${existing.fmvPerShare.toStringAsFixed(2)} → ${newTx.fmvPerShare.toStringAsFixed(2)}');
    }
    
    // Kaufpreis Unterschiede
    if (!_isNumberSimilar(existing.purchasePricePerShare, newTx.purchasePricePerShare, 0.01)) {
      differences.add('Kaufpreis: ${existing.purchasePricePerShare.toStringAsFixed(2)} → ${newTx.purchasePricePerShare.toStringAsFixed(2)}');
    }
    
    // Verkaufspreis Unterschiede
    if (existing.salePricePerShare != null && newTx.salePricePerShare != null) {
      if (!_isNumberSimilar(existing.salePricePerShare!, newTx.salePricePerShare!, 0.01)) {
        differences.add('Verkaufspreis: ${existing.salePricePerShare!.toStringAsFixed(2)} → ${newTx.salePricePerShare!.toStringAsFixed(2)}');
      }
    }
    
    // Lookback FMV Unterschiede
    if (existing.lookbackFmv == null && newTx.lookbackFmv != null) {
      differences.add('Lookback FMV hinzugefügt: ${newTx.lookbackFmv!.toStringAsFixed(2)}');
    } else if (existing.lookbackFmv != null && newTx.lookbackFmv != null) {
      if (!_isNumberSimilar(existing.lookbackFmv!, newTx.lookbackFmv!, 0.01)) {
        differences.add('Lookback FMV: ${existing.lookbackFmv!.toStringAsFixed(2)} → ${newTx.lookbackFmv!.toStringAsFixed(2)}');
      }
    }
    
    // Angebotszeitraum Unterschiede
    if (existing.offeringPeriod != newTx.offeringPeriod) {
      differences.add('Angebotszeitraum: ${existing.offeringPeriod ?? 'N/A'} → ${newTx.offeringPeriod ?? 'N/A'}');
    }
    
    // Wechselkurs Unterschiede
    if (existing.exchangeRateAtPurchase != null && newTx.exchangeRateAtPurchase != null) {
      if (!_isNumberSimilar(existing.exchangeRateAtPurchase!, newTx.exchangeRateAtPurchase!, 0.001)) {
        differences.add('USD/EUR Kurs: ${existing.exchangeRateAtPurchase!.toStringAsFixed(4)} → ${newTx.exchangeRateAtPurchase!.toStringAsFixed(4)}');
      }
    }
    
    return differences;
  }
  
  static bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  static bool _isNumberSimilar(double a, double b, double tolerance) {
    return (a - b).abs() <= tolerance;
  }
  
  /// Erstellt eine aktualisierte Transaktion durch Zusammenführung der Daten
  static TransactionModel mergeTransactions(
    TransactionModel existing,
    TransactionModel newTx,
  ) {
    return existing.copyWith(
      // Behalte die ursprüngliche ID und Erstellungszeit
      // Aktualisiere nur die Felder, die in der neuen Transaktion besser/vollständiger sind
      
      // FMV aktualisieren falls neuer Wert vorhanden
      fmvPerShare: newTx.fmvPerShare != 0 ? newTx.fmvPerShare : existing.fmvPerShare,
      
      // Kaufpreis aktualisieren falls neuer Wert vorhanden  
      purchasePricePerShare: newTx.purchasePricePerShare != 0 ? newTx.purchasePricePerShare : existing.purchasePricePerShare,
      
      // Verkaufsdaten hinzufügen falls noch nicht vorhanden
      saleDate: newTx.saleDate ?? existing.saleDate,
      salePricePerShare: newTx.salePricePerShare ?? existing.salePricePerShare,
      
      // Lookback-Daten hinzufügen falls noch nicht vorhanden
      lookbackFmv: newTx.lookbackFmv ?? existing.lookbackFmv,
      offeringPeriod: newTx.offeringPeriod ?? existing.offeringPeriod,
      qualifiedDispositionDate: newTx.qualifiedDispositionDate ?? existing.qualifiedDispositionDate,
      
      // Wechselkurse aktualisieren
      exchangeRateAtPurchase: newTx.exchangeRateAtPurchase ?? existing.exchangeRateAtPurchase,
      exchangeRateAtSale: newTx.exchangeRateAtSale ?? existing.exchangeRateAtSale,
      
      // Steuersätze aktualisieren
      incomeTaxRate: newTx.incomeTaxRate,
      capitalGainsTaxRate: newTx.capitalGainsTaxRate,
      
      // Aktualisierungszeit setzen
      updatedAt: DateTime.now(),
    );
  }
  
  /// Generiert eine eindeutige Kennung für eine Transaktion basierend auf Kernattributen
  static String generateTransactionKey(TransactionModel transaction) {
    final dateKey = '${transaction.purchaseDate.year}-${transaction.purchaseDate.month.toString().padLeft(2, '0')}-${transaction.purchaseDate.day.toString().padLeft(2, '0')}';
    final quantityKey = transaction.quantity.toStringAsFixed(3);
    final typeKey = transaction.type.toString();
    
    return '$dateKey|$quantityKey|$typeKey';
  }
}