import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/transactions_provider.dart';
import '../../data/models/transaction_model.dart';
import 'add_purchase_screen.dart';
import '../../core/utils/app_icons.dart';
import '../widgets/common_bottom_action_bar.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alle Transaktionen'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Alle', icon: Icon(Icons.list)),
            Tab(text: 'Offen', icon: Icon(Icons.trending_up)),
            Tab(text: 'Verkauft', icon: Icon(Icons.check_circle)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddPurchaseScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final filteredTransactions = _filterTransactions(transactions);
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionsList(filteredTransactions, 'Alle'),
              _buildTransactionsList(
                filteredTransactions.where((t) => !t.isSold).toList(),
                'Offene Positionen',
              ),
              _buildTransactionsList(
                filteredTransactions.where((t) => t.isSold).toList(),
                'Verkaufte Positionen',
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Fehler beim Laden: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () { ref.refresh(transactionsProvider); },
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CommonBottomActionBar(), // Immer beide Buttons
    );
  }

  List<TransactionModel> _filterTransactions(List<TransactionModel> transactions) {
    if (_searchQuery.isEmpty) return transactions;
    
    return transactions.where((transaction) {
      final query = _searchQuery.toLowerCase();
      final date = DateFormat('dd.MM.yyyy').format(transaction.purchaseDate);
      final quantity = transaction.quantity.toString();
      final fmv = transaction.fmvPerShare.toString();
      
      return date.contains(query) ||
             quantity.contains(query) ||
             fmv.contains(query);
    }).toList();
  }

  Widget _buildTransactionsList(List<TransactionModel> transactions, String emptyMessage) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Keine Transaktionen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              emptyMessage == 'Alle' 
                  ? 'Fügen Sie Ihre erste Transaktion hinzu'
                  : 'Keine $emptyMessage vorhanden',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddPurchaseScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Transaktion hinzufügen'),
            ),
          ],
        ),
      );
    }

    // Sort transactions by date (newest first)
    final sortedTransactions = List<TransactionModel>.from(transactions)
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(transactionsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 100), // Extra bottom padding for action bar
        itemCount: sortedTransactions.length,
        itemBuilder: (context, index) {
          final transaction = sortedTransactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel transaction) {
    final isProfit = transaction.isSold && 
        transaction.salePricePerShare != null &&
        transaction.salePricePerShare! > transaction.fmvPerShare;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: transaction.isSold
                        ? (isProfit ? Colors.green : Colors.red)
                        : Colors.blue,
                    child: Icon(
                      transaction.isSold
                          ? (isProfit ? Icons.trending_up : Icons.trending_down)
                          : Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${transaction.quantity.toStringAsFixed(transaction.quantity == transaction.quantity.roundToDouble() ? 0 : 2)} Aktien',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kauf: ${DateFormat('dd.MM.yyyy').format(transaction.purchaseDate)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: transaction.isSold ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      transaction.isSold ? 'Verkauft' : 'Offen',
                      style: TextStyle(
                        color: transaction.isSold ? Colors.green : Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FMV: \$${transaction.fmvPerShare.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                        if (transaction.isSold && transaction.saleDate != null)
                          Text(
                            'Verkauf: ${DateFormat('dd.MM.yyyy').format(transaction.saleDate!)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Bezahlt: \$${transaction.purchasePricePerShare.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                        Text(
                          'Rabatt: \$${((transaction.fmvPerShare - transaction.purchasePricePerShare) * transaction.quantity).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transaktions-Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddPurchaseScreen(
                                    existingTransaction: transaction,
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildDetailRow('Anzahl Aktien', '${transaction.quantity.toStringAsFixed(transaction.quantity == transaction.quantity.roundToDouble() ? 0 : 2)}'),
                  _buildDetailRow('Kaufdatum', DateFormat('dd.MM.yyyy').format(transaction.purchaseDate)),
                  if (transaction.saleDate != null)
                    _buildDetailRow('Verkaufsdatum', DateFormat('dd.MM.yyyy').format(transaction.saleDate!)),
                  const SizedBox(height: 16),
                  Text('Preise (USD)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildDetailRow('Fair Market Value', '\$${transaction.fmvPerShare.toStringAsFixed(2)}'),
                  _buildDetailRow('Kaufpreis (nach Rabatt)', '\$${transaction.purchasePricePerShare.toStringAsFixed(2)}'),
                  if (transaction.salePricePerShare != null)
                    _buildDetailRow('Verkaufspreis', '\$${transaction.salePricePerShare!.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  Text('Berechnungen', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildDetailRow('ESPP Rabatt pro Aktie', '\$${(transaction.fmvPerShare - transaction.purchasePricePerShare).toStringAsFixed(2)}'),
                  _buildDetailRow('Gesamtrabatt', '\$${((transaction.fmvPerShare - transaction.purchasePricePerShare) * transaction.quantity).toStringAsFixed(2)}'),
                  _buildDetailRow('Lohnsteuer (${(transaction.incomeTaxRate * 100).toStringAsFixed(0)}%)', '\$${(((transaction.fmvPerShare - transaction.purchasePricePerShare) * transaction.quantity) * transaction.incomeTaxRate).toStringAsFixed(2)}'),
                  if (transaction.isSold && transaction.salePricePerShare != null)
                    _buildDetailRow('Kapitalgewinn/-verlust', '\$${(((transaction.salePricePerShare! - transaction.fmvPerShare) * transaction.quantity)).toStringAsFixed(2)}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaktionen suchen'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Datum, Anzahl oder Preis eingeben...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('Löschen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}