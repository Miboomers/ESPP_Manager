import '../../data/models/transaction_model.dart';

enum ImportStrategy {
  freshImport,      // Alles löschen, neu importieren
  smartMerge,       // Intelligente Zusammenführung mit Teilverkäufen
  incrementalOnly,  // Nur wirklich neue Transaktionen
}

class TransactionGroup {
  final DateTime purchaseDate;
  final double originalQuantity;
  final List<TransactionModel> purchases;
  final List<TransactionModel> sales;
  final TransactionModel? lookbackData;

  TransactionGroup({
    required this.purchaseDate,
    required this.originalQuantity,
    required this.purchases,
    required this.sales,
    this.lookbackData,
  });

  double get totalSoldQuantity => sales.fold(0.0, (sum, sale) => sum + sale.quantity);
  double get remainingQuantity => originalQuantity - totalSoldQuantity;
  bool get isFullySold => remainingQuantity <= 0.001; // Toleranz für Rundungsfehler
}

class SmartTransactionMatcher {
  /// Gruppiert Transaktionen nach Kaufdatum und erkennt Teilverkäufe
  static List<TransactionGroup> groupTransactions(
    List<TransactionModel> allTransactions,
  ) {
    final groups = <DateTime, TransactionGroup>{};
    
    // Gruppe alle Transaktionen nach Kaufdatum
    for (final tx in allTransactions) {
      final dateKey = DateTime(tx.purchaseDate.year, tx.purchaseDate.month, tx.purchaseDate.day);
      
      if (!groups.containsKey(dateKey)) {
        groups[dateKey] = TransactionGroup(
          purchaseDate: dateKey,
          originalQuantity: 0.0,
          purchases: [],
          sales: [],
        );
      }
      
      final group = groups[dateKey]!;
      if (tx.type == TransactionType.purchase) {
        group.purchases.add(tx);
        // Aktualisiere Original-Quantity falls größer
        if (tx.quantity > group.originalQuantity) {
          groups[dateKey] = TransactionGroup(
            purchaseDate: group.purchaseDate,
            originalQuantity: tx.quantity,
            purchases: group.purchases,
            sales: group.sales,
            lookbackData: group.lookbackData,
          );
        }
      } else {
        group.sales.add(tx);
      }
    }
    
    return groups.values.toList();
  }
  
  /// Erkennt ob eine neue Transaktion zu einer bestehenden Gruppe gehört
  static TransactionGroup? findMatchingGroup(
    List<TransactionGroup> existingGroups,
    TransactionModel newTransaction,
  ) {
    final newDate = DateTime(
      newTransaction.purchaseDate.year,
      newTransaction.purchaseDate.month,
      newTransaction.purchaseDate.day,
    );
    
    // Suche exakte Datum-Übereinstimmung
    for (final group in existingGroups) {
      if (_isSameDate(group.purchaseDate, newDate)) {
        // Prüfe ob Quantity-wise sinnvoll
        if (newTransaction.type == TransactionType.sale) {
          // Verkauf: Prüfe ob noch genug Aktien vorhanden
          final availableQuantity = group.remainingQuantity;
          if (newTransaction.quantity <= availableQuantity + 0.001) { // Mit Toleranz
            return group;
          }
        } else {
          // Kauf: Prüfe ob es der Original-Kauf oder Lookback-Daten sind
          if (_isNumberSimilar(newTransaction.quantity, group.originalQuantity, 0.001) ||
              newTransaction.quantity > group.originalQuantity) {
            return group;
          }
        }
      }
    }
    
    return null;
  }
  
  /// Führt Lookback-Daten mit bestehenden Transaktionen zusammen
  static List<TransactionModel> mergeLookbackData(
    List<TransactionModel> existingTransactions,
    List<TransactionModel> lookbackTransactions,
  ) {
    final groups = groupTransactions(existingTransactions);
    final updatedTransactions = <TransactionModel>[];
    final processedLookback = <String>{};
    
    for (final group in groups) {
      // Suche passende Lookback-Daten
      TransactionModel? matchingLookback;
      for (final lookback in lookbackTransactions) {
        if (!processedLookback.contains(lookback.id) &&
            _isSameDate(group.purchaseDate, lookback.purchaseDate) &&
            _isNumberSimilar(group.originalQuantity, lookback.quantity, 0.001)) {
          matchingLookback = lookback;
          processedLookback.add(lookback.id);
          break;
        }
      }
      
      // Aktualisiere alle Transaktionen in der Gruppe mit Lookback-Daten
      for (final purchase in group.purchases) {
        TransactionModel updated = purchase;
        if (matchingLookback != null) {
          updated = purchase.copyWith(
            lookbackFmv: matchingLookback.lookbackFmv,
            offeringPeriod: matchingLookback.offeringPeriod,
            qualifiedDispositionDate: matchingLookback.qualifiedDispositionDate,
            updatedAt: DateTime.now(),
          );
        }
        updatedTransactions.add(updated);
      }
      
      // Füge alle Verkäufe hinzu (auch mit Lookback-Daten wenn vorhanden)
      for (final sale in group.sales) {
        TransactionModel updated = sale;
        if (matchingLookback != null) {
          updated = sale.copyWith(
            lookbackFmv: matchingLookback.lookbackFmv,
            offeringPeriod: matchingLookback.offeringPeriod,
            qualifiedDispositionDate: matchingLookback.qualifiedDispositionDate,
            updatedAt: DateTime.now(),
          );
        }
        updatedTransactions.add(updated);
      }
    }
    
    // Füge nicht-zugeordnete Lookback-Daten als neue Käufe hinzu
    for (final lookback in lookbackTransactions) {
      if (!processedLookback.contains(lookback.id)) {
        updatedTransactions.add(lookback);
      }
    }
    
    return updatedTransactions;
  }
  
  /// Intelligenter Import mit verschiedenen Strategien
  static ImportResult performSmartImport(
    List<TransactionModel> existingTransactions,
    List<TransactionModel> newTransactions,
    ImportStrategy strategy,
  ) {
    switch (strategy) {
      case ImportStrategy.freshImport:
        return ImportResult(
          finalTransactions: newTransactions,
          importedCount: newTransactions.length,
          updatedCount: 0,
          skippedCount: 0,
          strategy: strategy,
        );
        
      case ImportStrategy.smartMerge:
        // Aktuelle Implementierung mit Duplikat-Erkennung
        return _performSmartMerge(existingTransactions, newTransactions);
        
      case ImportStrategy.incrementalOnly:
        // Nur wirklich neue Transaktionen (keine Duplikate basierend auf Transaction-Key)
        return _performIncrementalImport(existingTransactions, newTransactions);
    }
  }
  
  static ImportResult _performSmartMerge(
    List<TransactionModel> existing,
    List<TransactionModel> newTx,
  ) {
    // Hier würde die aktuelle DuplicateDetector-Logik verwendet
    // Implementierung folgt...
    return ImportResult(
      finalTransactions: [...existing, ...newTx], // Vereinfacht
      importedCount: newTx.length,
      updatedCount: 0,
      skippedCount: 0,
      strategy: ImportStrategy.smartMerge,
    );
  }
  
  static ImportResult _performIncrementalImport(
    List<TransactionModel> existing,
    List<TransactionModel> newTx,
  ) {
    final existingKeys = existing.map((t) => _generateTransactionKey(t)).toSet();
    final newTransactions = newTx.where((t) => !existingKeys.contains(_generateTransactionKey(t))).toList();
    
    return ImportResult(
      finalTransactions: [...existing, ...newTransactions],
      importedCount: newTransactions.length,
      updatedCount: 0,
      skippedCount: newTx.length - newTransactions.length,
      strategy: ImportStrategy.incrementalOnly,
    );
  }
  
  // Helper methods
  static bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  static bool _isNumberSimilar(double a, double b, double tolerance) {
    return (a - b).abs() <= tolerance;
  }
  
  static String _generateTransactionKey(TransactionModel transaction) {
    final dateKey = '${transaction.purchaseDate.year}-${transaction.purchaseDate.month.toString().padLeft(2, '0')}-${transaction.purchaseDate.day.toString().padLeft(2, '0')}';
    final quantityKey = transaction.quantity.toStringAsFixed(3);
    final typeKey = transaction.type.toString();
    final saleKey = transaction.saleDate != null ? 
        '${transaction.saleDate!.year}-${transaction.saleDate!.month.toString().padLeft(2, '0')}-${transaction.saleDate!.day.toString().padLeft(2, '0')}' : 
        'null';
    
    return '$dateKey|$quantityKey|$typeKey|$saleKey';
  }
}

class ImportResult {
  final List<TransactionModel> finalTransactions;
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final ImportStrategy strategy;

  ImportResult({
    required this.finalTransactions,
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.strategy,
  });
}