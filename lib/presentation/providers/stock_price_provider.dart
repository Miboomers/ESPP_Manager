import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stock_price_model.dart';
import '../../data/models/exchange_rate_model.dart';
import '../../data/datasources/stock_api_service.dart';
import '../../data/repositories/stock_cache_repository.dart';

final stockApiServiceProvider = Provider<StockApiService>((ref) {
  return StockApiService();
});

final stockCacheRepositoryProvider = Provider<StockCacheRepository>((ref) {
  return StockCacheRepository();
});

final stockPriceProvider = FutureProvider.family<StockPriceModel, String>((ref, symbol) async {
  final apiService = ref.read(stockApiServiceProvider);
  final cacheRepository = ref.read(stockCacheRepositoryProvider);
  
  // Try to get cached data first
  final cachedStockPrice = await cacheRepository.getCachedStockPrice(symbol);
  if (cachedStockPrice != null) {
    return cachedStockPrice;
  }
  
  // If no cache or expired, fetch from API
  try {
    final stockPrice = await apiService.getStockPrice(symbol);
    
    if (stockPrice == null) {
      throw Exception('Could not fetch stock price for $symbol');
    }
    
    // Cache the fresh data
    await cacheRepository.cacheStockPrice(stockPrice);
    
    return stockPrice;
  } catch (e) {
    // API failed, throw exception to show error in debug
    throw Exception('All APIs failed for $symbol: $e');
  }
});

final exchangeRateProvider = FutureProvider.family<ExchangeRateModel, ExchangeRateRequest>((ref, request) async {
  final apiService = ref.read(stockApiServiceProvider);
  final cacheRepository = ref.read(stockCacheRepositoryProvider);
  
  // Try to get cached data first
  final cachedRate = await cacheRepository.getCachedExchangeRate(request.from, request.to);
  if (cachedRate != null) {
    return cachedRate;
  }
  
  // If no cache or expired, fetch from API
  final exchangeRate = await apiService.getExchangeRate(request.from, request.to);
  
  if (exchangeRate == null) {
    throw Exception('Could not fetch exchange rate from ${request.from} to ${request.to}');
  }
  
  // Cache the fresh data
  await cacheRepository.cacheExchangeRate(exchangeRate);
  
  return exchangeRate;
});

final historicalExchangeRateProvider = FutureProvider.family<ExchangeRateModel, HistoricalExchangeRateRequest>((ref, request) async {
  final apiService = ref.read(stockApiServiceProvider);
  final exchangeRate = await apiService.getHistoricalExchangeRate(
    request.from,
    request.to,
    request.date,
  );
  
  if (exchangeRate == null) {
    throw Exception('Could not fetch historical exchange rate from ${request.from} to ${request.to} for ${request.date}');
  }
  
  return exchangeRate;
});

// Current USD/EUR rate provider
final usdEurRateProvider = FutureProvider<ExchangeRateModel>((ref) async {
  final apiService = ref.read(stockApiServiceProvider);
  final cacheRepository = ref.read(stockCacheRepositoryProvider);
  
  // Try to get cached data first
  final cachedRate = await cacheRepository.getCachedExchangeRate('USD', 'EUR');
  if (cachedRate != null) {
    return cachedRate;
  }
  
  // If no cache or expired, fetch from API
  final exchangeRate = await apiService.getECBExchangeRate();
  
  if (exchangeRate == null) {
    throw Exception('Could not fetch USD/EUR exchange rate');
  }
  
  // Cache the fresh data
  await cacheRepository.cacheExchangeRate(exchangeRate);
  
  return exchangeRate;
});

// Provider for cache cleanup
final cacheCleanupProvider = FutureProvider<void>((ref) async {
  final cacheRepository = ref.read(stockCacheRepositoryProvider);
  await cacheRepository.clearExpiredCache();
});

class ExchangeRateRequest {
  final String from;
  final String to;

  const ExchangeRateRequest({
    required this.from,
    required this.to,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExchangeRateRequest &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

class HistoricalExchangeRateRequest {
  final String from;
  final String to;
  final DateTime date;

  const HistoricalExchangeRateRequest({
    required this.from,
    required this.to,
    required this.date,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoricalExchangeRateRequest &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          date == other.date;

  @override
  int get hashCode => from.hashCode ^ to.hashCode ^ date.hashCode;
}