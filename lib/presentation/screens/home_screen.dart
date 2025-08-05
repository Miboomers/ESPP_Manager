import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/transactions_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_price_provider.dart';
import '../../data/models/transaction_model.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/app_icons.dart';
import '../widgets/common_bottom_action_bar.dart';
import '../widgets/portfolio_summary_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESPP Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
        children: [
          _buildPortfolioSummary(ref),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildQuickActions(context),
          ),
          const SizedBox(height: 16),
          _buildRecentTransactions(context),
        ],
      ),
      bottomNavigationBar: const CommonBottomActionBar(),
    );
  }

  Widget _buildPortfolioSummary(WidgetRef ref) {
    return Consumer(
      builder: (context, consumerRef, child) {
        final transactionsAsync = consumerRef.watch(transactionsProvider);
        final exchangeRateAsync = consumerRef.watch(usdEurRateProvider);
        final exchangeRate = exchangeRateAsync.valueOrNull?.rate ?? 0.92;
        
        return transactionsAsync.when(
          data: (transactions) {
            final openPositions = transactions.where((t) => !t.isSold).toList();
            
            if (openPositions.isEmpty) {
              return Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Noch keine Aktien im Portfolio', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('Fügen Sie Ihren ersten ESPP-Kauf hinzu', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              );
            }
            
            return PortfolioSummaryWidget(
              openPositions: openPositions,
              exchangeRate: exchangeRate,
            );
          },
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Fehler beim Laden: $error'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final transactionsAsync = ref.watch(transactionsProvider);
        final settingsAsync = ref.watch(settingsProvider);
        
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portfolio Übersicht',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                transactionsAsync.when(
                  data: (transactions) {
                    return settingsAsync.when(
                      data: (settings) {
                        final openPositions = transactions.where((t) => !t.isSold).toList();
                        
                        // Calculate totals
                        final totalShares = openPositions.fold<double>(0, (sum, t) => sum + t.quantity);
                        final totalInvestment = openPositions.fold<double>(0, (sum, t) => sum + (t.purchasePricePerShare * t.quantity));
                        final totalFMV = openPositions.fold<double>(0, (sum, t) => sum + (t.fmvPerShare * t.quantity));
                        final totalDiscount = openPositions.fold<double>(0, (sum, t) => sum + ((t.fmvPerShare - t.purchasePricePerShare) * t.quantity));
                        
                        // Calculate taxes
                        final incomeTax = totalDiscount * settings.defaultIncomeTaxRate;
                        // Use live exchange rate with fallback
                        final exchangeRateAsync = ref.watch(usdEurRateProvider);
                        final exchangeRate = exchangeRateAsync.valueOrNull?.rate ?? 0.92;
                        final incomeTaxEUR = incomeTax * exchangeRate;
                        
                        // Calculate potential gain
                        final currentValue = totalFMV; // Using FMV as current market value for now
                        final gainLoss = currentValue - totalFMV; // This would be 0 until we have live prices
                        
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSummaryItem(
                                  context,
                                  'Aktueller Wert',
                                  '\$${currentValue.toStringAsFixed(2)}',
                                  Colors.blue,
                                ),
                                _buildSummaryItem(
                                  context,
                                  'Investiert',
                                  '\$${totalInvestment.toStringAsFixed(2)}',
                                  Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSummaryItem(
                                  context,
                                  'Anzahl Aktien',
                                  NumberFormatter.formatQuantity(totalShares),
                                  Colors.purple,
                                ),
                                _buildSummaryItem(
                                  context,
                                  'Lohnsteuer',
                                  '€${incomeTaxEUR.toStringAsFixed(2)}',
                                  Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSummaryItem(
                                  context,
                                  'ESPP Rabatt',
                                  '\$${totalDiscount.toStringAsFixed(2)}',
                                  Colors.teal,
                                ),
                                _buildSummaryItem(
                                  context,
                                  'Rabatt (EUR)',
                                  '€${(totalDiscount * exchangeRate).toStringAsFixed(2)}',
                                  Colors.indigo,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Fehler: $e')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Fehler: $e')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            'Depot',
            AppIcons.portfolio,
            () => Navigator.pushNamed(context, '/portfolio'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionCard(
            context,
            'Berichte',
            AppIcons.reports,
            () => Navigator.pushNamed(context, '/reports'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionCard(
            context,
            'Export',
            AppIcons.export,
            () => Navigator.pushNamed(context, '/export'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Letzte Transaktionen',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/transactions'),
                    child: const Text('Alle anzeigen'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Consumer(
            builder: (context, ref, child) {
              final transactionsAsync = ref.watch(transactionsProvider);
              
              return transactionsAsync.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Keine Transaktionen vorhanden',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Show last 3 transactions
                  // Sortiere Transaktionen nach createdAt (neueste zuerst) und nimm die ersten 3
                  final sortedTransactions = List<TransactionModel>.from(transactions)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  final recentTransactions = sortedTransactions.take(3).toList();
                  
                  return Column(
                    children: recentTransactions.map((transaction) {
                      return ListTile(
                        leading: AppIcons.getTransactionAvatar(
                          transaction.isSold,
                          size: 40,
                        ),
                        title: Text(
                          '${NumberFormatter.formatQuantity(transaction.quantity)} Aktien',
                        ),
                        subtitle: Text(
                          DateFormat('dd.MM.yyyy').format(transaction.purchaseDate),
                        ),
                        trailing: Text(
                          '\$${transaction.fmvPerShare.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Fehler: $error'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}