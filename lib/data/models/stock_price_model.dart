import 'package:equatable/equatable.dart';

class StockPriceModel extends Equatable {
  final String symbol;
  final double price;
  final double previousClose;
  final double change;
  final double changePercent;
  final DateTime timestamp;
  final String currency;

  const StockPriceModel({
    required this.symbol,
    required this.price,
    required this.previousClose,
    required this.change,
    required this.changePercent,
    required this.timestamp,
    this.currency = 'USD',
  });

  factory StockPriceModel.fromJson(Map<String, dynamic> json) {
    return StockPriceModel(
      symbol: json['symbol'] as String,
      price: (json['price'] as num).toDouble(),
      previousClose: (json['previousClose'] as num).toDouble(),
      change: (json['change'] as num).toDouble(),
      changePercent: (json['changePercent'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'price': price,
      'previousClose': previousClose,
      'change': change,
      'changePercent': changePercent,
      'timestamp': timestamp.toIso8601String(),
      'currency': currency,
    };
  }

  @override
  List<Object?> get props => [
        symbol,
        price,
        previousClose,
        change,
        changePercent,
        timestamp,
        currency,
      ];
}