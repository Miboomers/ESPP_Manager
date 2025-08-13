import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../../core/services/file_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_price_provider.dart';
import '../../data/datasources/exchange_rate_api.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _isImporting = false;
  String _status = '';
  final List<String> _logs = [];
  List<dynamic> _selectedFiles = []; // Can be File or PlatformFile
  // bool _isClosedPositions = true; // Nicht mehr benötigt - automatische Erkennung
  
  // Statistiken
  int _totalTransactions = 0;
  int _importedTransactions = 0;
  // int _skippedTransactions = 0; // Nicht mehr verwendet
  int _errorTransactions = 0;
  
  // ID Counter für eindeutige IDs
  int _idCounter = 0;

  // Automatische Erkennung des CSV-Typs anhand der Header-Struktur
  bool _detectCsvType(List<String> headers) {
    if (headers.length < 5) {
      _logs.add('⚠️ Zu wenige Spalten für automatische Erkennung');
      return true; // Default: Geschlossene Positionen
    }
    
    // Entferne HTML-Tags und normalisiere Header
    final cleanHeaders = headers.map((h) => 
      h.replaceAll(RegExp(r'<[^>]*>'), '') // HTML-Tags entfernen
       .toLowerCase()
       .trim()
    ).toList();
    
    _logs.add('🔍 Bereinigte Header: ${cleanHeaders.take(5).join(", ")}...');
    
    // Spalte 3 ist der entscheidende Unterschied:
    // Geschlossene: "verkaufsdatum" | "date sold or transferred"
    // Offene: "kostenbasis" | "cost basis"
    final column3 = cleanHeaders.length > 2 ? cleanHeaders[2] : '';
    
    // Spalte 4 als zusätzliche Bestätigung:
    // Geschlossene: "erlöse" | "proceeds" 
    // Offene: "kostenbasis/anteil" | "cost basis/share"
    final column4 = cleanHeaders.length > 3 ? cleanHeaders[3] : '';
    
    // Erkenne geschlossene Positionen
    final isClosedByColumn3 = column3.contains('verkaufsdatum') || 
                             column3.contains('date sold') || 
                             column3.contains('sold');
    
    final isClosedByColumn4 = column4.contains('erlöse') || 
                             column4.contains('proceeds');
    
    // Erkenne offene Positionen  
    final isOpenByColumn3 = column3.contains('kostenbasis') || 
                           column3.contains('cost basis');
    
    final isOpenByColumn4 = column4.contains('kostenbasis/anteil') || 
                           column4.contains('cost basis/share') ||
                           column4.contains('basis/share');
    
    if (isClosedByColumn3 || isClosedByColumn4) {
      _logs.add('✅ Erkannt als: Geschlossene Positionen (Verkäufe)');
      _logs.add('   → Spalte 3: "$column3"');
      _logs.add('   → Spalte 4: "$column4"');
      return true;
    } else if (isOpenByColumn3 || isOpenByColumn4) {
      _logs.add('✅ Erkannt als: Offene Positionen (Käufe)');
      _logs.add('   → Spalte 3: "$column3"');
      _logs.add('   → Spalte 4: "$column4"');
      return false;
    } else {
      _logs.add('⚠️ CSV-Typ konnte nicht eindeutig erkannt werden');
      _logs.add('   → Spalte 3: "$column3"');
      _logs.add('   → Spalte 4: "$column4"');
      _logs.add('   → Verwende Standard: Geschlossene Positionen');
      return true; // Fallback
    }
  }

  Future<void> _selectFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: true,
        withData: true, // Important for web
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          if (kIsWeb) {
            // On Web, work with PlatformFile directly
            _selectedFiles = result.files.cast<dynamic>();
          } else {
            // On Desktop/Mobile, convert to File objects
            _selectedFiles = result.files
                .where((file) => file.path != null)
                .map((file) => File(file.path!))
                .cast<dynamic>()
                .toList();
          }
          
          if (_selectedFiles.length == 1) {
            _status = 'Datei ausgewählt: ${FileService.getFileName(_selectedFiles.first)}';
          } else {
            _status = '${_selectedFiles.length} Dateien ausgewählt';
          }
          _logs.clear();
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Fehler beim Dateiauswahl: $e';
      });
    }
  }

  Future<void> _importData() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wählen Sie zuerst eine oder mehrere CSV-Dateien aus')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _status = 'Importiere Daten...';
      _logs.clear();
      _totalTransactions = 0;
      _importedTransactions = 0;
      // _skippedTransactions = 0; // Nicht mehr verwendet
      _errorTransactions = 0;
      _idCounter = DateTime.now().millisecondsSinceEpoch; // Basis für eindeutige IDs
    });

    // WICHTIG: Alle API Providers invalidieren um Rate Limits zu vermeiden
    ref.invalidate(stockPriceProvider);
    _logs.add('🔄 API Provider pausiert für Import...');

    try {
      // Sammle alle Transaktionen von allen Dateien nach Typ
      final Map<bool, List<TransactionModel>> transactionsByType = {
        true: [], // Geschlossene Positionen
        false: [], // Offene Positionen
      };
      
      // Get settings for tax rates
      final settings = await ref.read(settingsProvider.future);
      
      // Verarbeite jede ausgewählte Datei
      for (final file in _selectedFiles) {
        _logs.add('');
        _logs.add('📄 Verarbeite Datei: ${FileService.getFileName(file)}');
        
        final input = await FileService.readFileAsString(file);
        
        // Remove BOM if present
        final cleanInput = input.startsWith('\ufeff') ? input.substring(1) : input;
        
        // Parse CSV
        final List<List<dynamic>> rows = const CsvToListConverter().convert(cleanInput);
        
        if (rows.isEmpty) {
          _logs.add('⚠️ Die CSV-Datei ist leer, überspringe...');
          continue;
        }

        // Get headers
        final headers = rows[0].map((e) => e.toString().trim()).toList();
        _logs.add('Headers: ${headers.take(3).join(", ")}...');

        // Automatische CSV-Typ Erkennung
        final detectedIsClosedPositions = _detectCsvType(headers);
        _logs.add('');
        
        // Process data rows
        int fileTransactions = 0;
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          
          // Skip empty rows
          if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
            continue;
          }
          
          _totalTransactions++;
          fileTransactions++;
          
          try {
            TransactionModel transaction;
            // Verwende automatische Erkennung
            if (detectedIsClosedPositions) {
              transaction = _createClosedPositionTransaction(row, headers, settings);
            } else {
              transaction = _createOpenPositionTransaction(row, headers, settings);
            }
            
            transactionsByType[detectedIsClosedPositions]!.add(transaction);
            _importedTransactions++;
            
            // Update UI alle 10 Transaktionen
            if (_importedTransactions % 10 == 0) {
              setState(() {});
            }
          } catch (e) {
            _errorTransactions++;
            _logs.add('❌ Fehler in Zeile ${i + 1}: $e');
          }
        }
        
        _logs.add('✅ $fileTransactions Transaktionen aus dieser Datei vorbereitet');
      }
      
      // Jetzt importiere alle gesammelten Transaktionen
      await _importCollectedTransactions(transactionsByType);

      // 🔄 Cloud-Synchronisierung nach erfolgreichem Import (nur wenn aktiviert)
      bool isCloudSyncEnabled = false;
      if (_importedTransactions > 0) {
        try {
          final cloudService = ref.read(cloudSyncServiceProvider);
          
          // Prüfe ob Cloud-Sync aktiviert ist
          final syncStatus = await cloudService.syncStatusStream.first;
          isCloudSyncEnabled = syncStatus.state != SyncState.idle;
          
          if (isCloudSyncEnabled) {
            _logs.add('');
            _logs.add('☁️ Cloud-Sync ist aktiviert - starte automatische Synchronisierung...');
            setState(() {});
            
            // 🔄 Direkte Cloud-Synchronisierung der neuen Transaktionen
            try {
              final allNewTransactions = transactionsByType.values.expand((list) => list).toList();
              
              // Lade alle neuen Transaktionen direkt in die Cloud
              for (final transaction in allNewTransactions) {
                await cloudService.syncTransaction(transaction);
                _logs.add('   → Transaktion ${transaction.id} in Cloud hochgeladen');
              }
              
              // Lade alle ausstehenden Änderungen
              await cloudService.syncPendingChanges();
              
              _logs.add('✅ Cloud-Synchronisierung erfolgreich abgeschlossen!');
              _logs.add('   → ${allNewTransactions.length} Transaktionen direkt in die Cloud übertragen');
              
            } catch (e) {
              _logs.add('❌ Fehler bei Cloud-Synchronisierung: $e');
              _logs.add('   → Versuche alternative Sync-Methode...');
              
              // Alternative: Warte kurz und versuche es nochmal
              await Future.delayed(const Duration(seconds: 2));
              await cloudService.syncPendingChanges();
              _logs.add('✅ Alternative Sync-Methode abgeschlossen');
            }
          } else {
            _logs.add('');
            _logs.add('ℹ️ Cloud-Sync ist nicht aktiviert - überspringe Synchronisierung');
            _logs.add('   → Daten wurden nur lokal gespeichert');
          }
        } catch (e) {
          _logs.add('');
          _logs.add('⚠️ Cloud-Sync-Status konnte nicht ermittelt werden: $e');
          _logs.add('   → Daten wurden lokal gespeichert, aber nicht mit der Cloud synchronisiert');
        }
      }

      // WICHTIG: Import-Status zurücksetzen und Zusammenfassung anzeigen
      if (mounted) {
        setState(() {
          _status = 'Import abgeschlossen!';
          _logs.add('');
          _logs.add('=== ZUSAMMENFASSUNG ===');
          _logs.add('Dateien verarbeitet: $_selectedFiles.length');
          _logs.add('Gesamt: $_totalTransactions Transaktionen');
          _logs.add('Importiert: $_importedTransactions');
          _logs.add('Fehler: $_errorTransactions');
          if (_importedTransactions > 0) {
            _logs.add('☁️ Cloud-Sync: ${isCloudSyncEnabled ? 'Erfolgreich' : 'Nicht aktiviert'}');
          }
          _isImporting = false; // WICHTIG: Spinner stoppen!
        });
        
        // Zusätzliche Sicherheit: State explizit aktualisieren
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
      }

      // Snackbar anzeigen
      if (_importedTransactions > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_importedTransactions Transaktionen erfolgreich importiert!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Cloud-Sync-Status zurücksetzen
      if (mounted) {
        ref.invalidate(cloudSyncServiceProvider);
      }
    } catch (e) {
      setState(() {
        _status = 'Import fehlgeschlagen: $e';
        _isImporting = false;
      });
    }
  }

  Future<void> _importCollectedTransactions(Map<bool, List<TransactionModel>> transactionsByType) async {
    final existingTransactions = await ref.read(transactionsProvider.future);
    final transactionsNotifier = ref.read(transactionsProvider.notifier);
    
    // Berechne was gelöscht werden muss
    final existingPurchases = existingTransactions.where((t) => t.type == TransactionType.purchase).length;
    final existingSales = existingTransactions.where((t) => t.type == TransactionType.sale).length;
    
    final hasClosedPositions = transactionsByType[true]!.isNotEmpty;
    final hasOpenPositions = transactionsByType[false]!.isNotEmpty;
    
    // Zeige Warnung wenn nötig
    if (existingTransactions.isNotEmpty && (hasClosedPositions || hasOpenPositions)) {
      final shouldProceed = await _showSmartImportWarning(
        existingPurchases: existingPurchases,
        existingSales: existingSales,
        newClosedPositions: transactionsByType[true]!.length,
        newOpenPositions: transactionsByType[false]!.length,
      );
      
      if (!shouldProceed) {
        setState(() {
          _status = 'Import abgebrochen';
          _isImporting = false;
        });
        return;
      }
    }
    
    // Führe Import durch
    _logs.add('');
    _logs.add('🗑️ Bereite Datenbank vor...');
    setState(() {});
    
    // Wenn geschlossene Positionen importiert werden, lösche ALLE alten Daten
    if (hasClosedPositions) {
      _logs.add('→ Lösche alle bestehenden Transaktionen (${existingTransactions.length})...');
      for (final tx in existingTransactions) {
        await transactionsNotifier.deleteTransaction(tx.id);
      }
    } else if (hasOpenPositions) {
      // Nur offene Positionen: Lösche nur alte Käufe
      final purchases = existingTransactions.where((t) => t.type == TransactionType.purchase).toList();
      _logs.add('→ Lösche nur offene Positionen (${purchases.length} Käufe)...');
      _logs.add('→ Behalte $existingSales Verkäufe');
      for (final purchase in purchases) {
        await transactionsNotifier.deleteTransaction(purchase.id);
      }
    }
    
    // Importiere neue Transaktionen
    _logs.add('');
    _logs.add('💾 Importiere neue Transaktionen...');
    setState(() {});
    
    // Geschlossene Positionen
    if (hasClosedPositions) {
      _logs.add('→ Importiere ${transactionsByType[true]!.length} geschlossene Positionen...');
      final enrichedClosed = await _enrichWithHistoricalRates(transactionsByType[true]!);
      for (final transaction in enrichedClosed) {
        await transactionsNotifier.addTransaction(transaction);
      }
    }
    
    // Offene Positionen
    if (hasOpenPositions) {
      _logs.add('→ Importiere ${transactionsByType[false]!.length} offene Positionen...');
      final enrichedOpen = await _enrichWithHistoricalRates(transactionsByType[false]!);
      for (final transaction in enrichedOpen) {
        await transactionsNotifier.addTransaction(transaction);
      }
    }
  }

  Future<bool> _showSmartImportWarning({
    required int existingPurchases,
    required int existingSales,
    required int newClosedPositions,
    required int newOpenPositions,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Import Bestätigung'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Die App hat automatisch erkannt:'),
                const SizedBox(height: 8),
                if (newClosedPositions > 0)
                  Text('• $newClosedPositions geschlossene Positionen (Verkäufe)'),
                if (newOpenPositions > 0)
                  Text('• $newOpenPositions offene Positionen (Käufe)'),
                const SizedBox(height: 16),
                const Text('Aktuelle Daten in der App:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('• $existingPurchases offene Positionen'),
                Text('• $existingSales geschlossene Positionen'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ WICHTIG:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (newClosedPositions > 0)
                        const Text('• Geschlossene Positionen ersetzen ALLE Daten!'),
                      if (newOpenPositions > 0 && newClosedPositions == 0)
                        const Text('• Nur offene Positionen werden ersetzt, Verkäufe bleiben erhalten.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Möchten Sie fortfahren?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Import durchführen'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  TransactionModel _createClosedPositionTransaction(List<dynamic> row, List<String> headers, dynamic settings) {
    // Expected format: Datum des Erwerbs,Anzahl,Verkaufsdatum,Erlöse,Kostenbasis,Gewinn/Verlust,Bezeichnung
    
    if (row.length < 6) {
      throw Exception('Unvollständige Zeile');
    }

    // Parse purchase date (acquisition date)
    final purchaseDateStr = row[0].toString().trim();
    final purchaseDate = _parseFidelityDate(purchaseDateStr);
    
    // Parse quantity
    final quantity = double.parse(row[1].toString().replaceAll(',', '.'));
    
    // Parse sale date
    final saleDateStr = row[2].toString().trim();
    final saleDate = _parseFidelityDate(saleDateStr);
    
    // Parse amounts
    final proceeds = double.parse(row[3].toString().replaceAll(',', '.'));
    final costBasis = double.parse(row[4].toString().replaceAll(',', '.'));
    
    // Calculate prices
    final purchasePricePerShare = costBasis / quantity;
    final salePricePerShare = proceeds / quantity;
    
    // For ESPP, we need to estimate FMV (typically 15% higher than purchase price)
    // This will be corrected when we match with lookback data
    final fmvPerShare = purchasePricePerShare / (1 - settings.defaultEsppDiscountRate);
    
    // Create sale transaction mit eindeutiger ID
    // Note: lookbackFmv will be populated when matched with lookback data
    return TransactionModel(
      id: (++_idCounter).toString(),
      purchaseDate: purchaseDate, // This is the acquisition_date from CSV
      quantity: quantity,
      purchasePricePerShare: purchasePricePerShare,
      fmvPerShare: fmvPerShare,
      type: TransactionType.sale,
      saleDate: saleDate,
      salePricePerShare: salePricePerShare,
      exchangeRateAtPurchase: 0.92, // Default EUR/USD rate
      exchangeRateAtSale: 0.92,
      incomeTaxRate: settings.defaultIncomeTaxRate,
      capitalGainsTaxRate: settings.defaultCapitalGainsTaxRate,
      createdAt: DateTime.now(),
      lookbackFmv: null, // Will be populated from lookback data
    );
  }

  TransactionModel _createOpenPositionTransaction(List<dynamic> row, List<String> headers, dynamic settings) {
    // Expected format: Datum des Erwerbs,Anzahl,Kostenbasis,Kostenbasis/Anteil,Wert,Gewinn/Verlust,...
    
    if (row.length < 4) {
      throw Exception('Unvollständige Zeile');
    }

    // Parse purchase date
    final purchaseDateStr = row[0].toString().trim();
    final purchaseDate = _parseFidelityDate(purchaseDateStr);
    
    // Parse quantity
    final quantity = double.parse(row[1].toString().replaceAll(',', '.'));
    
    // Parse cost basis per share
    final costBasisPerShare = double.parse(row[3].toString().replaceAll(',', '.'));
    
    // For ESPP, we need to estimate FMV (typically 15% higher than purchase price)
    final fmvPerShare = costBasisPerShare / (1 - settings.defaultEsppDiscountRate);
    
    // Create purchase transaction mit eindeutiger ID
    return TransactionModel(
      id: (++_idCounter).toString(),
      purchaseDate: purchaseDate,
      quantity: quantity,
      purchasePricePerShare: costBasisPerShare,
      fmvPerShare: fmvPerShare,
      type: TransactionType.purchase,
      exchangeRateAtPurchase: 0.92, // Default EUR/USD rate
      incomeTaxRate: settings.defaultIncomeTaxRate,
      capitalGainsTaxRate: settings.defaultCapitalGainsTaxRate,
      createdAt: DateTime.now(),
    );
  }

  DateTime _parseFidelityDate(String dateStr) {
    // Fidelity formats: "OCT/31/2024" or "Apr-30-2025"
    
    // Try format 1: MON/DD/YYYY
    final format1 = RegExp(r'([A-Z]+)/(\d+)/(\d+)');
    final match1 = format1.firstMatch(dateStr.toUpperCase());
    if (match1 != null) {
      final month = _monthNameToNumber(match1.group(1)!);
      final day = int.parse(match1.group(2)!);
      final year = int.parse(match1.group(3)!);
      return DateTime(year, month, day);
    }
    
    // Try format 2: Mon-DD-YYYY
    final format2 = RegExp(r'([A-Za-z]+)-(\d+)-(\d+)');
    final match2 = format2.firstMatch(dateStr);
    if (match2 != null) {
      final month = _monthNameToNumber(match2.group(1)!.toUpperCase());
      final day = int.parse(match2.group(2)!);
      final year = int.parse(match2.group(3)!);
      return DateTime(year, month, day);
    }
    
    throw Exception('Unbekanntes Datumsformat: $dateStr');
  }

  int _monthNameToNumber(String monthName) {
    final months = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
      'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
      'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
    };
    
    final month = months[monthName.substring(0, 3).toUpperCase()];
    if (month == null) {
      throw Exception('Unbekannter Monat: $monthName');
    }
    return month;
  }

  /// Reichert Transaktionen mit historischen Wechselkursen an
  Future<List<TransactionModel>> _enrichWithHistoricalRates(List<TransactionModel> transactions) async {
    try {
      final transactionsWithStandardRates = transactions.where((t) => 
        t.exchangeRateAtPurchase == 0.92 || 
        (t.exchangeRateAtSale != null && t.exchangeRateAtSale == 0.92)
      ).toList();
      
      if (transactionsWithStandardRates.isEmpty) {
        _logs.add('✓ Alle Transaktionen haben bereits korrekte Wechselkurse');
        return transactions;
      }
      
      _logs.add('📅 Lade Kurse für ${transactionsWithStandardRates.length} Transaktionen...');
      setState(() {});
      
      final updatedTransactions = <TransactionModel>[];
      
      for (final transaction in transactions) {
        TransactionModel updated = transaction;
        
        // Kaufkurs aktualisieren falls Standard-Kurs
        if (transaction.exchangeRateAtPurchase == 0.92) {
          final historicalRate = await ExchangeRateService.getHistoricalRate(
            date: transaction.purchaseDate,
          );
          updated = updated.copyWith(exchangeRateAtPurchase: historicalRate);
        }
        
        // Verkaufskurs aktualisieren falls vorhanden und Standard-Kurs
        if (transaction.saleDate != null && 
            transaction.exchangeRateAtSale != null && 
            transaction.exchangeRateAtSale == 0.92) {
          final historicalSaleRate = await ExchangeRateService.getHistoricalRate(
            date: transaction.saleDate!,
          );
          updated = updated.copyWith(exchangeRateAtSale: historicalSaleRate);
        }
        
        updatedTransactions.add(updated);
      }
      
      final updatedCount = updatedTransactions.where((t) => 
        t.exchangeRateAtPurchase != 0.92 || 
        (t.exchangeRateAtSale != null && t.exchangeRateAtSale != 0.92)
      ).length;
      
      _logs.add('✅ $updatedCount Wechselkurse aktualisiert');
      return updatedTransactions;
      
    } catch (e) {
      _logs.add('⚠️ Fehler beim Laden der Wechselkurse: $e');
      _logs.add('→ Verwende Standard-Wechselkurse');
      return transactions;
    }
  }

  // Diese Methode wurde durch _showSmartImportWarning ersetzt
  // Future<bool> _showImportWarning(String importType, int existingCount, int newCount) async { ... }

  // Diese Methode wurde durch _importCollectedTransactions ersetzt
  // Future<void> _executeImportStrategy(...) async { ... }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fidelity CSV Import'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fidelity ESPP Daten importieren',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Die App erkennt automatisch anhand der CSV-Struktur, ob es sich um geschlossene oder offene Positionen handelt. Unterstützt deutsche und englische Fidelity-Exporte.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _selectedFiles.isNotEmpty ? Icons.check_circle : Icons.upload_file,
                      size: 48,
                      color: _selectedFiles.isNotEmpty ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFiles.isEmpty
                          ? 'Keine Dateien ausgewählt'
                          : _selectedFiles.length == 1
                              ? 'Datei: ${FileService.getFileName(_selectedFiles.first)}'
                              : '${_selectedFiles.length} Dateien ausgewählt',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFiles.length > 1) ...[
                      const SizedBox(height: 8),
                      ...(_selectedFiles.map((file) => Text(
                        '• ${FileService.getFileName(file)}',
                        style: const TextStyle(fontSize: 12),
                      ))),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isImporting ? null : _selectFiles,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('CSV-Datei(en) auswählen'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isImporting || _selectedFiles.isEmpty ? null : _importData,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isImporting ? 'Importiere...' : 'Import starten'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            // Button für Lookback-Daten Import
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/import-lookback');
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lookback-Daten importieren',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Importieren Sie ESPP Lookback-Preise und Kaufdetails',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: _isImporting ? Colors.blue[50] : Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _status,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_logs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _logs.map((log) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: log.startsWith('✓') ? Colors.green[700]
                                        : log.startsWith('Fehler') ? Colors.red[700]
                                        : Colors.black87,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}