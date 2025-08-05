import 'package:flutter_test/flutter_test.dart';
import 'package:espp_manager/core/utils/duplicate_detector.dart';
import 'package:espp_manager/data/models/transaction_model.dart';

void main() {
  group('Import Integration Tests', () {
    test('sollte CSV-Import mit anschließendem Lookback-Import simulieren', () {
      // Simuliere CSV-Import: Verkaufstransaktionen ohne Lookback-Daten
      final csvImportData = [
        TransactionModel(
          id: 'csv_1',
          purchaseDate: DateTime(2024, 10, 31),
          quantity: 77.693,
          fmvPerShare: 234.43, // Geschätzt aus kostenbasis / (1 - discount)
          purchasePricePerShare: 120.04,
          saleDate: DateTime(2024, 12, 15),
          salePricePerShare: 250.00,
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          exchangeRateAtPurchase: 0.92,
          exchangeRateAtSale: 0.91,
          type: TransactionType.sale,
          createdAt: DateTime.now(),
          // Keine Lookback-Daten
          lookbackFmv: null,
          offeringPeriod: null,
          qualifiedDispositionDate: null,
        ),
        TransactionModel(
          id: 'csv_2',
          purchaseDate: DateTime(2024, 4, 30),
          quantity: 36.145,
          fmvPerShare: 244.28,
          purchasePricePerShare: 201.10,
          saleDate: DateTime(2024, 11, 20),
          salePricePerShare: 240.00,
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          exchangeRateAtPurchase: 0.91,
          exchangeRateAtSale: 0.90,
          type: TransactionType.sale,
          createdAt: DateTime.now(),
          lookbackFmv: null,
          offeringPeriod: null,
          qualifiedDispositionDate: null,
        ),
      ];

      // Simuliere Lookback-Import: Purchase-Transaktionen mit vollständigen Lookback-Daten
      final lookbackImportData = [
        TransactionModel(
          id: 'lookback_1',
          purchaseDate: DateTime(2024, 10, 31), // Gleiches Datum wie CSV
          quantity: 77.693, // Gleiche Anzahl
          fmvPerShare: 234.43, // Korrekter FMV
          purchasePricePerShare: 120.04, // Korrekter Kaufpreis
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          exchangeRateAtPurchase: 0.92,
          type: TransactionType.purchase,
          createdAt: DateTime.now(),
          // Mit vollständigen Lookback-Daten
          lookbackFmv: 141.22,
          offeringPeriod: 'MAY/01/2023 - OCT/31/2023',
          qualifiedDispositionDate: DateTime(2025, 5, 1),
        ),
        TransactionModel(
          id: 'lookback_2',
          purchaseDate: DateTime(2024, 4, 30), // Gleiches Datum wie CSV
          quantity: 36.145, // Gleiche Anzahl
          fmvPerShare: 244.28,
          purchasePricePerShare: 201.10,
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          exchangeRateAtPurchase: 0.91,
          type: TransactionType.purchase,
          createdAt: DateTime.now(),
          // Mit vollständigen Lookback-Daten
          lookbackFmv: 236.59,
          offeringPeriod: 'NOV/01/2023 - APR/30/2024',
          qualifiedDispositionDate: DateTime(2025, 11, 1),
        ),
      ];

      // Test 1: CSV vs Lookback sollte keine Duplikate ergeben (verschiedene Typen)
      final duplicates1 = DuplicateDetector.findDuplicates(csvImportData, lookbackImportData);
      expect(duplicates1, isEmpty); // Verschiedene Transaktionstypen

      // Test 2: Simuliere Update-Szenario durch Merge einer existierenden Purchase mit neuen Lookback-Daten
      final existingPurchase = TransactionModel(
        id: 'existing_1',
        purchaseDate: DateTime(2024, 10, 31),
        quantity: 77.693,
        fmvPerShare: 234.43,
        purchasePricePerShare: 120.04,
        incomeTaxRate: 0.42,
        capitalGainsTaxRate: 0.25,
        exchangeRateAtPurchase: 0.92,
        type: TransactionType.purchase,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        // Ohne Lookback-Daten
        lookbackFmv: null,
        offeringPeriod: null,
        qualifiedDispositionDate: null,
      );

      final newLookbackData = lookbackImportData[0];
      
      final duplicates2 = DuplicateDetector.findDuplicates([existingPurchase], [newLookbackData]);
      expect(duplicates2, hasLength(1));
      
      // Test das Merge-Ergebnis
      final merged = DuplicateDetector.mergeTransactions(existingPurchase, newLookbackData);
      expect(merged.id, equals(existingPurchase.id)); // Ursprüngliche ID behalten
      expect(merged.lookbackFmv, equals(141.22)); // Lookback-Daten hinzugefügt
      expect(merged.offeringPeriod, equals('MAY/01/2023 - OCT/31/2023'));
      expect(merged.qualifiedDispositionDate, isNotNull);
      expect(merged.createdAt, equals(existingPurchase.createdAt)); // Ursprüngliche Erstellungszeit
      expect(merged.updatedAt, isNotNull); // updatedAt wurde gesetzt
    });

    test('sollte Duplikate bei wiederholtem CSV-Import erkennen', () {
      // Erste CSV-Import
      final firstImport = [
        TransactionModel(
          id: 'first_1',
          purchaseDate: DateTime(2024, 10, 31),
          quantity: 77.693,
          fmvPerShare: 234.43,
          purchasePricePerShare: 120.04,
          saleDate: DateTime(2024, 12, 15),
          salePricePerShare: 250.00,
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          type: TransactionType.sale,
          createdAt: DateTime.now(),
        ),
      ];

      // Zweite CSV-Import (gleiche Daten, andere IDs)
      final secondImport = [
        TransactionModel(
          id: 'second_1',
          purchaseDate: DateTime(2024, 10, 31), // Gleiches Datum
          quantity: 77.693, // Gleiche Anzahl
          fmvPerShare: 234.43, // Gleicher FMV
          purchasePricePerShare: 120.04, // Gleicher Kaufpreis
          saleDate: DateTime(2024, 12, 15), // Gleiches Verkaufsdatum
          salePricePerShare: 250.00, // Gleicher Verkaufspreis
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          type: TransactionType.sale, // Gleicher Typ
          createdAt: DateTime.now(),
        ),
      ];

      final duplicates = DuplicateDetector.findDuplicates(firstImport, secondImport);
      
      expect(duplicates, hasLength(1));
      expect(duplicates.first.similarityScore, equals(1.0)); // 100% identisch
      expect(duplicates.first.differences, isEmpty); // Keine Unterschiede
    });

    test('sollte verschiedene Wechselkurse als Update-würdig erkennen', () {
      // Existierende Transaktion mit Standard-Wechselkurs
      final existingWithDefaultRate = TransactionModel(
        id: 'existing_1',
        purchaseDate: DateTime(2024, 10, 31),
        quantity: 77.693,
        fmvPerShare: 234.43,
        purchasePricePerShare: 120.04,
        exchangeRateAtPurchase: 0.92, // Standard-Rate
        incomeTaxRate: 0.42,
        capitalGainsTaxRate: 0.25,
        type: TransactionType.purchase,
        createdAt: DateTime.now(),
      );

      // Neue Transaktion mit aktuellem Wechselkurs
      final newWithActualRate = TransactionModel(
        id: 'new_1',
        purchaseDate: DateTime(2024, 10, 31),
        quantity: 77.693,
        fmvPerShare: 234.43,
        purchasePricePerShare: 120.04,
        exchangeRateAtPurchase: 0.8756, // Tatsächlicher historischer Kurs
        incomeTaxRate: 0.42,
        capitalGainsTaxRate: 0.25,
        type: TransactionType.purchase,
        createdAt: DateTime.now(),
      );

      final duplicates = DuplicateDetector.findDuplicates([existingWithDefaultRate], [newWithActualRate]);
      
      expect(duplicates, hasLength(1));
      expect(duplicates.first.differences.any((diff) => diff.contains('USD/EUR Kurs')), isTrue);
      
      final merged = DuplicateDetector.mergeTransactions(existingWithDefaultRate, newWithActualRate);
      expect(merged.exchangeRateAtPurchase, equals(0.8756)); // Neuer Kurs übernommen
    });

    test('sollte Transaction-Keys für Deduplizierung verwenden können', () {
      final transactions = [
        TransactionModel(
          id: 'tx1',
          purchaseDate: DateTime(2024, 10, 31),
          quantity: 77.693,
          fmvPerShare: 234.43,
          purchasePricePerShare: 120.04,
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          type: TransactionType.purchase,
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: 'tx2', // Andere ID
          purchaseDate: DateTime(2024, 10, 31), // Aber gleiche Kern-Daten
          quantity: 77.693,
          fmvPerShare: 234.43,
          purchasePricePerShare: 120.04,
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          type: TransactionType.purchase,
          createdAt: DateTime.now(),
        ),
        TransactionModel(
          id: 'tx3',
          purchaseDate: DateTime(2024, 4, 30), // Anderes Datum
          quantity: 36.145,
          fmvPerShare: 244.28,
          purchasePricePerShare: 201.10,
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          type: TransactionType.purchase,
          createdAt: DateTime.now(),
        ),
      ];

      final keys = transactions.map(DuplicateDetector.generateTransactionKey).toList();
      
      expect(keys[0], equals(keys[1])); // Gleiche Kern-Daten = gleiche Keys
      expect(keys[0], isNot(equals(keys[2]))); // Verschiedene Daten = verschiedene Keys
      
      // Keys sollten für Set-basierte Deduplizierung verwendbar sein
      final uniqueKeys = keys.toSet();
      expect(uniqueKeys, hasLength(2)); // Nur 2 einzigartige Keys
    });
  });
}