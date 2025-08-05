import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/transaction_model.dart';
import '../providers/transactions_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_price_provider.dart';
import '../../core/utils/number_formatter.dart';

class AddPurchaseScreen extends ConsumerStatefulWidget {
  final TransactionModel? existingTransaction;

  const AddPurchaseScreen({
    super.key,
    this.existingTransaction,
  });

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purchaseDateController = TextEditingController();
  final _quantityController = TextEditingController();
  final _fmvController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _discountRateController = TextEditingController();
  final _incomeTaxRateController = TextEditingController();
  final _capitalGainsTaxRateController = TextEditingController();
  final _exchangeRatePurchaseController = TextEditingController();

  DateTime? _purchaseDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.existingTransaction != null) {
      final transaction = widget.existingTransaction!;
      _purchaseDate = transaction.purchaseDate;
      
      _purchaseDateController.text = DateFormat('dd.MM.yyyy').format(transaction.purchaseDate);
      _quantityController.text = NumberFormatter.formatQuantity(transaction.quantity);
      _fmvController.text = transaction.fmvPerShare.toStringAsFixed(2);
      _purchasePriceController.text = transaction.purchasePricePerShare.toStringAsFixed(2);
      _incomeTaxRateController.text = (transaction.incomeTaxRate * 100).toStringAsFixed(0);
      _capitalGainsTaxRateController.text = (transaction.capitalGainsTaxRate * 100).toStringAsFixed(0);
      _discountRateController.text = ((1 - transaction.purchasePricePerShare / transaction.fmvPerShare) * 100).toStringAsFixed(0);
      if (transaction.exchangeRateAtPurchase != null) {
        _exchangeRatePurchaseController.text = transaction.exchangeRateAtPurchase!.toStringAsFixed(4);
      }
    }
    
    // Add listeners for auto-calculation
    _fmvController.addListener(_calculatePurchasePrice);
    _discountRateController.addListener(_calculatePurchasePrice);
    _quantityController.addListener(() => setState(() {}));
    _incomeTaxRateController.addListener(() => setState(() {}));
    _capitalGainsTaxRateController.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    
    // Set default values from settings when available
    settingsAsync.whenData((settings) {
      if (_incomeTaxRateController.text.isEmpty && widget.existingTransaction == null) {
        _incomeTaxRateController.text = (settings.defaultIncomeTaxRate * 100).toStringAsFixed(0);
      }
      if (_capitalGainsTaxRateController.text.isEmpty && widget.existingTransaction == null) {
        _capitalGainsTaxRateController.text = (settings.defaultCapitalGainsTaxRate * 100).toStringAsFixed(0);
      }
      if (_discountRateController.text.isEmpty && widget.existingTransaction == null) {
        _discountRateController.text = (settings.defaultEsppDiscountRate * 100).toStringAsFixed(0);
      }
    });
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTransaction != null 
            ? 'ESPP Kauf bearbeiten' 
            : 'ESPP Kauf hinzufügen'),
        actions: [
          if (widget.existingTransaction != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteDialog,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPurchaseHeader(),
                const SizedBox(height: 16),
                _buildBasicInfoSection(),
                const SizedBox(height: 16),
                _buildPricesSection(),
                const SizedBox(height: 16),
                _buildTaxSection(),
                const SizedBox(height: 16),
                _buildExchangeRateSection(),
                const SizedBox(height: 16),
                _buildPreview(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurchaseHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ESPP Aktienkauf',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart_outlined, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Neue Aktien hinzufügen',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Grunddaten',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _purchaseDateController,
              decoration: const InputDecoration(
                labelText: 'Kaufdatum',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kaufdatum ist erforderlich';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Anzahl Aktien',
                helperText: 'Bruchteile bis 4 Nachkommastellen (z.B. 36.1446)',
                prefixIcon: Icon(Icons.shopping_cart_outlined),
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
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preise (USD)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fmvController,
              decoration: const InputDecoration(
                labelText: 'Fair Market Value pro Aktie',
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'FMV ist erforderlich';
                }
                final fmv = NumberFormatter.parseGermanNumber(value);
                if (fmv == null || fmv <= 0) {
                  return 'Ungültiger FMV';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discountRateController,
              decoration: const InputDecoration(
                labelText: 'ESPP Rabatt',
                suffixText: '%',
                helperText: 'Wird automatisch aus den Einstellungen geladen',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Rabattsatz ist erforderlich';
                }
                final rate = NumberFormatter.parseGermanNumber(value);
                if (rate == null || rate < 0 || rate > 100) {
                  return 'Ungültiger Rabattsatz (0-100%)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _purchasePriceController,
              decoration: const InputDecoration(
                labelText: 'Kaufpreis pro Aktie (automatisch berechnet)',
                prefixText: '\$ ',
                helperText: 'FMV × (1 - Rabatt%)',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              readOnly: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kaufpreis ist erforderlich';
                }
                final price = NumberFormatter.parseGermanNumber(value);
                if (price == null || price <= 0) {
                  return 'Ungültiger Kaufpreis';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Steuersätze',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _incomeTaxRateController,
              decoration: const InputDecoration(
                labelText: 'Lohnsteuersatz',
                suffixText: '%',
                helperText: 'Für ESPP Rabatt',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lohnsteuersatz ist erforderlich';
                }
                final rate = NumberFormatter.parseGermanNumber(value);
                if (rate == null || rate < 0 || rate > 100) {
                  return 'Ungültiger Steuersatz (0-100%)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _capitalGainsTaxRateController,
              decoration: const InputDecoration(
                labelText: 'Kapitalertragsteuersatz',
                suffixText: '%',
                helperText: 'Für Kursgewinne',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kapitalertragsteuersatz ist erforderlich';
                }
                final rate = NumberFormatter.parseGermanNumber(value);
                if (rate == null || rate < 0 || rate > 100) {
                  return 'Ungültiger Steuersatz (0-100%)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeRateSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wechselkurs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _exchangeRatePurchaseController,
                    decoration: const InputDecoration(
                      labelText: 'USD/EUR Kurs beim Kauf',
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

  Widget _buildPreview() {
    final quantity = NumberFormatter.parseGermanNumber(_quantityController.text) ?? 0;
    final fmv = NumberFormatter.parseGermanNumber(_fmvController.text) ?? 0;
    final purchasePrice = NumberFormatter.parseGermanNumber(_purchasePriceController.text) ?? 0;
    final incomeTaxRate = NumberFormatter.parseGermanNumber(_incomeTaxRateController.text) ?? 0;
    final exchangeRate = NumberFormatter.parseGermanNumber(_exchangeRatePurchaseController.text) ?? 0.92;
    
    if (quantity <= 0 || fmv <= 0 || purchasePrice <= 0) {
      return const SizedBox();
    }
    
    final totalMarketValue = quantity * fmv;
    final totalActualCost = quantity * purchasePrice;
    final totalDiscount = quantity * (fmv - purchasePrice);
    final incomeTax = totalDiscount * (incomeTaxRate / 100);
    
    final totalMarketValueEUR = totalMarketValue * exchangeRate;
    final totalActualCostEUR = totalActualCost * exchangeRate;
    final totalDiscountEUR = totalDiscount * exchangeRate;
    final incomeTaxEUR = incomeTax * exchangeRate;
    
    return Card(
      color: Colors.blue.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'ESPP Kaufübersicht',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Vergleichen Sie diese Werte mit Ihrer ESPP-Abrechnung',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            
            // Marktwert vs. Tatsächliche Kosten
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildComparisonRow('Marktwert (FMV × Anzahl):', 
                      '\$${NumberFormatter.formatCurrency(totalMarketValue)}',
                      '€${NumberFormatter.formatCurrency(totalMarketValueEUR)}',
                      'Theoretischer Wert ohne ESPP-Rabatt'),
                  const SizedBox(height: 8),
                  _buildComparisonRow('Tatsächliche Kosten:', 
                      '\$${NumberFormatter.formatCurrency(totalActualCost)}',
                      '€${NumberFormatter.formatCurrency(totalActualCostEUR)}',
                      'Was Sie wirklich bezahlen (mit ESPP-Rabatt)', 
                      isHighlighted: true),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            
            // ESPP Vorteil
            _buildBenefitRow('ESPP Rabatt (Vorteil):', 
                '\$${NumberFormatter.formatCurrency(totalDiscount)}',
                '€${NumberFormatter.formatCurrency(totalDiscountEUR)}',
                'Ihr Gewinn durch den ESPP-Rabatt'),
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            
            // Steuerliche Auswirkungen (EUR primär)
            Text(
              'Steuerliche Auswirkungen (Deutschland):',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[700]),
            ),
            const SizedBox(height: 8),
            _buildTaxRow('Lohnsteuer auf Rabatt:', 
                '€${NumberFormatter.formatCurrency(incomeTaxEUR)}',
                '\$${NumberFormatter.formatCurrency(incomeTax)}',
                'Sofort fällig auf den ESPP-Vorteil'),
            
            const SizedBox(height: 12),
            _buildExchangeRateInfo(exchangeRate),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, String usdValue, String eurValue, String description, {bool isHighlighted = false}) {
    return Container(
      padding: isHighlighted ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: isHighlighted ? BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ) : null,
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
                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                    color: isHighlighted ? Colors.green[800] : Colors.grey[700],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(usdValue, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isHighlighted ? 16 : 14)),
                  Text(eurValue, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String label, String usdValue, String eurValue, String description) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label, 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800]),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(usdValue, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 16)),
                  Text(eurValue, style: TextStyle(color: Colors.green[600], fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: Colors.green[600], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxRow(String label, String primaryValue, String secondaryValue, String description) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label, 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(primaryValue, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700], fontSize: 16)),
                  Text('($secondaryValue)', style: TextStyle(color: Colors.orange[600], fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: Colors.orange[600], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRateInfo(double exchangeRate) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.currency_exchange, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            'Verwendeter Kurs: 1 USD = ${exchangeRate.toStringAsFixed(4)} EUR',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
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
                : const Text('Kauf speichern'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _purchaseDate) {
      setState(() {
        _purchaseDate = picked;
        _purchaseDateController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  void _calculatePurchasePrice() {
    final fmv = NumberFormatter.parseGermanNumber(_fmvController.text);
    final discountRate = NumberFormatter.parseGermanNumber(_discountRateController.text);
    
    if (fmv != null && discountRate != null) {
      final purchasePrice = fmv * (1 - discountRate / 100);
      _purchasePriceController.text = purchasePrice.toStringAsFixed(2);
    }
  }

  Future<void> _fetchCurrentExchangeRate() async {
    try {
      final usdEurRateAsync = ref.read(usdEurRateProvider.future);
      final exchangeRateModel = await usdEurRateAsync;
      final rate = exchangeRateModel.rate;
      
      _exchangeRatePurchaseController.text = rate.toStringAsFixed(4);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Live-Wechselkurs: 1 USD = ${rate.toStringAsFixed(4)} EUR'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _exchangeRatePurchaseController.text = '0.92';
      
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

    setState(() => _isLoading = true);

    try {
      final transaction = TransactionModel(
        id: widget.existingTransaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        purchaseDate: _purchaseDate!,
        saleDate: null,
        quantity: NumberFormatter.parseGermanNumber(_quantityController.text)!,
        fmvPerShare: NumberFormatter.parseGermanNumber(_fmvController.text)!,
        purchasePricePerShare: NumberFormatter.parseGermanNumber(_purchasePriceController.text)!,
        salePricePerShare: null,
        incomeTaxRate: NumberFormatter.parseGermanNumber(_incomeTaxRateController.text)! / 100,
        capitalGainsTaxRate: NumberFormatter.parseGermanNumber(_capitalGainsTaxRateController.text)! / 100,
        exchangeRateAtPurchase: NumberFormatter.parseGermanNumber(_exchangeRatePurchaseController.text) ?? 0.92,
        exchangeRateAtSale: null,
        type: TransactionType.purchase,
        createdAt: widget.existingTransaction?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.existingTransaction != null) {
        await ref.read(transactionsProvider.notifier).updateTransaction(transaction);
      } else {
        await ref.read(transactionsProvider.notifier).addTransaction(transaction);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingTransaction != null 
                ? 'Kauf aktualisiert' 
                : 'Kauf gespeichert'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kauf löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existingTransaction != null) {
      ref.read(transactionsProvider.notifier).deleteTransaction(widget.existingTransaction!.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kauf gelöscht')),
        );
      }
    }
  }

  @override
  void dispose() {
    _purchaseDateController.dispose();
    _quantityController.dispose();
    _fmvController.dispose();
    _purchasePriceController.dispose();
    _discountRateController.dispose();
    _incomeTaxRateController.dispose();
    _capitalGainsTaxRateController.dispose();
    _exchangeRatePurchaseController.dispose();
    super.dispose();
  }
}