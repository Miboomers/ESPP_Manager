import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'settings_model.g.dart';

@HiveType(typeId: 2)
class SettingsModel extends Equatable {
  @HiveField(0)
  final bool biometricEnabled;
  
  @HiveField(1)
  final int autoLockMinutes;
  
  @HiveField(2)
  final double defaultIncomeTaxRate;
  
  @HiveField(3)
  final double defaultCapitalGainsTaxRate;
  
  @HiveField(4)
  final String defaultStockSymbol;
  
  @HiveField(5)
  final String displayCurrency;
  
  @HiveField(6)
  final bool showLivePrices;
  
  @HiveField(7)
  final DateTime? lastBackup;
  
  @HiveField(8)
  final double defaultEsppDiscountRate;

  const SettingsModel({
    this.biometricEnabled = false,
    this.autoLockMinutes = 5,
    this.defaultIncomeTaxRate = 0.42,
    this.defaultCapitalGainsTaxRate = 0.25,
    this.defaultStockSymbol = 'RMD',
    this.displayCurrency = 'EUR',
    this.showLivePrices = true,
    this.lastBackup,
    this.defaultEsppDiscountRate = 0.15, // 15% Standard ESPP Rabatt
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      biometricEnabled: json['biometricEnabled'] ?? false,
      autoLockMinutes: json['autoLockMinutes'] ?? 5,
      defaultIncomeTaxRate: (json['defaultIncomeTaxRate'] ?? 0.42).toDouble(),
      defaultCapitalGainsTaxRate: (json['defaultCapitalGainsTaxRate'] ?? 0.25).toDouble(),
      defaultStockSymbol: json['defaultStockSymbol'] ?? 'RMD',
      displayCurrency: json['displayCurrency'] ?? 'EUR',
      showLivePrices: json['showLivePrices'] ?? true,
      lastBackup: json['lastBackup'] != null 
          ? DateTime.parse(json['lastBackup']) 
          : null,
      defaultEsppDiscountRate: (json['defaultEsppDiscountRate'] ?? 0.15).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'biometricEnabled': biometricEnabled,
      'autoLockMinutes': autoLockMinutes,
      'defaultIncomeTaxRate': defaultIncomeTaxRate,
      'defaultCapitalGainsTaxRate': defaultCapitalGainsTaxRate,
      'defaultStockSymbol': defaultStockSymbol,
      'displayCurrency': displayCurrency,
      'showLivePrices': showLivePrices,
      'lastBackup': lastBackup?.toIso8601String(),
      'defaultEsppDiscountRate': defaultEsppDiscountRate,
    };
  }

  SettingsModel copyWith({
    bool? biometricEnabled,
    int? autoLockMinutes,
    double? defaultIncomeTaxRate,
    double? defaultCapitalGainsTaxRate,
    String? defaultStockSymbol,
    String? displayCurrency,
    bool? showLivePrices,
    DateTime? lastBackup,
    double? defaultEsppDiscountRate,
  }) {
    return SettingsModel(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      defaultIncomeTaxRate: defaultIncomeTaxRate ?? this.defaultIncomeTaxRate,
      defaultCapitalGainsTaxRate: defaultCapitalGainsTaxRate ?? this.defaultCapitalGainsTaxRate,
      defaultStockSymbol: defaultStockSymbol ?? this.defaultStockSymbol,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      showLivePrices: showLivePrices ?? this.showLivePrices,
      lastBackup: lastBackup ?? this.lastBackup,
      defaultEsppDiscountRate: defaultEsppDiscountRate ?? this.defaultEsppDiscountRate,
    );
  }

  @override
  List<Object?> get props => [
    biometricEnabled,
    autoLockMinutes,
    defaultIncomeTaxRate,
    defaultCapitalGainsTaxRate,
    defaultStockSymbol,
    displayCurrency,
    showLivePrices,
    lastBackup,
    defaultEsppDiscountRate,
  ];
}