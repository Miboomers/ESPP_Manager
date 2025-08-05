import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transactions_provider.dart';
import '../../data/models/transaction_model.dart';

class RecalculateScreen extends ConsumerStatefulWidget {
  const RecalculateScreen({super.key});

  @override
  ConsumerState<RecalculateScreen> createState() => _RecalculateScreenState();
}

class _RecalculateScreenState extends ConsumerState<RecalculateScreen> {
  bool _isRecalculating = false;
  String _status = '';
  int _processed = 0;
  int _total = 0;

  Future<void> _recalculateAllTransactions() async {
    setState(() {
      _isRecalculating = true;
      _status = 'Starte Neuberechnung...';
      _processed = 0;
    });

    try {
      // Get all transactions
      final transactions = await ref.read(transactionsProvider.future);
      _total = transactions.length;
      
      setState(() {
        _status = 'Berechne $_total Transaktionen neu...';
      });

      // Process each transaction
      for (var i = 0; i < transactions.length; i++) {
        final transaction = transactions[i];
        
        // The getters in TransactionModel will automatically use the new calculation logic
        // We just need to trigger a save to update the stored values
        await ref.read(transactionsProvider.notifier).updateTransaction(transaction);
        
        setState(() {
          _processed = i + 1;
          _status = 'Verarbeite Transaktion ${_processed} von $_total...';
        });
      }

      setState(() {
        _status = 'Neuberechnung abgeschlossen! $_processed Transaktionen aktualisiert.';
        _isRecalculating = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alle Transaktionen wurden erfolgreich neu berechnet!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Fehler bei der Neuberechnung: $e';
        _isRecalculating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaktionen neu berechnen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Wichtiger Hinweis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Diese Funktion berechnet alle Ihre ESPP-Transaktionen mit den aktualisierten Steuerformeln neu.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Dies ist notwendig, um die korrekten Werte für:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Gesamtgewinn (mit ESPP-Rabatt)', style: TextStyle(fontSize: 14)),
                          Text('• Steuerpflichtigen Kapitalgewinn (ohne ESPP-Rabatt)', style: TextStyle(fontSize: 14)),
                          Text('• Kapitalertragsteuer', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'gemäß deutschem Steuerrecht zu erhalten.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_status.isNotEmpty) ...[
              Card(
                color: _isRecalculating ? Colors.blue[50] : Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_isRecalculating)
                        const CircularProgressIndicator()
                      else
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[700],
                          size: 48,
                        ),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      if (_isRecalculating && _total > 0) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: _total > 0 ? _processed / _total : 0,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_processed / _total * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton.icon(
              onPressed: _isRecalculating ? null : _recalculateAllTransactions,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'Neuberechnung starten',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isRecalculating ? null : () => Navigator.pop(context),
              child: const Text('Zurück'),
            ),
          ],
        ),
      ),
    );
  }
}