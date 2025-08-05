import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert';
import '../../data/models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_price_provider.dart';
import '../../core/utils/duplicate_detector.dart';
import '../../data/datasources/exchange_rate_api.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  bool _isImporting = false;
  String _status = '';
  List<String> _logs = [];
  List<File> _selectedFiles = [];
  bool _isClosedPositions = true; // true = Verkäufe, false = Offene Positionen - wird automatisch erkannt
  
  // Statistiken
  int _totalTransactions = 0;
  int _importedTransactions = 0;
  int _skippedTransactions = 0;
  int _errorTransactions = 0;
  
  // ID Counter für eindeutige IDs
  int _idCounter = 0;

  // Automatische Erkennung des CSV-Typs anhand der Header
  bool _detectCsvType(List<String> headers) {
    // Normalisiere Header für besseren Vergleich
    final normalizedHeaders = headers.map((h) => h.toLowerCase().trim()).toList();
    
    // Geschlossene Positionen haben "Verkaufsdatum" und "Erlöse"
    final hasVerkaufsdatum = normalizedHeaders.any((h) => h.contains('verkaufsdatum') || h.contains('sale date'));
    final hasErloese = normalizedHeaders.any((h) => h.contains('erlöse') || h.contains('proceeds'));
    
    // Offene Positionen haben "Wert" statt "Erlöse"
    final hasWert = normalizedHeaders.any((h) => h == 'wert' || h == 'value');
    
    if (hasVerkaufsdatum && hasErloese) {
      _logs.add('✓ Erkannt als: Geschlossene Positionen (Verkäufe)');
      return true; // Geschlossene Positionen
    } else if (hasWert && !hasVerkaufsdatum) {
      _logs.add('✓ Erkannt als: Offene Positionen (Käufe)');
      return false; // Offene Positionen
    } else {
      // Fallback: Schaue nach anderen Indikatoren
      _logs.add('⚠️ CSV-Typ konnte nicht eindeutig erkannt werden, verwende Fallback-Erkennung');
      return hasVerkaufsdatum; // Wenn Verkaufsdatum vorhanden, dann geschlossene Positionen
    }
  }

  Future<void> _selectFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files
              .where((file) => file.path != null)
              .map((file) => File(file.path!))
              .toList();
          
          if (_selectedFiles.length == 1) {
            _status = 'Datei ausgewählt: ${result.files.first.name}';
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
      _skippedTransactions = 0;
      _errorTransactions = 0;
      _idCounter = DateTime.now().millisecondsSinceEpoch; // Basis für eindeutige IDs
    });

    // WICHTIG: Alle API Providers invalidieren um Rate Limits zu vermeiden
    ref.invalidate(stockPriceProvider);
    _logs.add('🔄 API Provider pausiert für Import...');

    try {
      // Sammle alle Transaktionen von allen Dateien
      final Map<bool, List<TransactionModel>> transactionsByType = {
        true: [], // Geschlossene Positionen
        false: [], // Offene Positionen
      };
      
      // Verarbeite jede ausgewählte Datei
      for (final file in _selectedFiles) {
        _logs.add('');
        _logs.add('📄 Verarbeite Datei: ${file.path.split('/').last}');
        
        final input = await file.readAsString(encoding: utf8);
      
      // Remove BOM if present
      final cleanInput = input.startsWith('\ufeff') ? input.substring(1) : input;
      
      // Parse CSV
      final List<List<dynamic>> rows = const CsvToListConverter().convert(cleanInput);
      
      if (rows.isEmpty) {
        throw Exception('Die CSV-Datei ist leer');
      }

      // Get headers
      final headers = rows[0].map((e) => e.toString().trim()).toList();
      _logs.add('Headers gefunden: ${headers.join(", ")}');

      // Get settings for tax rates
      final settings = await ref.read(settingsProvider.future);
      
      // Sammle alle Transaktionen erst, dann importiere als Batch
      final List<TransactionModel> transactionsToImport = [];
      
      // Process data rows
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        
        // Skip empty rows
        if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
          continue;
        }
        
        _totalTransactions++;
        
        try {
          TransactionModel transaction;
          if (_isClosedPositions) {
            transaction = _createClosedPositionTransaction(row, headers, settings);
          } else {
            transaction = _createOpenPositionTransaction(row, headers, settings);
          }
          
          transactionsToImport.add(transaction);
          _importedTransactions++;
          _logs.add('✓ Vorbereitet: ${transaction.quantity}x ${_isClosedPositions ? 'Verkauf' : 'Kauf'}');
          
          // Update UI alle 10 Transaktionen
          if (_importedTransactions % 10 == 0) {
            setState(() {});
          }
        } catch (e) {
          _errorTransactions++;
          _logs.add('Fehler in Zeile ${i + 1}: $e');
        }
      }
      
      // Import-Strategie basierend auf Checkbox-Auswahl
      if (transactionsToImport.isNotEmpty) {
        final existingTransactions = await ref.read(transactionsProvider.future);
        
        // Import-Strategie basierend auf CSV-Typ
        // Geschlossene Positionen: Fresh Import (ersetzt alles)
        // Offene Positionen: Nur Käufe ersetzen, Verkäufe behalten
        final strategy = _isClosedPositions 
          ? ImportStrategy.freshImport 
          : ImportStrategy.smartUpdate;
        
        // Zeige Warnung nur wenn bereits Daten vorhanden sind
        if (existingTransactions.isNotEmpty) {
          // Bei offenen Positionen zeige nur die Anzahl der Verkäufe
          final existingSales = existingTransactions.where((t) => t.type == TransactionType.sale).length;
          final displayCount = _isClosedPositions ? existingTransactions.length : existingSales;
          
          final shouldProceed = await _showImportWarning(
            _isClosedPositions ? 'Geschlossene Positionen' : 'Offene Positionen',
            displayCount,
            transactionsToImport.length,
          );
          
          if (!shouldProceed) {
            setState(() {
              _status = 'Import abgebrochen';
              _isImporting = false;
            });
            return;
          }
        }
        
        await _executeImportStrategy(strategy, existingTransactions, transactionsToImport);
      }

      setState(() {
        _status = 'Import abgeschlossen!';
        _logs.add('');
        _logs.add('=== ZUSAMMENFASSUNG ===');
        _logs.add('Gesamt: $_totalTransactions Transaktionen');
        _logs.add('Importiert: $_importedTransactions');
        _logs.add('Übersprungen: $_skippedTransactions');
        _logs.add('Fehler: $_errorTransactions');
        _isImporting = false;
      });

      if (_importedTransactions > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_importedTransactions Transaktionen erfolgreich importiert!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Import fehlgeschlagen: $e';
        _isImporting = false;
      });
    }
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

  Future<bool> _showImportWarning(String importType, int existingCount, int newCount) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text('$importType Import'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(importType == 'Geschlossene Positionen'
                  ? 'Sie haben bereits $existingCount Transaktionen in der App.'
                  : 'Sie haben $existingCount geschlossene Positionen (Verkäufe) in der App.'),
                const SizedBox(height: 12),
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
                      Text(importType == 'Geschlossene Positionen' 
                        ? 'CSV-Import ersetzt ALLE bestehenden Daten!'
                        : 'Import ersetzt nur offene Positionen. Ihre $existingCount Verkäufe bleiben erhalten!'),
                      const SizedBox(height: 8),
                      const Text('Empfohlener Workflow:'),
                      const Text('1. Geschlossene Positionen CSV importieren'),
                      const Text('2. Offene Positionen CSV importieren'),  
                      const Text('3. Lookback-Daten hinzufügen'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Möchten Sie fortfahren und $newCount neue Transaktionen importieren?'),
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
              child: Text(importType == 'Geschlossene Positionen' 
                ? 'Alle Daten ersetzen' 
                : 'Offene Positionen ersetzen'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }

  Future<void> _executeImportStrategy(
    ImportStrategy strategy,
    List<TransactionModel> existingTransactions,
    List<TransactionModel> transactionsToImport,
  ) async {
    final transactionsNotifier = ref.read(transactionsProvider.notifier);
    
    switch (strategy) {
      case ImportStrategy.freshImport:
        _logs.add('🗑️ Lösche alle bestehenden Transaktionen...');
        setState(() {});
        
        // Alle bestehenden Transaktionen löschen
        for (final tx in existingTransactions) {
          await transactionsNotifier.deleteTransaction(tx.id);
        }
        
        _logs.add('✅ ${existingTransactions.length} bestehende Transaktionen gelöscht');
        _logs.add('💾 Importiere ${transactionsToImport.length} neue Transaktionen...');
        setState(() {});
        
        // Historische Wechselkurse abrufen und Transaktionen aktualisieren
        _logs.add('🌍 Lade historische Wechselkurse...');
        setState(() {});
        
        final updatedTransactions = await _enrichWithHistoricalRates(transactionsToImport);
        
        // Alle neuen Transaktionen importieren
        for (final transaction in updatedTransactions) {
          await transactionsNotifier.addTransaction(transaction);
        }
        
        _importedTransactions = updatedTransactions.length;
        _skippedTransactions = 0;
        break;
        
      case ImportStrategy.smartUpdate:
        // Für offene Positionen: Lösche nur alte Käufe, behalte Verkäufe
        _logs.add('🔄 Ersetze nur offene Positionen...');
        setState(() {});
        
        // Lösche nur bestehende Käufe (offene Positionen)
        final existingPurchases = existingTransactions.where((t) => t.type == TransactionType.purchase).toList();
        final existingSales = existingTransactions.where((t) => t.type == TransactionType.sale).toList();
        
        _logs.add('📊 Behalte ${existingSales.length} Verkäufe (geschlossene Positionen)');
        _logs.add('🗑️ Ersetze ${existingPurchases.length} alte offene Positionen');
        
        for (final purchase in existingPurchases) {
          await transactionsNotifier.deleteTransaction(purchase.id);
        }
        
        // Historische Wechselkurse abrufen
        _logs.add('🌍 Lade historische Wechselkurse...');
        setState(() {});
        
        final updatedTransactions = await _enrichWithHistoricalRates(transactionsToImport);
        
        // Importiere neue offene Positionen
        for (final transaction in updatedTransactions) {
          await transactionsNotifier.addTransaction(transaction);
        }
        
        _importedTransactions = updatedTransactions.length;
        _skippedTransactions = 0;
        _logs.add('✅ ${updatedTransactions.length} neue offene Positionen importiert');
        break;
        
      case ImportStrategy.incrementalOnly:
        _logs.add('🔍 Erkenne bereits vorhandene Transaktionen...');
        setState(() {});
        
        final existingKeys = existingTransactions.map(DuplicateDetector.generateTransactionKey).toSet();
        final newTransactions = transactionsToImport.where((t) => 
          !existingKeys.contains(DuplicateDetector.generateTransactionKey(t))
        ).toList();
        
        _logs.add('💾 Importiere ${newTransactions.length} wirklich neue Transaktionen...');
        setState(() {});
        
        for (final transaction in newTransactions) {
          await transactionsNotifier.addTransaction(transaction);
        }
        
        _importedTransactions = newTransactions.length;
        _skippedTransactions = transactionsToImport.length - newTransactions.length;
        
        if (_skippedTransactions > 0) {
          _logs.add('⏭️ $_skippedTransactions bereits vorhandene Transaktionen übersprungen');
        }
        break;
    }
  }




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
                      'Importieren Sie Ihre ESPP-Transaktionen direkt aus Fidelity CSV-Exporten.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    // Verwende Wrap für bessere Mobile-Unterstützung
                    Wrap(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isClosedPositions = true;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<bool>(
                                value: true,
                                groupValue: _isClosedPositions,
                                onChanged: (value) {
                                  setState(() {
                                    _isClosedPositions = value!;
                                  });
                                },
                              ),
                              const Text('Geschlossene Positionen'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isClosedPositions = false;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<bool>(
                                value: false,
                                groupValue: _isClosedPositions,
                                onChanged: (value) {
                                  setState(() {
                                    _isClosedPositions = value!;
                                  });
                                },
                              ),
                              const Text('Offene Positionen'),
                            ],
                          ),
                        ),
                      ],
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
                      _selectedFile != null ? Icons.check_circle : Icons.upload_file,
                      size: 48,
                      color: _selectedFile != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFile != null
                          ? 'Datei: ${_selectedFile!.path.split('/').last}'
                          : 'Keine Datei ausgewählt',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isImporting ? null : _selectFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('CSV-Datei auswählen'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isImporting || _selectedFile == null ? null : _importData,
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