import 'package:hive/hive.dart';
import '../models/stock_price_model.dart';
import '../models/exchange_rate_model.dart';

class StockCacheRepository {
  static const String _stockPriceBoxName = 'stock_prices';
  static const String _exchangeRateBoxName = 'exchange_rates';
  static const Duration _cacheValidityDuration = Duration(minutes: 15);

  Box<Map>? _stockPriceBox;
  Box<Map>? _exchangeRateBox;

  Future<void> init() async {
    _stockPriceBox = await Hive.openBox<Map>(_stockPriceBoxName);
    _exchangeRateBox = await Hive.openBox<Map>(_exchangeRateBoxName);
  }

  Future<StockPriceModel?> getCachedStockPrice(String symbol) async {
    if (_stockPriceBox == null) await init();
    
    final cachedData = _stockPriceBox!.get(symbol);
    if (cachedData == null) return null;

    try {
      final stockPrice = StockPriceModel.fromJson(Map<String, dynamic>.from(cachedData));
      
      // Check if cache is still valid (within 15 minutes)
      if (DateTime.now().difference(stockPrice.timestamp) < _cacheValidityDuration) {
        return stockPrice;
      }
    } catch (e) {
      print('Error reading cached stock price: $e');
    }
    
    return null;
  }

  Future<void> cacheStockPrice(StockPriceModel stockPrice) async {
    if (_stockPriceBox == null) await init();
    
    try {
      await _stockPriceBox!.put(stockPrice.symbol, stockPrice.toJson());
    } catch (e) {
      print('Error caching stock price: $e');
    }
  }

  Future<ExchangeRateModel?> getCachedExchangeRate(String from, String to) async {
    if (_exchangeRateBox == null) await init();
    
    final key = '${from}_$to';
    final cachedData = _exchangeRateBox!.get(key);
    if (cachedData == null) return null;

    try {
      final exchangeRate = ExchangeRateModel.fromJson(Map<String, dynamic>.from(cachedData));
      
      // Check if cache is still valid (within 15 minutes)
      if (DateTime.now().difference(exchangeRate.timestamp) < _cacheValidityDuration) {
        return exchangeRate;
      }
    } catch (e) {
      print('Error reading cached exchange rate: $e');
    }
    
    return null;
  }

  Future<void> cacheExchangeRate(ExchangeRateModel exchangeRate) async {
    if (_exchangeRateBox == null) await init();
    
    try {
      final key = '${exchangeRate.fromCurrency}_${exchangeRate.toCurrency}';
      await _exchangeRateBox!.put(key, exchangeRate.toJson());
    } catch (e) {
      print('Error caching exchange rate: $e');
    }
  }

  Future<void> clearExpiredCache() async {
    if (_stockPriceBox == null || _exchangeRateBox == null) await init();
    
    try {
      // Clear expired stock prices
      final stockPriceKeys = _stockPriceBox!.keys.toList();
      for (final key in stockPriceKeys) {
        final cachedData = _stockPriceBox!.get(key);
        if (cachedData != null) {
          final stockPrice = StockPriceModel.fromJson(Map<String, dynamic>.from(cachedData));
          if (DateTime.now().difference(stockPrice.timestamp) >= _cacheValidityDuration) {
            await _stockPriceBox!.delete(key);
          }
        }
      }

      // Clear expired exchange rates
      final exchangeRateKeys = _exchangeRateBox!.keys.toList();
      for (final key in exchangeRateKeys) {
        final cachedData = _exchangeRateBox!.get(key);
        if (cachedData != null) {
          final exchangeRate = ExchangeRateModel.fromJson(Map<String, dynamic>.from(cachedData));
          if (DateTime.now().difference(exchangeRate.timestamp) >= _cacheValidityDuration) {
            await _exchangeRateBox!.delete(key);
          }
        }
      }
    } catch (e) {
      print('Error clearing expired cache: $e');
    }
  }

  Future<void> clearAllCache() async {
    if (_stockPriceBox == null || _exchangeRateBox == null) await init();
    
    try {
      await _stockPriceBox!.clear();
      await _exchangeRateBox!.clear();
    } catch (e) {
      print('Error clearing all cache: $e');
    }
  }
}