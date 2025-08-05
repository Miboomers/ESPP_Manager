import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../providers/stock_price_provider.dart';
import '../providers/settings_provider.dart';
import 'add_purchase_screen.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/app_icons.dart';
import '../widgets/common_bottom_action_bar.dart';
import '../widgets/portfolio_summary_widget.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide sell button
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Offene Positionen'),
            Tab(text: 'Verkaufte Positionen'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(stockPriceProvider);
              ref.invalidate(transactionsProvider);
            },
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) => TabBarView(
          controller: _tabController,
          children: [
            _buildOpenPositions(transactions, settings),
            _buildSoldPositions(transactions, settings),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Fehler: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(transactionsProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CommonBottomActionBar(), // Immer beide Buttons
    );
  }

  Widget _buildOpenPositions(List<TransactionModel> transactions, settings) {
    final openPositions = transactions.where((t) => !t.isSold).toList();
    
    if (openPositions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Keine offenen Positionen'),
            SizedBox(height: 8),
            Text('Fügen Sie Ihre erste Transaktion hinzu'),
          ],
        ),
      );
    }

    // Verwende ListView wie im HomeScreen für vollständige Scrollbarkeit
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100), // Extra bottom padding for action bar
      itemCount: openPositions.length + 1, // +1 für Portfolio Summary
      itemBuilder: (context, index) {
        if (index == 0) {
          // Portfolio Summary als erstes Element - kein zusätzliches Padding
          return _buildPortfolioSummaryNew(openPositions, ref);
        }
        // Position Cards ab Index 1
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildPositionCard(openPositions[index - 1], settings, true),
        );
      },
    );
  }

  Widget _buildPortfolioSummaryNew(List<TransactionModel> openPositions, WidgetRef ref) {
    final exchangeRateAsync = ref.watch(usdEurRateProvider);
    final exchangeRate = exchangeRateAsync.valueOrNull?.rate ?? 0.92;
    
    return PortfolioSummaryWidget(
      openPositions: openPositions,
      exchangeRate: exchangeRate,
      includeMargin: true, // Behält seinen eigenen Margin - wie im HomeScreen
    );
  }

  Widget _buildSoldPositions(List<TransactionModel> transactions, settings) {
    final soldPositions = transactions.where((t) => t.isSold).toList();
    
    if (soldPositions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Keine verkauften Positionen'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Extra bottom padding for action bar
      itemCount: soldPositions.length,
      itemBuilder: (context, index) {
        return _buildPositionCard(soldPositions[index], settings, false);
      },
    );
  }



  Widget _buildPositionCard(TransactionModel transaction, settings, bool isOpen) {
    // Wechselkurs für EUR-Berechnungen
    final exchangeRateAsync = ref.watch(usdEurRateProvider);
    final exchangeRate = exchangeRateAsync.valueOrNull?.rate ?? 0.92;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPurchaseScreen(
                existingTransaction: transaction,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${NumberFormatter.formatQuantity(transaction.quantity)} Aktien',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (isOpen)
                    Consumer(
                      builder: (context, ref, child) {
                        final settings = ref.watch(settingsProvider).valueOrNull;
                        final symbol = settings?.defaultStockSymbol ?? 'AAPL';
                        final stockPriceAsync = ref.watch(stockPriceProvider(symbol));
                        return stockPriceAsync.when(
                          data: (stockPrice) => _buildLivePrice(stockPrice.price, stockPrice.changePercent),
                          loading: () => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => const Text('--'),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Kaufdatum und ggf. Verkaufsdatum
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kaufdatum:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  Text(DateFormat('dd.MM.yyyy').format(transaction.purchaseDate)),
                ],
              ),
              if (transaction.saleDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Verkaufsdatum:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    Text(DateFormat('dd.MM.yyyy').format(transaction.saleDate!)),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Preise im Portfolio-Stil (EUR groß, USD klein)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kaufpreis', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        Text(
                          '€${(transaction.purchasePricePerShare * (transaction.exchangeRateAtPurchase ?? exchangeRate)).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${transaction.purchasePricePerShare.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FMV', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        Text(
                          '€${(transaction.fmvPerShare * (transaction.exchangeRateAtPurchase ?? exchangeRate)).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.purple, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${transaction.fmvPerShare.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (transaction.salePricePerShare != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Verkaufspreis', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(
                            '€${(transaction.salePricePerShare! * (transaction.exchangeRateAtSale ?? exchangeRate)).toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.indigo, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${transaction.salePricePerShare!.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: Container()), // Leer für symmetrisches Layout
                  ],
                ),
              ],
              
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('USD/EUR Kauf', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        Text(
                          '${(transaction.exchangeRateAtPurchase ?? 0.92).toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (transaction.exchangeRateAtSale != null) ...[
                          Text('USD/EUR Verkauf', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          Text(
                            '${transaction.exchangeRateAtSale!.toStringAsFixed(4)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 20),
              
              // ESPP Rabatt und Steuern im Portfolio-Stil
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ESPP Rabatt', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        Text(
                          '€${(transaction.totalDiscount * (transaction.exchangeRateAtPurchase ?? exchangeRate)).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${transaction.totalDiscount.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lohnsteuer', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        Text(
                          '€${(transaction.incomeTaxOnDiscount * (transaction.exchangeRateAtPurchase ?? exchangeRate)).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '\$${transaction.incomeTaxOnDiscount.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              if (transaction.totalGainEUR != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kapitalgewinn', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(
                            '€${transaction.totalGainEUR!.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: transaction.totalGainEUR! >= 0 ? Colors.green : Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${(transaction.totalCapitalGainUSD ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (transaction.capitalGainsTaxEUR != null && transaction.capitalGainsTaxEUR! > 0)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kapitalertragsteuer', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text(
                              '€${transaction.capitalGainsTaxEUR!.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '\$${(transaction.capitalGainsTax ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(child: Container()),
                  ],
                ),
              ],
              
              // Kapitalgewinn und -steuer für offene Positionen (basierend auf aktuellem Kurs)
              if (isOpen)
                _buildOpenPositionGainsAndTaxes(transaction, exchangeRate),
              
              if (isOpen)
                _buildCurrentValue(transaction),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePrice(double price, double changePercent) {
    final isPositive = changePercent >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '\$${price.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
          style: TextStyle(
            color: isPositive ? Colors.green : Colors.red,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildOpenPositionGainsAndTaxes(TransactionModel transaction, double exchangeRate) {
    return Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(settingsProvider).valueOrNull;
        final symbol = settings?.defaultStockSymbol ?? 'AAPL';
        final stockPriceAsync = ref.watch(stockPriceProvider(symbol));
        
        return stockPriceAsync.when(
          data: (stockPrice) {
            // Berechne hypothetischen Kapitalgewinn bei Verkauf zum aktuellen Kurs
            final currentSalePricePerShare = stockPrice.price;
            final currentSaleValueUSD = currentSalePricePerShare * transaction.quantity;
            final currentSaleValueEUR = currentSaleValueUSD * exchangeRate;
            
            // STEUERPFLICHTIGER Kapitalgewinn (FMV-basiert für deutsche Steuer)
            final fmvCostEUR = transaction.fmvPerShare * transaction.quantity * (transaction.exchangeRateAtPurchase ?? exchangeRate);
            final fmvCostUSD = transaction.fmvPerShare * transaction.quantity;
            final taxableCapitalGainEUR = currentSaleValueEUR - fmvCostEUR;
            final taxableCapitalGainUSD = currentSaleValueUSD - fmvCostUSD;
            
            // Kapitalertragsteuer nur wenn steuerpflichtiger Gewinn > 0
            final potentialCapitalGainsTaxEUR = taxableCapitalGainEUR > 0 ? taxableCapitalGainEUR * transaction.capitalGainsTaxRate : 0.0;
            final potentialCapitalGainsTaxUSD = taxableCapitalGainUSD > 0 ? taxableCapitalGainUSD * transaction.capitalGainsTaxRate : 0.0;
            
            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Potentielle Werte bei Verkauf (aktueller Kurs: \$${currentSalePricePerShare.toStringAsFixed(2)})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Kapitalgewinn (steuerpflichtig) und Kapitalertragsteuer
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kapitalgewinn (steuerpflichtig)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text(
                              '€${taxableCapitalGainEUR.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: taxableCapitalGainEUR >= 0 ? Colors.orange : Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${taxableCapitalGainUSD.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (potentialCapitalGainsTaxEUR > 0)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kapitalertragsteuer', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              Text(
                                '€${potentialCapitalGainsTaxEUR.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '\$${potentialCapitalGainsTaxUSD.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kapitalertragsteuer', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              Text(
                                '€0.00',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '\$0.00',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            child: Text(
              'Kapitalgewinn-Berechnung nicht verfügbar (Kein aktueller Kurs)',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentValue(TransactionModel transaction) {
    return Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(settingsProvider).valueOrNull;
        final symbol = settings?.defaultStockSymbol ?? 'AAPL';
        final stockPriceAsync = ref.watch(stockPriceProvider(symbol));
        final exchangeRateAsync = ref.watch(usdEurRateProvider);
        final exchangeRate = exchangeRateAsync.valueOrNull?.rate ?? 0.92;
        
        return stockPriceAsync.when(
          data: (stockPrice) {
            final currentValueUSD = stockPrice.price * transaction.quantity;
            final currentValueEUR = currentValueUSD * exchangeRate;
            final totalInvestedUSD = transaction.totalPurchaseCost;
            final totalInvestedEUR = totalInvestedUSD * (transaction.exchangeRateAtPurchase ?? exchangeRate);
            final unrealizedGainUSD = currentValueUSD - totalInvestedUSD;
            final unrealizedGainEUR = currentValueEUR - totalInvestedEUR;
            final unrealizedGainPercent = (unrealizedGainUSD / totalInvestedUSD) * 100;

            return Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: unrealizedGainUSD >= 0 
                    ? Colors.green.withValues(alpha: 0.1) 
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Aktueller Wert', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text(
                              '€${currentValueEUR.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '\$${currentValueUSD.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Unreal. Gewinn/Verlust', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text(
                              '€${unrealizedGainEUR.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: unrealizedGainUSD >= 0 ? Colors.green : Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '\$${unrealizedGainUSD.toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${unrealizedGainPercent.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    color: unrealizedGainUSD >= 0 ? Colors.green : Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          loading: () => Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            child: const Text('Kursdaten nicht verfügbar'),
          ),
        );
      },
    );
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}