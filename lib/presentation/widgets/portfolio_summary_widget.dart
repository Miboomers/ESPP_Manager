import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction_model.dart';
import '../../core/utils/number_formatter.dart';
import '../../core/utils/market_hours.dart';
import '../providers/stock_price_provider.dart';
import '../providers/settings_provider.dart';

class PortfolioSummaryWidget extends ConsumerWidget {
  final List<TransactionModel> openPositions;
  final double exchangeRate;
  final bool includeMargin;
  
  const PortfolioSummaryWidget({
    super.key,
    required this.openPositions,
    required this.exchangeRate,
    this.includeMargin = true, // Standard: mit Margin für HomeScreen
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalShares = openPositions.fold<double>(0, (sum, t) => sum + t.quantity);
    final totalInvested = openPositions.fold<double>(0, (sum, t) => sum + t.totalPurchaseCost);
    final totalDiscount = openPositions.fold<double>(0, (sum, t) => sum + t.totalDiscount);
    
    // Berechnungen für FMV-basierten Wert (ohne ESPP-Rabatt für Kapitalertragsteuer)
    final totalFMVCost = openPositions.fold<double>(0, (sum, t) => sum + (t.fmvPerShare * t.quantity));
    
    final totalDiscountEUR = totalDiscount * exchangeRate;
    final incomeTax = totalDiscount * 0.42; // Default 42% income tax
    
    // Aktuellen Marktwert berechnen
    final settings = ref.watch(settingsProvider).valueOrNull;
    final symbol = settings?.defaultStockSymbol ?? 'AAPL';
    final stockPriceAsync = ref.watch(stockPriceProvider(symbol));

    return Card(
      margin: includeMargin ? const EdgeInsets.all(16) : EdgeInsets.zero,
      color: Colors.blue.withValues(alpha: 0.1), // Heller blauer Hintergrund
      elevation: 0, // Kein Schatten
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.1), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Portfolio Übersicht',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 8), // Platz zwischen Text und Kurs
                Flexible(
                  child: stockPriceAsync.when(
                  data: (stockPrice) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stockPrice.symbol}: \$${stockPrice.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        '${stockPrice.changePercent >= 0 ? '+' : ''}${stockPrice.changePercent.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: stockPrice.changePercent >= 0 ? Colors.green : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${stockPrice.timestamp.day}.${stockPrice.timestamp.month}.${stockPrice.timestamp.year} ${stockPrice.timestamp.hour.toString().padLeft(2, '0')}:${stockPrice.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                      Text(
                        MarketHours.getMarketStatus(stockPrice.symbol),
                        style: TextStyle(
                          color: MarketHours.isMarketOpen(stockPrice.symbol) ? Colors.green : Colors.grey[600],
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(width: 80, height: 40),
                  error: (error, stack) => GestureDetector(
                    onTap: () => _showDebugInfo(context, symbol, error.toString()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Kurs nicht verfügbar',
                          style: TextStyle(color: Colors.red[600], fontSize: 10),
                        ),
                        Text(
                          '(Tap für Details)',
                          style: TextStyle(color: Colors.grey[400], fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aktueller Wert', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          stockPriceAsync.when(
                            data: (stockPrice) {
                              final currentValue = totalShares * stockPrice.price;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('€${(currentValue * exchangeRate).toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('\$${currentValue.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              );
                            },
                            loading: () => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('€${(totalInvested * exchangeRate).toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('\$${totalInvested.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ],
                            ),
                            error: (_, __) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('€${(totalInvested * exchangeRate).toStringAsFixed(2)}', style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('\$${totalInvested.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Investiert', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('€${(totalInvested * exchangeRate).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('\$${totalInvested.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
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
                          Text('Anzahl Aktien', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(NumberFormatter.formatQuantity(totalShares), style: const TextStyle(color: Colors.purple, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lohnsteuer', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('€${(incomeTax * exchangeRate).toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('\$${incomeTax.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
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
                          Text('ESPP Rabatt', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('€${totalDiscountEUR.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('\$${totalDiscount.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: stockPriceAsync.when(
                        data: (stockPrice) {
                          final currentValue = totalShares * stockPrice.price;
                          final currentValueEUR = currentValue * exchangeRate;
                          
                          // Investierter Betrag in EUR mit historischen Wechselkursen (wie Einzelpositionen)
                          final totalInvestedEUR = openPositions.fold<double>(0, (sum, t) => 
                            sum + (t.totalPurchaseCost * (t.exchangeRateAtPurchase ?? exchangeRate)));
                          
                          final totalGainEUR = currentValueEUR - totalInvestedEUR;
                          final totalGainUSD = currentValue - totalInvested;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gesamtgewinn', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              Text('€${totalGainEUR.toStringAsFixed(2)}', 
                                style: TextStyle(
                                  color: totalGainEUR >= 0 ? Colors.green : Colors.red, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                              Text('\$${totalGainUSD.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            ],
                          );
                        },
                        loading: () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gesamtgewinn', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('€0.00', style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('\$0.00', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                        error: (_, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gesamtgewinn', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('€0.00', style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('\$0.00', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: stockPriceAsync.when(
                        data: (stockPrice) {
                          final currentValue = totalShares * stockPrice.price;
                          // Steuerpflichtiger Kapitalgewinn: Aktueller Wert minus FMV-Kostenbasis (ohne ESPP-Rabatt)
                          final taxableGainUSD = currentValue - totalFMVCost;
                          final taxableGainEUR = taxableGainUSD * exchangeRate;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kapitalgewinn (steuerpflichtig)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              Text('€${taxableGainEUR.toStringAsFixed(2)}', 
                                style: TextStyle(
                                  color: taxableGainEUR >= 0 ? Colors.orange : Colors.red, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                              Text('\$${taxableGainUSD.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                            ],
                          );
                        },
                        loading: () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kapitalgewinn (steuerpflichtig)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('€0.00', style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('\$0.00', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                        error: (_, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kapitalgewinn (steuerpflichtig)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('€0.00', style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('\$0.00', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: stockPriceAsync.when(
                        data: (stockPrice) {
                          final currentValue = totalShares * stockPrice.price;
                          final taxableGainUSD = currentValue - totalFMVCost;
                          final taxableGainEUR = taxableGainUSD * exchangeRate;
                          final capitalGainsTax = taxableGainEUR > 0 ? taxableGainEUR * 0.25 : 0.0; // 25% Kapitalertragsteuer
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kapitalertragsteuer (25%)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              Text('€${capitalGainsTax.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text('auf €${taxableGainEUR.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                            ],
                          );
                        },
                        loading: () => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kapitalertragsteuer (25%)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('€0.00', style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('auf €0.00', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                          ],
                        ),
                        error: (_, __) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kapitalertragsteuer (25%)', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            Text('€0.00', style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('auf €0.00', style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showDebugInfo(BuildContext context, String symbol, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('API Debug Info - $symbol'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Symbol: $symbol', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Fehler:', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(error, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Mögliche Ursachen:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('• Alpha Vantage API Rate Limit (5 calls/min)', style: TextStyle(fontSize: 12)),
              const Text('• Netzwerkverbindung unterbrochen', style: TextStyle(fontSize: 12)),
              const Text('• API Server nicht erreichbar', style: TextStyle(fontSize: 12)),
              const Text('• Ungültiges Aktien-Symbol', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              const Text('Fallback:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('App nutzt Mock-Daten aus dem Code', style: TextStyle(fontSize: 12)),
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