import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transactions_provider.dart';
import '../widgets/common_bottom_action_bar.dart';
import '../../data/models/transaction_model.dart';
import '../widgets/data_exporter.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  int? selectedYear;
  ExportFormat selectedFormat = ExportFormat.csv;
  List<int> availableYears = [];
  bool includeOpenPositions = true;
  bool includeSoldPositions = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableYears();
  }

  void _loadAvailableYears() {
    final transactionsAsync = ref.read(transactionsProvider);
    transactionsAsync.whenData((transactions) {
      final years = <int>{};
      
      // Jahre aus Käufen
      for (final transaction in transactions) {
        years.add(transaction.purchaseDate.year);
        
        // Jahre aus Verkäufen
        if (transaction.saleDate != null) {
          years.add(transaction.saleDate!.year);
        }
      }
      
      setState(() {
        availableYears = years.toList()..sort((a, b) => b.compareTo(a));
        if (availableYears.isNotEmpty) {
          selectedYear = availableYears.first;
        }
      });
    });
  }

  List<TransactionModel> _getTransactionsForYear(List<TransactionModel> allTransactions, int year) {
    return allTransactions.where((t) {
      final purchaseInYear = t.purchaseDate.year == year;
      final saleInYear = t.saleDate?.year == year;
      
      if (includeOpenPositions && !includeSoldPositions) {
        return purchaseInYear && t.type == TransactionType.purchase;
      } else if (!includeOpenPositions && includeSoldPositions) {
        return saleInYear == true;
      } else if (includeOpenPositions && includeSoldPositions) {
        return purchaseInYear || (saleInYear == true);
      }
      return false;
    }).toList()..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daten exportieren'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (availableYears.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Keine Daten zum Exportieren vorhanden.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final yearTransactions = selectedYear != null 
              ? _getTransactionsForYear(transactions, selectedYear!)
              : <TransactionModel>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export-Einstellungen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Jahr auswählen
                        DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Steuerjahr',
                            border: OutlineInputBorder(),
                          ),
                          items: availableYears.map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedYear = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Position-Filter
                        const Text(
                          'Welche Positionen exportieren?',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          title: const Text('Offene Positionen'),
                          value: includeOpenPositions,
                          onChanged: (value) {
                            setState(() {
                              includeOpenPositions = value ?? false;
                            });
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('Verkaufte Positionen'),
                          value: includeSoldPositions,
                          onChanged: (value) {
                            setState(() {
                              includeSoldPositions = value ?? false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Format auswählen
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export-Format',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        RadioListTile<ExportFormat>(
                          title: const Text('CSV (Comma Separated Values)'),
                          subtitle: const Text('Für Excel, Google Sheets, etc.'),
                          value: ExportFormat.csv,
                          groupValue: selectedFormat,
                          onChanged: (value) {
                            setState(() {
                              selectedFormat = value!;
                            });
                          },
                        ),
                        RadioListTile<ExportFormat>(
                          title: const Text('Excel (.xlsx)'),
                          subtitle: const Text('Microsoft Excel Format'),
                          value: ExportFormat.excel,
                          groupValue: selectedFormat,
                          onChanged: (value) {
                            setState(() {
                              selectedFormat = value!;
                            });
                          },
                        ),
                        RadioListTile<ExportFormat>(
                          title: const Text('JSON'),
                          subtitle: const Text('Für Entwickler und APIs'),
                          value: ExportFormat.json,
                          groupValue: selectedFormat,
                          onChanged: (value) {
                            setState(() {
                              selectedFormat = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Daten-Vorschau
                if (yearTransactions.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Daten-Vorschau',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${yearTransactions.length} Einträge',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Folgende Daten werden exportiert:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• Kaufdatum & Verkaufsdatum'),
                                Text('• Anzahl Aktien'),
                                Text('• Kauf-/Verkaufspreis in USD'),
                                Text('• FMV (Fair Market Value)'),
                                Text('• ESPP-Rabatt'),
                                Text('• Wechselkurse (Kauf & Verkauf)'),
                                Text('• Alle Werte in EUR umgerechnet'),
                                Text('• Gewinne/Verluste'),
                                Text('• Steuerliche Berechnungen'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                
                // Export-Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: (selectedYear != null && yearTransactions.isNotEmpty)
                        ? () async {
                            await DataExporter.exportData(
                              context: context,
                              transactions: yearTransactions,
                              format: selectedFormat,
                              year: selectedYear!,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.download),
                    label: Text('Als ${selectedFormat.displayName} exportieren'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Fehler: $error'),
        ),
      ),
      bottomNavigationBar: const CommonBottomActionBar(),
    );
  }
}

enum ExportFormat {
  csv('CSV'),
  excel('Excel'),
  json('JSON');
  
  final String displayName;
  const ExportFormat(this.displayName);
}