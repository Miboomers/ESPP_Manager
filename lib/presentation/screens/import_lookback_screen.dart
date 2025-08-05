import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/lookback_parser.dart';
import '../../core/services/lookback_enrichment_service.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../widgets/flexible_bottom_action_bar.dart';

class ImportLookbackScreen extends ConsumerStatefulWidget {
  const ImportLookbackScreen({super.key});

  @override
  ConsumerState<ImportLookbackScreen> createState() => _ImportLookbackScreenState();
}

class _ImportLookbackScreenState extends ConsumerState<ImportLookbackScreen> {
  final _clipboardController = TextEditingController();
  List<LookbackData> _parsedData = [];
  bool _isParsing = false;
  String? _errorMessage;

  // Manual input controllers
  final _offeringPeriodController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _lookbackFmvController = TextEditingController();
  final _fmvAtPurchaseController = TextEditingController();
  final _actualPriceController = TextEditingController();
  final _sharesController = TextEditingController();
  final _qualifiedDateController = TextEditingController();
  bool _showManualInput = false;

  @override
  void dispose() {
    _clipboardController.dispose();
    _offeringPeriodController.dispose();
    _purchaseDateController.dispose();
    _lookbackFmvController.dispose();
    _fmvAtPurchaseController.dispose();
    _actualPriceController.dispose();
    _sharesController.dispose();
    _qualifiedDateController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        _clipboardController.text = clipboardData!.text!;
        await _parseClipboardData(clipboardData.text!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Einfügen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _parseClipboardData(String text) async {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
    });

    try {
      if (text.isEmpty) {
        setState(() {
          _errorMessage = 'Bitte fügen Sie Lookback-Daten ein';
          _isParsing = false;
        });
        return;
      }

      final parsedData = LookbackParser.parseFromClipboard(text);
      
      // DEBUG: Prüfe Parse-Ergebnis
      print('🔍 DEBUG: Lookback-Import - Eingabetext-Länge: ${text.length}');
      print('🔍 DEBUG: Lookback-Import - Gefundene Datensätze: ${parsedData.length}');
      for (int i = 0; i < parsedData.length; i++) {
        final data = parsedData[i];
        print('  Datensatz ${i + 1}:');
        print('    - Offering Period: ${data.offeringPeriod}');
        print('    - Purchase Date: ${data.purchaseDate}');
        print('    - Lookback FMV: ${data.lookbackFmv}');
        print('    - FMV at Purchase: ${data.fmvAtPurchase}');
        print('    - Actual Price: ${data.actualPrice}');
        print('    - Shares: ${data.shares}');
      }
      
      if (parsedData.isEmpty) {
        print('❌ DEBUG: Keine Lookback-Daten geparst - Erste 500 Zeichen der Eingabe:');
        print(text.substring(0, text.length > 500 ? 500 : text.length));
        
        setState(() {
          _errorMessage = 'Keine gültigen Daten gefunden. Bitte überprüfen Sie das Format.';
          _isParsing = false;
        });
        return;
      }

      // Validate all parsed data
      final invalidData = parsedData.where((data) => !LookbackParser.validateLookbackData(data)).toList();
      if (invalidData.isNotEmpty) {
        setState(() {
          _errorMessage = 'Einige Daten scheinen ungültig zu sein. Bitte überprüfen.';
        });
      }

      setState(() {
        _parsedData = parsedData;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler beim Parsen: $e';
        _isParsing = false;
      });
    }
  }

  void _importData() async {
    if (_parsedData.isEmpty) return;
    
    final transactionsNotifier = ref.read(transactionsProvider.notifier);
    final existingTransactions = await ref.read(transactionsProvider.future);
    
    // NEUE LOGIK: Enrichment statt neue Transaktionen erstellen
    print('🚀 DEBUG: Lookback-Enrichment gestartet');
    print('  - Bestehende Transaktionen: ${existingTransactions.length}');
    print('  - Lookback-Datensätze: ${_parsedData.length}');
    
    // Filtere nur die Verkaufstransaktionen
    final existingSales = existingTransactions.where((t) => t.isSold).toList();
    print('  - Bestehende Verkäufe: ${existingSales.length}');
    
    if (existingSales.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Verkaufstransaktionen gefunden. Importieren Sie zuerst Ihre Verkäufe.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Reichere Verkaufstransaktionen mit Lookback-Daten an
    final enrichedSales = LookbackEnrichmentService.enrichSalesWithLookbackData(
      existingSales,
      _parsedData,
    );
    
    // Validiere das Ergebnis
    final result = LookbackEnrichmentService.validateEnrichment(existingSales, enrichedSales);
    print('📊 Enrichment-Ergebnis: ${result.summary}');
    
    // Aktualisiere alle angereicherten Verkaufstransaktionen
    int updatedCount = 0;
    for (final enrichedSale in enrichedSales) {
      // Nur aktualisieren wenn Lookback-Daten hinzugefügt wurden
      final originalSale = existingSales.firstWhere((s) => s.id == enrichedSale.id);
      if (originalSale.lookbackFmv == null && enrichedSale.lookbackFmv != null) {
        await transactionsNotifier.updateTransaction(enrichedSale);
        updatedCount++;
        print('✅ Verkauf ${enrichedSale.id} erfolgreich angereichert');
      }
    }
    
    // Zeige Ergebnis
    if (mounted) {
      final message = result.isSuccessful 
        ? 'Erfolgreich! $updatedCount Verkäufe mit Lookback-Daten angereichert.'
        : 'Warnung: Nur ${result.enrichedSales} von ${result.totalSales} Verkäufen konnten angereichert werden.';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result.isSuccessful ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      
      // Zurück zur Transaktionsliste
      Navigator.of(context).pop();
    }
  }

  void _addManualEntry() {
    try {
      final lookbackData = LookbackData(
        offeringPeriod: _offeringPeriodController.text,
        purchaseDate: DateFormat('dd.MM.yyyy').parse(_purchaseDateController.text),
        lookbackFmv: _parseInput(_lookbackFmvController.text),
        fmvAtPurchase: _parseInput(_fmvAtPurchaseController.text),
        actualPrice: _parseInput(_actualPriceController.text),
        shares: _parseInput(_sharesController.text),
        purchaseValue: _parseInput(_actualPriceController.text) * 
                      _parseInput(_sharesController.text),
        qualifiedDispositionDate: DateFormat('dd.MM.yyyy').parse(_qualifiedDateController.text),
        accountType: 'Brokerage',
      );
      
      if (LookbackParser.validateLookbackData(lookbackData)) {
        setState(() {
          _parsedData.add(lookbackData);
          _clearManualInputs();
          _showManualInput = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Validierung der manuellen Eingabe fehlgeschlagen';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler bei der manuellen Eingabe: $e';
      });
    }
  }

  double _parseInput(String input) {
    return double.parse(input.replaceAll(',', '.'));
  }

  void _clearManualInputs() {
    _offeringPeriodController.clear();
    _purchaseDateController.clear();
    _lookbackFmvController.clear();
    _fmvAtPurchaseController.clear();
    _actualPriceController.clear();
    _sharesController.clear();
    _qualifiedDateController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lookback-Daten importieren'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lookback-Daten von Fidelity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kopieren Sie die Lookback-Daten aus Ihrem Fidelity-Konto und fügen Sie sie hier ein.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  // Clipboard Input
                  TextField(
                    controller: _clipboardController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Lookback-Daten hier einfügen',
                      hintText: 'Kopieren Sie die Tabelle aus Fidelity und fügen Sie sie hier ein...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      if (text.isNotEmpty && text != _clipboardController.text) {
                        _parseClipboardData(text);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Paste Button
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pasteFromClipboard,
                        icon: const Icon(Icons.paste),
                        label: const Text('Aus Zwischenablage einfügen'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showManualInput = !_showManualInput;
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Manuell hinzufügen'),
                      ),
                    ],
                  ),
                  
                  if (_isParsing) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_errorMessage!)),
                        ],
                      ),
                    ),
                  ],
                  
                  // Manual Input Form
                  if (_showManualInput) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manuelle Eingabe',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _offeringPeriodController,
                              decoration: const InputDecoration(
                                labelText: 'Angebotszeitraum',
                                hintText: 'z.B. NOV/01/2024 - APR/30/2025',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _purchaseDateController,
                              decoration: const InputDecoration(
                                labelText: 'Kaufdatum',
                                hintText: 'dd.MM.yyyy',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _lookbackFmvController,
                                    decoration: const InputDecoration(
                                      labelText: 'Lookback FMV',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _fmvAtPurchaseController,
                                    decoration: const InputDecoration(
                                      labelText: 'FMV am Kaufdatum',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _actualPriceController,
                                    decoration: const InputDecoration(
                                      labelText: 'Tatsächlicher Preis',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _sharesController,
                                    decoration: const InputDecoration(
                                      labelText: 'Anzahl Aktien',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _qualifiedDateController,
                              decoration: const InputDecoration(
                                labelText: 'Qualified Disposition Date',
                                hintText: 'dd.MM.yyyy',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _addManualEntry,
                              child: const Text('Hinzufügen'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Parsed Data Display
                  if (_parsedData.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gefundene Lookback-Daten (${_parsedData.length})',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ...(_parsedData.take(5).map((data) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      data.offeringPeriod,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd.MM.yyyy').format(data.purchaseDate),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '\$${data.lookbackFmv.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${data.shares.toStringAsFixed(2)} Aktien',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ))),
                            if (_parsedData.length > 5) ...[
                              const SizedBox(height: 8),
                              Text(
                                '... und ${_parsedData.length - 5} weitere',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
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
          ),
          
          // Bottom Action Bar
          if (_parsedData.isNotEmpty)
            FlexibleBottomActionBar(
              primaryIcon: Icons.upload,
              primaryLabel: '${_parsedData.length} Lookback-Datensätze anreichern',
              primaryAction: _importData,
            ),
        ],
      ),
    );
  }
}