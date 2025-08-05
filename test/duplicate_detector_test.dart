import 'package:flutter_test/flutter_test.dart';
import 'package:espp_manager/core/utils/duplicate_detector.dart';
import 'package:espp_manager/data/models/transaction_model.dart';

void main() {
  group('DuplicateDetector Tests', () {
    late TransactionModel baseTransaction;
    late TransactionModel duplicateTransaction;
    late TransactionModel differentTransaction;

    setUp(() {
      // Basis-Transaktion für Tests
      baseTransaction = TransactionModel(
        id: '1',
        purchaseDate: DateTime(2024, 10, 31),
        quantity: 77.693,
        fmvPerShare: 234.43,
        purchasePricePerShare: 120.04,
        incomeTaxRate: 0.42,
        capitalGainsTaxRate: 0.25,
        exchangeRateAtPurchase: 0.92,
        type: TransactionType.purchase,
        createdAt: DateTime.now(),
        lookbackFmv: 141.22,
        offeringPeriod: 'MAY/01/2023 - OCT/31/2023',
        qualifiedDispositionDate: DateTime(2025, 5, 1),
      );

      // Sehr ähnliche Transaktion (Duplikat)
      duplicateTransaction = TransactionModel(
        id: '2',
        purchaseDate: DateTime(2024, 10, 31), // Gleiches Datum
        quantity: 77.693, // Gleiche Anzahl
        fmvPerShare: 234.43, // Gleicher FMV
        purchasePricePerShare: 120.04, // Gleicher Kaufpreis
        incomeTaxRate: 0.42,
        capitalGainsTaxRate: 0.25,
        exchangeRateAtPurchase: 0.92,
        type: TransactionType.purchase, // Gleicher Typ
        createdAt: DateTime.now(),
        lookbackFmv: 141.22,
        offeringPeriod: 'MAY/01/2023 - OCT/31/2023',
        qualifiedDispositionDate: DateTime(2025, 5, 1),
      );

      // Deutlich verschiedene Transaktion
      differentTransaction = TransactionModel(
        id: '3',
        purchaseDate: DateTime(2024, 4, 30), // Anderes Datum
        quantity: 36.145, // Andere Anzahl
        fmvPerShare: 244.28,
        purchasePricePerShare: 201.10,
        incomeTaxRate: 0.42,
        capitalGainsTaxRate: 0.25,
        exchangeRateAtPurchase: 0.92,
        type: TransactionType.purchase,
        createdAt: DateTime.now(),
        lookbackFmv: 236.59,
        offeringPeriod: 'NOV/01/2024 - APR/30/2025',
        qualifiedDispositionDate: DateTime(2026, 11, 1),
      );
    });

    test('sollte Duplikate erkennen bei identischen Kern-Attributen', () {
      final existingTransactions = [baseTransaction];
      final newTransactions = [duplicateTransaction];
      
      final duplicates = DuplicateDetector.findDuplicates(existingTransactions, newTransactions);
      
      expect(duplicates, hasLength(1));
      expect(duplicates.first.similarityScore, greaterThan(0.9)); // Hohe Ähnlichkeit
      expect(duplicates.first.existingTransaction.id, equals('1'));
      expect(duplicates.first.newTransaction.id, equals('2'));
    });

    test('sollte keine Duplikate bei verschiedenen Transaktionen finden', () {
      final existingTransactions = [baseTransaction];
      final newTransactions = [differentTransaction];
      
      final duplicates = DuplicateDetector.findDuplicates(existingTransactions, newTransactions);
      
      expect(duplicates, isEmpty);
    });

    test('sollte Duplikate mit Lookback-Daten-Updates erkennen', () {
      // Basis-Transaktion ohne Lookback-Daten
      final baseWithoutLookback = TransactionModel(
        id: '1',
        purchaseDate: DateTime(2024, 10, 31),
        quantity: 77.693,
        fmvPerShare: 234.43,
        purchasePricePerShare: 120.04,
        incomeTaxRate: 0.42,
        capitalGainsTaxRate: 0.25,
        type: TransactionType.purchase,
        createdAt: DateTime.now(),
        // Kein Lookback-Daten
        lookbackFmv: null,
        offeringPeriod: null,
        qualifiedDispositionDate: null,
      );

      // Neue Transaktion mit Lookback-Daten
      final newWithLookback = TransactionModel(
        id: '2',
        purchaseDate: DateTime(2024, 10, 31), // Gleiches Datum
        quantity: 77.693, // Gleiche Anzahl
        fmvPerShare: 234.43,
        purchasePricePerShare: 120.04,
        incomeTaxRate: 0.42,
        capitalGainsTaxRate: 0.25,
        type: TransactionType.purchase, // Gleicher Typ
        createdAt: DateTime.now(),
        // Mit Lookback-Daten
        lookbackFmv: 141.22,
        offeringPeriod: 'MAY/01/2023 - OCT/31/2023',
        qualifiedDispositionDate: DateTime(2025, 5, 1),
      );

      final existingTransactions = [baseWithoutLookback];
      final newTransactions = [newWithLookback];
      
      final duplicates = DuplicateDetector.findDuplicates(existingTransactions, newTransactions);
      
      expect(duplicates, hasLength(1));
      expect(duplicates.first.differences.any((diff) => diff.contains('Lookback FMV hinzugefügt')), isTrue);
      expect(duplicates.first.differences.any((diff) => diff.contains('Angebotszeitraum')), isTrue);
    });

    test('sollte Transaktionen korrekt zusammenführen', () {
      // Basis-Transaktion ohne Lookback-Daten
      final existing = baseTransaction.copyWith(
        lookbackFmv: null,
        offeringPeriod: null,
        saleDate: null,
        salePricePerShare: null,
      );

      // Neue Transaktion mit zusätzlichen Daten
      final newTx = duplicateTransaction.copyWith(
        lookbackFmv: 141.22,
        offeringPeriod: 'MAY/01/2023 - OCT/31/2023',
        saleDate: DateTime(2024, 12, 15),
        salePricePerShare: 250.0,
      );

      final merged = DuplicateDetector.mergeTransactions(existing, newTx);

      // Überprüfe, dass alle Daten korrekt zusammengeführt wurden
      expect(merged.id, equals(existing.id)); // Ursprüngliche ID behalten
      expect(merged.createdAt, equals(existing.createdAt)); // Ursprüngliche Erstellungszeit behalten
      expect(merged.lookbackFmv, equals(141.22)); // Neue Lookback-Daten hinzugefügt
      expect(merged.offeringPeriod, equals('MAY/01/2023 - OCT/31/2023')); // Neuer Angebotszeitraum
      expect(merged.saleDate, equals(DateTime(2024, 12, 15))); // Verkaufsdatum hinzugefügt
      expect(merged.salePricePerShare, equals(250.0)); // Verkaufspreis hinzugefügt
      expect(merged.updatedAt, isNotNull); // updatedAt wurde gesetzt
    });

    test('sollte Verkaufstransaktionen NICHT als Duplikat erkennen', () {
      final purchaseTransaction = baseTransaction;
      final saleTransaction = baseTransaction.copyWith(
        id: '4',
        type: TransactionType.sale,
        saleDate: DateTime(2024, 12, 15),
        salePricePerShare: 250.0,
      );

      final existingTransactions = [purchaseTransaction];
      final newTransactions = [saleTransaction];
      
      final duplicates = DuplicateDetector.findDuplicates(existingTransactions, newTransactions);
      
      // Verkauf vs Kauf: (4 Punkte Datum + 3 Punkte Anzahl + 0 Punkte Typ + 0 Punkte Verkaufsdatum) / 10 = 70%
      // 0.7 ist NICHT > 0.7, also wird es nicht als Duplikat erkannt
      expect(duplicates, isEmpty);
    });

    test('sollte verschiedene Verkaufsdaten als Unterschied erkennen', () {
      final existingSale = baseTransaction.copyWith(
        type: TransactionType.sale,
        saleDate: DateTime(2024, 12, 15),
        salePricePerShare: 250.0,
      );

      final newSale = duplicateTransaction.copyWith(
        type: TransactionType.sale,
        saleDate: DateTime(2024, 12, 20), // Anderes Verkaufsdatum
        salePricePerShare: 255.0, // Anderer Verkaufspreis
      );

      final existingTransactions = [existingSale];
      final newTransactions = [newSale];
      
      final duplicates = DuplicateDetector.findDuplicates(existingTransactions, newTransactions);
      
      expect(duplicates, hasLength(1));
      expect(duplicates.first.differences, isNotEmpty);
      expect(duplicates.first.differences.any((diff) => diff.contains('Verkaufspreis')), isTrue);
    });

    test('sollte Wechselkurs-Updates korrekt erkennen', () {
      final existingWithDefaultRate = baseTransaction.copyWith(
        exchangeRateAtPurchase: 0.92, // Standard-Rate
      );

      final newWithActualRate = duplicateTransaction.copyWith(
        exchangeRateAtPurchase: 0.8756, // Tatsächliche Rate
      );

      final existingTransactions = [existingWithDefaultRate];
      final newTransactions = [newWithActualRate];
      
      final duplicates = DuplicateDetector.findDuplicates(existingTransactions, newTransactions);
      
      expect(duplicates, hasLength(1));
      expect(duplicates.first.differences.any((diff) => diff.contains('USD/EUR Kurs')), isTrue);
    });

    test('sollte eindeutige Transaction-Keys generieren', () {
      final key1 = DuplicateDetector.generateTransactionKey(baseTransaction);
      final key2 = DuplicateDetector.generateTransactionKey(duplicateTransaction);
      final key3 = DuplicateDetector.generateTransactionKey(differentTransaction);

      // Gleiche Transaktionen sollten gleiche Keys haben
      expect(key1, equals(key2));
      
      // Verschiedene Transaktionen sollten verschiedene Keys haben
      expect(key1, isNot(equals(key3)));
      
      // Key sollte erwartetes Format haben
      expect(key1, matches(RegExp(r'\d{4}-\d{2}-\d{2}\|\d+\.\d+\|TransactionType\.\w+')));
    });

    test('sollte Ähnlichkeits-Score korrekt berechnen', () {
      // Test mit verschiedenen Ähnlichkeitsgraden
      final transactions = [
        baseTransaction,
        duplicateTransaction, // 100% ähnlich
        baseTransaction.copyWith(quantity: 77.690), // Leicht andere Anzahl
        baseTransaction.copyWith(purchaseDate: DateTime(2024, 10, 30)), // Anderes Datum
        differentTransaction, // Komplett anders
      ];

      for (int i = 1; i < transactions.length; i++) {
        final duplicates = DuplicateDetector.findDuplicates([baseTransaction], [transactions[i]]);
        
        if (i == 1) {
          // duplicateTransaction sollte hohe Ähnlichkeit haben (100%)
          expect(duplicates, hasLength(1));
          expect(duplicates.first.similarityScore, equals(1.0));
        } else if (i == 2) {
          // Leicht andere Anzahl bekommt weniger Punkte für Quantity
          // (4 Punkte Datum + 0 Punkte Anzahl + 2 Punkte Typ + 1 Punkt kein Sale) / 10 = 70%
          // 0.7 ist NICHT > 0.7, also wird es nicht als Duplikat erkannt
          expect(duplicates, isEmpty);
        } else if (i == 3) {
          // Anderes Datum bekommt keine Punkte für Datum - unter 70% Schwellwert
          // (0 Punkte Datum + 3 Punkte Anzahl + 2 Punkte Typ + 1 Punkt kein Sale) / 10 = 60%
          expect(duplicates, isEmpty);
        } else {
          // Komplett anders sollte definitiv nicht erkannt werden
          expect(duplicates, isEmpty);
        }
      }
    });

    test('sollte mehrere Duplikate in einer Liste finden', () {
      final existingTransactions = [baseTransaction, differentTransaction];
      final newTransactions = [
        duplicateTransaction, // Duplikat von baseTransaction
        differentTransaction.copyWith(id: '5'), // Duplikat von differentTransaction
        TransactionModel( // Komplett neue Transaktion
          id: '6',
          purchaseDate: DateTime(2024, 8, 15),
          quantity: 50.0,
          fmvPerShare: 200.0,
          purchasePricePerShare: 170.0,
          incomeTaxRate: 0.42,
          capitalGainsTaxRate: 0.25,
          type: TransactionType.purchase,
          createdAt: DateTime.now(),
        ),
      ];
      
      final duplicates = DuplicateDetector.findDuplicates(existingTransactions, newTransactions);
      
      expect(duplicates, hasLength(2)); // Zwei Duplikate gefunden
      expect(duplicates.map((d) => d.existingTransaction.id).toSet(), equals({'1', '3'}));
    });
  });
}