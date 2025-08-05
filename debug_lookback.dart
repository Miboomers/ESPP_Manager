import 'lib/data/models/transaction_model.dart';
import 'lib/data/repositories/transactions_repository.dart';
import 'lib/core/security/encryption_service.dart';
import 'lib/core/security/secure_storage_service.dart';

void main() async {
  print('🔍 DEBUG: Überprüfe Lookback-Daten in Transaktionen');
  
  try {
    final repository = TransactionsRepository();
    final transactions = await repository.getAllTransactions();
    
    print('\n📊 Gefundene Transaktionen: ${transactions.length}');
    
    if (transactions.isEmpty) {
      print('❌ Keine Transaktionen gefunden!');
      return;
    }
    
    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      print('\n--- Transaktion ${i + 1} ---');
      print('ID: ${tx.id}');
      print('Kaufdatum: ${tx.purchaseDate}');
      print('Verkaufsdatum: ${tx.saleDate}');
      print('Menge: ${tx.quantity}');
      print('FMV per Share: ${tx.fmvPerShare}');
      print('🎯 Lookback FMV: ${tx.lookbackFmv ?? "NICHT VORHANDEN"}');
      print('📅 Offering Period: ${tx.offeringPeriod ?? "NICHT VORHANDEN"}');
      print('💰 ESPP Basis Price: ${tx.esppBasisPrice}');
      print('🏷️ Verkauft: ${tx.isSold}');
      
      if (tx.lookbackFmv != null) {
        print('✅ Hat Lookback-Daten!');
      } else {
        print('❌ Keine Lookback-Daten!');
      }
    }
    
    // Statistiken
    final withLookback = transactions.where((t) => t.lookbackFmv != null).length;
    final withOfferingPeriod = transactions.where((t) => t.offeringPeriod != null).length;
    final soldTransactions = transactions.where((t) => t.isSold).length;
    
    print('\n📈 STATISTIKEN:');
    print('Transaktionen mit Lookback FMV: $withLookback von ${transactions.length}');
    print('Transaktionen mit Offering Period: $withOfferingPeriod von ${transactions.length}');
    print('Verkaufte Transaktionen: $soldTransactions von ${transactions.length}');
    
    if (withLookback == 0) {
      print('\n🚨 PROBLEM IDENTIFIZIERT: Keine Lookback-Daten vorhanden!');
      print('Das erklärt, warum sie nicht im PDF-Bericht erscheinen.');
    }
    
  } catch (e) {
    print('❌ Fehler beim Laden der Transaktionen: $e');
  }
}