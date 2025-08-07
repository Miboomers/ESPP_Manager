import '../models/transaction_model.dart';
import '../../core/security/secure_storage_service.dart';
import '../../core/security/encryption_service.dart';

class TransactionsRepository {
  static const String _transactionsKey = 'espp_transactions';
  
  SecureStorageService? _storageService;
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      try {
        final encryptionService = EncryptionService();
        await encryptionService.initialize();
        _storageService = SecureStorageService(encryptionService);
        await _storageService!.initialize();
        _isInitialized = true;
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    await _ensureInitialized();
    
    final data = await _storageService!.getData(_transactionsKey);
    if (data != null && data['transactions'] is List) {
      final transactionsList = data['transactions'] as List;
      return transactionsList
          .map((json) => TransactionModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    
    return [];
  }

  Future<void> saveTransaction(TransactionModel transaction) async {
    await _ensureInitialized();
    
    final transactions = await getAllTransactions();
    
    final existingIndex = transactions.indexWhere((t) => t.id == transaction.id);
    
    if (existingIndex >= 0) {
      transactions[existingIndex] = transaction;
    } else {
      transactions.add(transaction);
    }
    
    await _saveTransactions(transactions);
  }

  Future<void> deleteTransaction(String id) async {
    await _ensureInitialized();
    
    final transactions = await getAllTransactions();
    transactions.removeWhere((t) => t.id == id);
    
    await _saveTransactions(transactions);
  }

  Future<void> deleteAllTransactions() async {
    await _ensureInitialized();
    await _storageService!.deleteData(_transactionsKey);
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    final transactions = await getAllTransactions();
    try {
      return transactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final transactions = await getAllTransactions();
    return transactions.where((t) {
      return t.purchaseDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             t.purchaseDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _saveTransactions(List<TransactionModel> transactions) async {
    final data = {
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    
    await _storageService!.saveData(_transactionsKey, data);
  }
}