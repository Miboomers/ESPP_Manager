import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/stock_price_model.dart';
import '../models/exchange_rate_model.dart';

class StockApiService {
  late final Dio _dio;
  
  StockApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  // Multiple API sources for reliability
  Future<StockPriceModel?> getStockPrice(String symbol) async {
    // Try Yahoo Finance first (unlimited, no key needed)
    try {
      return await _getYahooFinancePrice(symbol);
    } catch (e) {
    }
    
    // Fallback to Alpha Vantage
    try {
      return await _getAlphaVantagePrice(symbol);
    } catch (e) {
      rethrow;
    }
  }

  Future<StockPriceModel?> _getYahooFinancePrice(String symbol) async {
    final response = await _dio.get(
      'https://query1.finance.yahoo.com/v8/finance/chart/$symbol',
      queryParameters: {
        'interval': '1d',
        'range': '1d',
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final chart = data['chart'] as Map<String, dynamic>;
      final results = chart['result'] as List<dynamic>;
      
      if (results.isNotEmpty) {
        final result = results[0] as Map<String, dynamic>;
        final meta = result['meta'] as Map<String, dynamic>;
        
        final price = meta['regularMarketPrice']?.toDouble() ?? 0.0;
        final previousClose = meta['previousClose']?.toDouble() ?? 0.0;
        final change = price - previousClose;
        final changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0.0;
        
        return StockPriceModel(
          symbol: meta['symbol'] ?? symbol,
          price: price,
          previousClose: previousClose,
          change: change,
          changePercent: changePercent,
          timestamp: DateTime.now(),
        );
      }
    }
    
    throw Exception('Yahoo Finance: No data received');
  }

  Future<StockPriceModel?> _getAlphaVantagePrice(String symbol) async {
    try {
      // Using Alpha Vantage free API as an example
      // Note: You'll need to get a free API key from https://www.alphavantage.co/
      const apiKey = 'N6PM5QM290G0RHTM'; // Alpha Vantage API Key
      
      final response = await _dio.get(
        'https://www.alphavantage.co/query',
        queryParameters: {
          'function': 'GLOBAL_QUOTE',
          'symbol': symbol,
          'apikey': apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        
        // Check for Alpha Vantage rate limit message
        if (data.containsKey('Note')) {
          throw Exception('Alpha Vantage Rate Limit: ${data['Note']}');
        }
        if (data.containsKey('Information')) {
          throw Exception('Alpha Vantage API Info: ${data['Information']}');
        }
        
        final quote = data['Global Quote'] as Map<String, dynamic>?;
        
        if (quote != null && quote.isNotEmpty) {
          return StockPriceModel(
            symbol: quote['01. symbol'] ?? symbol,
            price: double.parse(quote['05. price'] ?? '0'),
            previousClose: double.parse(quote['08. previous close'] ?? '0'),
            change: double.parse(quote['09. change'] ?? '0'),
            changePercent: double.parse(
              (quote['10. change percent'] ?? '0%').replaceAll('%', ''),
            ),
            timestamp: DateTime.now(),
          );
        } else {
          throw Exception('No quote data received from Alpha Vantage');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } catch (e) {
      // Log error and rethrow for better debugging
      rethrow; // Don't hide the error!
    }
  }

  // Free Exchange Rate API
  Future<ExchangeRateModel?> getExchangeRate(
    String fromCurrency,
    String toCurrency,
  ) async {
    try {
      // Using ExchangeRate-API (free)
      final response = await _dio.get(
        'https://api.exchangerate-api.com/v4/latest/$fromCurrency',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        
        if (rates.containsKey(toCurrency)) {
          return ExchangeRateModel(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            rate: double.parse(rates[toCurrency].toString()),
            timestamp: DateTime.now(),
          );
        }
      }
    } catch (e) {
    }
    
    // Fallback: return mock data for demo purposes
    return _getMockExchangeRate(fromCurrency, toCurrency);
  }

  // European Central Bank API for EUR rates
  Future<ExchangeRateModel?> getECBExchangeRate() async {
    try {
      final response = await _dio.get(
        'https://api.exchangerate-api.com/v4/latest/USD',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        
        if (rates.containsKey('EUR')) {
          return ExchangeRateModel(
            fromCurrency: 'USD',
            toCurrency: 'EUR',
            rate: double.parse(rates['EUR'].toString()),
            timestamp: DateTime.now(),
          );
        }
      }
    } catch (e) {
    }
    
    return _getMockExchangeRate('USD', 'EUR');
  }

  // Mock data for demo purposes
  StockPriceModel _getMockStockPrice(String symbol) {
    final mockPrices = {
      'AAPL': 175.50,
      'MSFT': 310.25,
      'GOOGL': 140.80,
      'AMZN': 145.30,
      'TSLA': 250.75,
      'RMD': 185.40, // ResMed mock price
    };
    
    final price = mockPrices[symbol] ?? 100.00;
    final previousClose = price * 0.98; // -2% from previous day
    final change = price - previousClose;
    final changePercent = (change / previousClose) * 100;
    
    return StockPriceModel(
      symbol: symbol,
      price: price,
      previousClose: previousClose,
      change: change,
      changePercent: changePercent,
      timestamp: DateTime.now(),
    );
  }

  ExchangeRateModel _getMockExchangeRate(String from, String to) {
    // USD to EUR mock rate
    if (from == 'USD' && to == 'EUR') {
      return ExchangeRateModel(
        fromCurrency: from,
        toCurrency: to,
        rate: 0.92, // Mock USD to EUR rate
        timestamp: DateTime.now(),
      );
    }
    
    // EUR to USD mock rate
    if (from == 'EUR' && to == 'USD') {
      return ExchangeRateModel(
        fromCurrency: from,
        toCurrency: to,
        rate: 1.09, // Mock EUR to USD rate
        timestamp: DateTime.now(),
      );
    }
    
    return ExchangeRateModel(
      fromCurrency: from,
      toCurrency: to,
      rate: 1.0,
      timestamp: DateTime.now(),
    );
  }

  // Get historical exchange rate for a specific date
  Future<ExchangeRateModel?> getHistoricalExchangeRate(
    String fromCurrency,
    String toCurrency,
    DateTime date,
  ) async {
    try {
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final response = await _dio.get(
        'https://api.exchangerate-api.com/v4/history/$fromCurrency/$dateString',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        
        if (rates.containsKey(toCurrency)) {
          return ExchangeRateModel(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            rate: double.parse(rates[toCurrency].toString()),
            timestamp: date,
          );
        }
      }
    } catch (e) {
    }
    
    // Fallback to current rate
    return await getExchangeRate(fromCurrency, toCurrency);
  }
}