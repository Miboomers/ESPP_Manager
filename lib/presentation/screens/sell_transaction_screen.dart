import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../providers/stock_price_provider.dart';
import '../../core/utils/number_formatter.dart';

class SellTransactionScreen extends ConsumerStatefulWidget {
  const SellTransactionScreen({super.key});

  @override
  ConsumerState<SellTransactionScreen> createState() => _SellTransactionScreenState();
}

class _SellTransactionScreenState extends ConsumerState<SellTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _saleDateController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _quantityToSellController = TextEditingController();
  final _exchangeRateSaleController = TextEditingController();
  
  DateTime? _saleDate;
  String? _selectedTransactionId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Set today's date as default
    _saleDate = DateTime.now();
    _saleDateController.text = DateFormat('dd.MM.yyyy').format(_saleDate!);
    
    // Default exchange rate
    _exchangeRateSaleController.text = '0.92';
    
    // Fetch current exchange rate
    _fetchCurrentExchangeRate();
    
    // Add listeners for live preview updates
    _quantityToSellController.addListener(() => setState(() {}));
    _salePriceController.addListener(() => setState(() {}));
    _exchangeRateSaleController.addListener(() => setState(() {}));
  }

  TransactionModel? _getSelectedTransaction(List<TransactionModel> transactions) {
    if (_selectedTransactionId == null) return null;
    try {
      return transactions.firstWhere((t) => t.id == _selectedTransactionId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktien verkaufen'),
      ),
      body: Form(
        key: _formKey,
        child: transactionsAsync.when(
          data: (transactions) {
            final openPositions = transactions.where((t) => !t.isSold).toList();
            
            if (openPositions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, 
                         size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Keine offenen Positionen zum Verkauf'),
                  ],
                ),
              );
            }
            
            final selectedTransaction = _getSelectedTransaction(openPositions);
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPositionSelector(openPositions),
                  if (selectedTransaction != null) ...[
                    const SizedBox(height: 16),
                    _buildTransactionDetails(selectedTransaction),
                    const SizedBox(height: 16),
                    _buildSaleDetailsForm(selectedTransaction),
                    const SizedBox(height: 16),
                    _buildPreview(selectedTransaction),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Fehler: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionSelector(List<TransactionModel> openPositions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position auswählen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedTransactionId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Offene Position',
                hintText: 'Wählen Sie eine Position zum Verkauf',
              ),
              selectedItemBuilder: (BuildContext context) {
                return openPositions.map<Widget>((TransactionModel transaction) {
                  return Text(
                    '${NumberFormatter.formatQuantity(transaction.quantity)} Aktien - ${DateFormat('dd.MM.yyyy').format(transaction.purchaseDate)}',
                    overflow: TextOverflow.ellipsis,
                  );
                }).toList();
              },
              items: openPositions.map((transaction) {
                return DropdownMenuItem<String>(
                  value: transaction.id,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${NumberFormatter.formatQuantity(transaction.quantity)} Aktien - ${DateFormat('dd.MM.yyyy').format(transaction.purchaseDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kaufpreis: \$${NumberFormatter.formatCurrency(transaction.purchasePricePerShare)} | FMV: \$${NumberFormatter.formatCurrency(transaction.fmvPerShare)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() {
                  _selectedTransactionId = value;
                  if (value != null) {
                    final transaction = openPositions.firstWhere((t) => t.id == value);
                    // Pre-fill quantity with full amount
                    _quantityToSellController.text = 
                        NumberFormatter.formatQuantity(transaction.quantity);
                  }
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Bitte wählen Sie eine Position aus';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionDetails(TransactionModel transaction) {
    return Card(
      color: Colors.blue.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Positionsdetails',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Kaufdatum:', 
                DateFormat('dd.MM.yyyy').format(transaction.purchaseDate)),
            _buildDetailRow('Anzahl:', 
                '${NumberFormatter.formatQuantity(transaction.quantity)} Aktien'),
            _buildDetailRow('Kaufpreis:', 
                '\$${NumberFormatter.formatCurrency(transaction.purchasePricePerShare)}'),
            _buildDetailRow('FMV beim Kauf:', 
                '\$${NumberFormatter.formatCurrency(transaction.fmvPerShare)}'),
            _buildDetailRow('ESPP Rabatt:', 
                '\$${NumberFormatter.formatCurrency(transaction.discount)} pro Aktie'),
            _buildDetailRow('Gesamtinvestition:', 
                '\$${NumberFormatter.formatCurrency(transaction.totalPurchaseCost)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCurrencyComparisonRow(String label, String value, String description, {bool isHighlighted = false, bool isNegative = false}) {
    Color textColor = isNegative ? Colors.red[700]! : (isHighlighted ? Colors.green[700]! : Colors.grey[700]!);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              description,
              style: TextStyle(fontSize: 9, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaleDetailsForm(TransactionModel transaction) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verkaufsdetails',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _saleDateController,
              decoration: const InputDecoration(
                labelText: 'Verkaufsdatum',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () => _selectDate(context, transaction.purchaseDate),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Verkaufsdatum ist erforderlich';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityToSellController,
              decoration: InputDecoration(
                labelText: 'Anzahl zu verkaufen',
                helperText: 'Max: ${NumberFormatter.formatQuantity(transaction.quantity)}',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Anzahl ist erforderlich';
                }
                final quantity = NumberFormatter.parseGermanNumber(value);
                if (quantity == null || quantity <= 0) {
                  return 'Ungültige Anzahl';
                }
                if (quantity > transaction.quantity) {
                  return 'Anzahl übersteigt verfügbare Aktien';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _salePriceController,
              decoration: const InputDecoration(
                labelText: 'Verkaufspreis pro Aktie (USD)',
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Verkaufspreis ist erforderlich';
                }
                final price = NumberFormatter.parseGermanNumber(value);
                if (price == null || price <= 0) {
                  return 'Ungültiger Verkaufspreis';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _exchangeRateSaleController,
                    decoration: const InputDecoration(
                      labelText: 'USD/EUR Kurs',
                      helperText: '1 USD = x EUR',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Wechselkurs erforderlich';
                      }
                      final rate = NumberFormatter.parseGermanNumber(value);
                      if (rate == null || rate <= 0) {
                        return 'Ungültiger Kurs';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchCurrentExchangeRate,
                  tooltip: 'Aktuellen Kurs laden',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(TransactionModel transaction) {
    final quantity = NumberFormatter.parseGermanNumber(_quantityToSellController.text) ?? 0;
    final salePrice = NumberFormatter.parseGermanNumber(_salePriceController.text) ?? 0;
    final exchangeRate = NumberFormatter.parseGermanNumber(_exchangeRateSaleController.text) ?? 0.92;
    
    if (quantity <= 0 || salePrice <= 0) {
      return const SizedBox();
    }
    
    final totalSaleProceeds = quantity * salePrice;
    final purchaseCost = quantity * transaction.purchasePricePerShare;
    final incomeTaxOnDiscount = quantity * transaction.discount * transaction.incomeTaxRate;
    
    // EUR-based capital gains calculation (for German tax law)
    final purchaseValueEUR = transaction.fmvPerShare * quantity * (transaction.exchangeRateAtPurchase ?? 0.92);
    final saleValueEUR = salePrice * quantity * exchangeRate;
    final capitalGainEUR = saleValueEUR - purchaseValueEUR;
    final capitalGainsTaxEUR = capitalGainEUR > 0 ? capitalGainEUR * transaction.capitalGainsTaxRate : 0;
    
    // Net profit calculation using correct EUR-based tax
    final netProfitUSD = totalSaleProceeds - purchaseCost - incomeTaxOnDiscount - (capitalGainsTaxEUR / exchangeRate);
    final netProfitEUR = netProfitUSD * exchangeRate;
    
    return Card(
      color: netProfitUSD >= 0 
          ? Colors.green.withValues(alpha: 0.05) 
          : Colors.red.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verkaufsübersicht',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Verkaufserlös:', 
                '\$${NumberFormatter.formatCurrency(totalSaleProceeds)}'),
            _buildDetailRow('Kaufkosten:', 
                '-\$${NumberFormatter.formatCurrency(purchaseCost)}'),
            _buildDetailRow('Lohnsteuer (Rabatt):', 
                '-\$${NumberFormatter.formatCurrency(incomeTaxOnDiscount)}'),
            
            // Show currency impact on capital gains
            if (capitalGainEUR > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kapitalertragsteuer (Deutsche Steuerberechnung):',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800], fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    _buildCurrencyComparisonRow(
                      'Kauf (EUR-Basis):',
                      '€${NumberFormatter.formatCurrency(purchaseValueEUR)}',
                      'FMV × Menge × Kurs beim Kauf',
                    ),
                    const SizedBox(height: 4),
                    _buildCurrencyComparisonRow(
                      'Verkauf (EUR-Basis):',
                      '€${NumberFormatter.formatCurrency(saleValueEUR)}',
                      'Verkaufspreis × Menge × Kurs beim Verkauf',
                    ),
                    const SizedBox(height: 4),
                    _buildCurrencyComparisonRow(
                      'Kapitalgewinn (EUR):',
                      '€${NumberFormatter.formatCurrency(capitalGainEUR)}',
                      'Relevant für deutsche Steuererklärung',
                      isHighlighted: true,
                    ),
                    const SizedBox(height: 4),
                    _buildCurrencyComparisonRow(
                      'Steuer (25%):',
                      '-€${NumberFormatter.formatCurrency(capitalGainsTaxEUR.toDouble())}',
                      'Kapitalertragsteuer auf EUR-Basis',
                      isNegative: true,
                    ),
                  ],
                ),
              ),
            ],
            
            const Divider(),
            _buildDetailRow('Nettogewinn (EUR):', 
                '€${NumberFormatter.formatCurrency(netProfitEUR)}'),
            _buildDetailRow('Nettogewinn (USD):', 
                '(\$${NumberFormatter.formatCurrency(netProfitUSD)})'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.currency_exchange, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Wechselkurse dokumentiert:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kauf: 1 USD = ${(transaction.exchangeRateAtPurchase ?? 0.92).toStringAsFixed(4)} EUR',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  Text(
                    'Verkauf: 1 USD = ${exchangeRate.toStringAsFixed(4)} EUR',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveTransaction,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verkauf speichern'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, DateTime minDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _saleDate ?? DateTime.now(),
      firstDate: minDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _saleDate) {
      setState(() {
        _saleDate = picked;
        _saleDateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Future<void> _fetchCurrentExchangeRate() async {
    try {
      final usdEurRateAsync = ref.read(usdEurRateProvider.future);
      final exchangeRateModel = await usdEurRateAsync;
      final rate = exchangeRateModel.rate;
      
      _exchangeRateSaleController.text = rate.toStringAsFixed(4);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Live-Wechselkurs: 1 USD = ${rate.toStringAsFixed(4)} EUR'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _exchangeRateSaleController.text = '0.92';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Standard-Wechselkurs verwendet: 1 USD = 0.92 EUR'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTransactionId == null) return;

    setState(() => _isLoading = true);

    try {
      final transactionsAsync = ref.read(transactionsProvider);
      final transactions = transactionsAsync.valueOrNull ?? [];
      final selectedTransaction = transactions.firstWhere((t) => t.id == _selectedTransactionId);
      
      final quantityToSell = NumberFormatter.parseGermanNumber(_quantityToSellController.text)!;
      final salePrice = NumberFormatter.parseGermanNumber(_salePriceController.text)!;
      final exchangeRate = NumberFormatter.parseGermanNumber(_exchangeRateSaleController.text)!;
      
      // Check if selling full or partial position
      if (quantityToSell == selectedTransaction.quantity) {
        // Full sale - update existing transaction
        final updatedTransaction = selectedTransaction.copyWith(
          saleDate: _saleDate,
          salePricePerShare: salePrice,
          exchangeRateAtSale: exchangeRate,
          type: TransactionType.sale,
          updatedAt: DateTime.now(),
        );
        
        await ref.read(transactionsProvider.notifier).updateTransaction(updatedTransaction);
      } else {
        // Partial sale - create new transaction for sold portion
        final soldTransaction = TransactionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          purchaseDate: selectedTransaction.purchaseDate,
          saleDate: _saleDate,
          quantity: quantityToSell,
          fmvPerShare: selectedTransaction.fmvPerShare,
          purchasePricePerShare: selectedTransaction.purchasePricePerShare,
          salePricePerShare: salePrice,
          incomeTaxRate: selectedTransaction.incomeTaxRate,
          capitalGainsTaxRate: selectedTransaction.capitalGainsTaxRate,
          exchangeRateAtPurchase: selectedTransaction.exchangeRateAtPurchase,
          exchangeRateAtSale: exchangeRate,
          type: TransactionType.sale,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Update original transaction with reduced quantity
        final remainingQuantity = selectedTransaction.quantity - quantityToSell;
        final updatedOriginal = selectedTransaction.copyWith(
          quantity: remainingQuantity,
          updatedAt: DateTime.now(),
        );
        
        await ref.read(transactionsProvider.notifier).addTransaction(soldTransaction);
        await ref.read(transactionsProvider.notifier).updateTransaction(updatedOriginal);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verkauf erfolgreich gespeichert'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _saleDateController.dispose();
    _salePriceController.dispose();
    _quantityToSellController.dispose();
    _exchangeRateSaleController.dispose();
    super.dispose();
  }
}