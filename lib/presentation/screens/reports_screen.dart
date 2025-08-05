import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transactions_provider.dart';
import '../widgets/common_bottom_action_bar.dart';
import '../../data/models/transaction_model.dart';
import '../widgets/tax_report_generator.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int? selectedYear;
  List<int> availableYears = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableYears();
  }

  void _loadAvailableYears() {
    final transactionsAsync = ref.read(transactionsProvider);
    transactionsAsync.whenData((transactions) {
      final years = <int>{};
      
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.sale && transaction.saleDate != null) {
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
      return t.type == TransactionType.sale && 
             t.saleDate != null && 
             t.saleDate!.year == year;
    }).toList()..sort((a, b) => a.saleDate!.compareTo(b.saleDate!));
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Steuerberichte'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (availableYears.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Keine Verkäufe vorhanden.\n\nSobald Sie Aktien verkaufen, können Sie hier Steuerberichte für die jeweiligen Jahre erstellen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final yearTransactions = selectedYear != null 
              ? _getTransactionsForYear(transactions, selectedYear!)
              : <TransactionModel>[];

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Steuerjahr auswählen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Jahr',
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
                      if (selectedYear != null && yearTransactions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSummaryCard(yearTransactions),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await TaxReportGenerator.generateReport(
                                context,
                                selectedYear!,
                                yearTransactions,
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('PDF-Bericht erstellen'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (selectedYear != null && yearTransactions.isNotEmpty)
                Expanded(
                  child: _buildTransactionsList(yearTransactions),
                ),
            ],
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

  Widget _buildSummaryCard(List<TransactionModel> transactions) {
    final totalGainEUR = transactions.fold<double>(
      0, 
      (sum, t) => sum + (t.totalGainEUR ?? 0),
    );
    
    // Steuerpflichtiger Kapitalgewinn (ohne ESPP-Rabatt)
    final taxableGainEUR = transactions.fold<double>(
      0,
      (sum, t) {
        // Verkaufswert in EUR
        final saleValueEUR = t.salePricePerShare! * t.quantity * t.exchangeRateAtSale!;
        // FMV-Kostenbasis in EUR (mit Kauf-Wechselkurs!)
        final fmvCostEUR = t.fmvPerShare * t.quantity * t.exchangeRateAtPurchase!;
        // Steuerpflichtiger Gewinn
        return sum + (saleValueEUR - fmvCostEUR);
      },
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Zusammenfassung:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${transactions.length} Verkäufe',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gesamtgewinn:'),
              Text(
                '€${totalGainEUR.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: totalGainEUR >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stpfl. Kapitalgewinn:'),
              Text(
                '€${taxableGainEUR.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<TransactionModel> transactions) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final gainEUR = transaction.totalGainEUR ?? 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              '${transaction.saleDate!.day}.${transaction.saleDate!.month}.${transaction.saleDate!.year}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${transaction.quantity} Aktien | Kauf: ${transaction.purchaseDate.day}.${transaction.purchaseDate.month}.${transaction.purchaseDate.year}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '€${gainEUR.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: gainEUR >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                  'Gewinn',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}