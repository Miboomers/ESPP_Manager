import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transactions_repository.dart';
import '../../core/utils/transaction_matcher.dart';
import '../../core/services/cloud_sync_service.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository();
});

final transactionsProvider = AsyncNotifierProvider<TransactionsNotifier, List<TransactionModel>>(() {
  return TransactionsNotifier();
});

class TransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  TransactionsRepository? _repository;

  TransactionsRepository get repository {
    _repository ??= ref.read(transactionsRepositoryProvider);
    return _repository!;
  }

  @override
  Future<List<TransactionModel>> build() async {
    return await repository.getAllTransactions();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    state = const AsyncValue.loading();
    try {
      await repository.saveTransaction(transaction);
      final transactions = await repository.getAllTransactions();
      
      // Match sales with purchases to update lookback data
      final matchedTransactions = TransactionMatcher.matchSalesWithPurchases(transactions);
      
      state = AsyncValue.data(matchedTransactions);
      
      // 🔄 Automatische Cloud-Synchronisierung
      try {
        final cloudService = ref.read(cloudSyncServiceProvider);
        await cloudService.syncPendingChanges();
      } catch (e) {
        // Cloud-Sync-Fehler nicht an den Benutzer weitergeben
        // Daten wurden lokal gespeichert
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    state = const AsyncValue.loading();
    try {
      await repository.saveTransaction(transaction);
      final transactions = await repository.getAllTransactions();
      state = AsyncValue.data(transactions);
      
      // 🔄 Automatische Cloud-Synchronisierung
      try {
        final cloudService = ref.read(cloudSyncServiceProvider);
        await cloudService.syncPendingChanges();
      } catch (e) {
        // Cloud-Sync-Fehler nicht an den Benutzer weitergeben
        // Daten wurden lokal gespeichert
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteTransaction(String id) async {
    state = const AsyncValue.loading();
    try {
      await repository.deleteTransaction(id);
      final transactions = await repository.getAllTransactions();
      state = AsyncValue.data(transactions);
      
      // 🔄 Automatische Cloud-Synchronisierung
      try {
        final cloudService = ref.read(cloudSyncServiceProvider);
        await cloudService.syncPendingChanges();
      } catch (e) {
        // Cloud-Sync-Fehler nicht an den Benutzer weitergeben
        // Daten wurden lokal gespeichert
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteAllTransactions() async {
    state = const AsyncValue.loading();
    try {
      await repository.deleteAllTransactions();
      state = const AsyncValue.data([]);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  List<TransactionModel> getOpenPositions() {
    final transactions = state.valueOrNull ?? [];
    return transactions.where((t) => !t.isSold).toList();
  }

  List<TransactionModel> getSoldPositions() {
    final transactions = state.valueOrNull ?? [];
    return transactions.where((t) => t.isSold).toList();
  }

  Future<void> restoreFromCloud(List<TransactionModel> cloudTransactions) async {
    state = const AsyncValue.loading();
    try {
      // Clear local data first
      await repository.deleteAllTransactions();
      
      // Save all cloud transactions to local storage
      for (final transaction in cloudTransactions) {
        await repository.saveTransaction(transaction);
      }
      
      // Match sales with purchases to update lookback data
      final matchedTransactions = TransactionMatcher.matchSalesWithPurchases(cloudTransactions);
      
      state = AsyncValue.data(matchedTransactions);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}