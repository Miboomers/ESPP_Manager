import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/lookback_parser.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/flexible_bottom_action_bar.dart';

class ImportLookbackScreen extends ConsumerStatefulWidget {
  const ImportLookbackScreen({super.key});

  @override
  ConsumerState<ImportLookbackScreen> createState() => _ImportLookbackScreenState();
}

class _ImportLookbackScreenState extends ConsumerState<ImportLookbackScreen> {
  final _pasteController = TextEditingController();
  List<LookbackData> _parsedData = [];
  bool _isParsing = false;
  String? _errorMessage;
  
  double _parseInput(String value) {
    // Handle German number format (comma as decimal separator)
    final cleanValue = value
        .replaceAll(',', '.')
        .replaceAll(' ', '')
        .trim();
    return double.tryParse(cleanValue) ?? 0.0;
  }
  
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
    _pasteController.dispose();
    _offeringPeriodController.dispose();
    _purchaseDateController.dispose();
    _lookbackFmvController.dispose();
    _fmvAtPurchaseController.dispose();
    _actualPriceController.dispose();
    _sharesController.dispose();
    _qualifiedDateController.dispose();
    super.dispose();
  }

  void _parseClipboardData() {
    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _parsedData = [];
    });

    try {
      final text = _pasteController.text.trim();
      if (text.isEmpty) {
        setState(() {
          _errorMessage = 'Bitte fügen Sie die Daten aus Fidelity ein';
          _isParsing = false;
        });
        return;
      }

      final parsedData = LookbackParser.parseFromClipboard(text);
      
      if (parsedData.isEmpty) {
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

    final settingsAsync = ref.read(settingsProvider);
    final settings = settingsAsync.value;
    if (settings == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Einstellungen werden geladen...'),
        ),
      );
      return;
    }
    
    final transactionsNotifier = ref.read(transactionsProvider.notifier);
    
    int importedCount = 0;
    
    for (final lookbackData in _parsedData) {
      try {
        // Create a purchase transaction with lookback data
        final transaction = TransactionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          purchaseDate: lookbackData.purchaseDate,
          quantity: lookbackData.shares,
          fmvPerShare: lookbackData.fmvAtPurchase,
          purchasePricePerShare: lookbackData.actualPrice,
          lookbackFmv: lookbackData.lookbackFmv,
          offeringPeriod: lookbackData.offeringPeriod,
          qualifiedDispositionDate: lookbackData.qualifiedDispositionDate,
          incomeTaxRate: settings.defaultIncomeTaxRate,
          capitalGainsTaxRate: settings.defaultCapitalGainsTaxRate,
          exchangeRateAtPurchase: 0.92, // Standard USD to EUR rate
          type: TransactionType.purchase,
          createdAt: DateTime.now(),
        );
        
        await transactionsNotifier.addTransaction(transaction);
        importedCount++;
      } catch (e) {
        // Log error in production
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$importedCount Transaktionen erfolgreich importiert'),
          backgroundColor: Colors.green,
        ),
      );
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
          _errorMessage = 'Ungültige Daten. Bitte überprüfen Sie Ihre Eingaben.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler bei der manuellen Eingabe: $e';
      });
    }
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
        title: const Text('ESPP Lookback-Daten importieren'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32, // Account for padding
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Option A: Copy-Paste Import
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.content_paste),
                        const SizedBox(width: 8),
                        const Text(
                          'Option A: Copy-Paste Import',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.help_outline),
                          onPressed: () => _showFormatHelp(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kopieren Sie die Daten direkt aus dem Fidelity Portal:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pasteController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Fügen Sie hier die kopierten Daten ein...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.paste),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data != null) {
                              _pasteController.text = data.text ?? '';
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isParsing ? null : _parseClipboardData,
                        icon: _isParsing 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.analytics),
                        label: Text(_isParsing ? 'Verarbeite...' : 'Daten parsen'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Option C: Manual Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: 8),
                        const Text(
                          'Option C: Manuelle Eingabe',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(_showManualInput ? Icons.expand_less : Icons.expand_more),
                          onPressed: () {
                            setState(() {
                              _showManualInput = !_showManualInput;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_showManualInput) ...[
                      const SizedBox(height: 16),
                      _buildManualInputForm(),
                    ],
                  ],
                ),
              ),
            ),
            
            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Parsed data preview
            if (_parsedData.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (_parsedData.isNotEmpty)
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              '${_parsedData.length} Einträge gefunden',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _parsedData.length,
                            itemBuilder: (context, index) {
                              final data = _parsedData[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    'Kauf: ${DateFormat('dd.MM.yyyy').format(data.purchaseDate)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Zeitraum: ${data.offeringPeriod}'),
                                      Text('Aktien: ${data.shares.toStringAsFixed(4)}'),
                                      Text(
                                        'Rabatt: \$${(data.lookbackFmv - data.actualPrice).toStringAsFixed(2)}/Aktie',
                                        style: const TextStyle(color: Colors.green),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _parsedData.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    bottomNavigationBar: FlexibleBottomActionBar(
        primaryAction: _parsedData.isNotEmpty
            ? () => _importData()
            : null,
        primaryLabel: 'Importieren (${_parsedData.length})',
        primaryIcon: Icons.upload,
        primaryColor: Colors.green,
      ),
    );
  }

  Widget _buildManualInputForm() {
    return Column(
      children: [
        TextField(
          controller: _offeringPeriodController,
          decoration: const InputDecoration(
            labelText: 'Angebotszeitraum',
            hintText: 'z.B. MAY/01/2023 - OCT/31/2023',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _purchaseDateController,
                decoration: const InputDecoration(
                  labelText: 'Kaufdatum',
                  hintText: 'DD.MM.YYYY',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _qualifiedDateController,
                decoration: const InputDecoration(
                  labelText: 'Qualifizierter Verkauf ab',
                  hintText: 'DD.MM.YYYY',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _lookbackFmvController,
                decoration: const InputDecoration(
                  labelText: 'Lookback FMV',
                  hintText: '0,00',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _fmvAtPurchaseController,
                decoration: const InputDecoration(
                  labelText: 'FMV am Kauftag',
                  hintText: '0,00',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _actualPriceController,
                decoration: const InputDecoration(
                  labelText: 'Tatsächlicher Kaufpreis',
                  hintText: '0,00',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sharesController,
                decoration: const InputDecoration(
                  labelText: 'Anzahl Aktien',
                  hintText: '0,0000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addManualEntry,
            icon: const Icon(Icons.add),
            label: const Text('Manuellen Eintrag hinzufügen'),
          ),
        ),
      ],
    );
  }

  void _showFormatHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erwartetes Format'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Kopieren Sie die Tabelle aus dem Fidelity Portal:'),
              SizedBox(height: 16),
              Text(
                'MAY/01/2023 - OCT/31/2023    OCT/31/2023    \$234.43 USD    \$141.22 USD    \$120.04 USD    77.693 shares    \$9,326.06 USD    MAY/01/2025    Maklerkonto',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  backgroundColor: Colors.grey,
                ),
              ),
              SizedBox(height: 16),
              Text('Die Spalten sind:'),
              Text('• Angebotszeitraum'),
              Text('• Kaufdatum'),
              Text('• Lookback FMV'),
              Text('• FMV am Kauftag'),
              Text('• Tatsächlicher Kaufpreis'),
              Text('• Anzahl Aktien'),
              Text('• Gesamtwert'),
              Text('• Qualifizierter Verkauf ab'),
              Text('• Kontotyp'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}