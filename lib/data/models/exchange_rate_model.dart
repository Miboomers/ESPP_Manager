import 'package:equatable/equatable.dart';

class ExchangeRateModel extends Equatable {
  final String fromCurrency;
  final String toCurrency;
  final double rate;
  final DateTime timestamp;

  const ExchangeRateModel({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    required this.timestamp,
  });

  factory ExchangeRateModel.fromJson(Map<String, dynamic> json) {
    return ExchangeRateModel(
      fromCurrency: json['fromCurrency'] as String,
      toCurrency: json['toCurrency'] as String,
      rate: (json['rate'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromCurrency': fromCurrency,
      'toCurrency': toCurrency,
      'rate': rate,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [fromCurrency, toCurrency, rate, timestamp];
}