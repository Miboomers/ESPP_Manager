import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 0)
class TransactionModel extends Equatable {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final DateTime purchaseDate;
  
  @HiveField(2)
  final DateTime? saleDate;
  
  @HiveField(3)
  final double quantity;
  
  @HiveField(4)
  final double fmvPerShare; // Fair Market Value in USD
  
  @HiveField(5)
  final double purchasePricePerShare; // After discount in USD
  
  @HiveField(6)
  final double? salePricePerShare; // in USD
  
  @HiveField(7)
  final double incomeTaxRate; // Percentage (e.g., 0.42 for 42%)
  
  @HiveField(8)
  final double capitalGainsTaxRate; // Percentage (e.g., 0.25 for 25%)
  
  @HiveField(9)
  final double? exchangeRateAtPurchase; // USD to EUR
  
  @HiveField(10)
  final double? exchangeRateAtSale; // USD to EUR
  
  @HiveField(11)
  final TransactionType type;
  
  @HiveField(12)
  final DateTime createdAt;
  
  @HiveField(13)
  final DateTime? updatedAt;
  
  @HiveField(14)
  final double? lookbackFmv; // FMV at start of offering period
  
  @HiveField(15)
  final String? offeringPeriod; // e.g. "MAY/01/2023 - OCT/31/2023"
  
  @HiveField(16)
  final DateTime? qualifiedDispositionDate; // 2 years from purchase date

  const TransactionModel({
    required this.id,
    required this.purchaseDate,
    this.saleDate,
    required this.quantity,
    required this.fmvPerShare,
    required this.purchasePricePerShare,
    this.salePricePerShare,
    required this.incomeTaxRate,
    required this.capitalGainsTaxRate,
    this.exchangeRateAtPurchase,
    this.exchangeRateAtSale,
    required this.type,
    required this.createdAt,
    this.updatedAt,
    this.lookbackFmv,
    this.offeringPeriod,
    this.qualifiedDispositionDate,
  });

  // Calculated properties
  // ESPP discount calculation considers lookback price if available
  double get actualPurchasePrice => purchasePricePerShare;
  
  // The ESPP basis price is the lower of lookback FMV or purchase date FMV
  double get esppBasisPrice => lookbackFmv != null && lookbackFmv! < fmvPerShare 
      ? lookbackFmv! 
      : fmvPerShare;
  
  // The geldwerter Vorteil (monetary benefit) is the difference between 
  // FMV at purchase date and actual purchase price (includes full 15% discount)
  double get geldwerterVorteil => fmvPerShare - purchasePricePerShare;
  
  double get totalGeldwerterVorteil => geldwerterVorteil * quantity;
  
  // Income tax is calculated on the full monetary benefit
  double get incomeTaxOnDiscount => totalGeldwerterVorteil * incomeTaxRate;
  
  // USD-based capital gain per share
  // IMPORTANT: For tax purposes, the cost basis is the FMV at purchase date
  // The discount was already income-taxed, so FMV at purchase becomes the new cost basis
  double? get capitalGainPerShareUSD => 
      salePricePerShare != null ? salePricePerShare! - fmvPerShare : null;
  
  double? get totalCapitalGainUSD => 
      capitalGainPerShareUSD != null ? capitalGainPerShareUSD! * quantity : null;
  
  // EUR-based TOTAL gain (actual gain including ESPP discount)
  double? get totalGainEUR {
    if (salePricePerShare == null || exchangeRateAtPurchase == null || exchangeRateAtSale == null) {
      return null;
    }
    
    // Total gain = Sale value - Actually paid amount (with ESPP discount)
    final actualPurchaseValueEUR = purchasePricePerShare * quantity * exchangeRateAtPurchase!;
    final saleValueEUR = salePricePerShare! * quantity * exchangeRateAtSale!;
    
    return saleValueEUR - actualPurchaseValueEUR;
  }
  
  // EUR-based TAXABLE capital gain (for German tax calculation - uses FMV at purchase as cost basis)
  double? get taxableCapitalGainEUR {
    if (salePricePerShare == null || exchangeRateAtPurchase == null || exchangeRateAtSale == null) {
      return null;
    }
    
    // Taxable capital gain = Sale value - FMV cost basis (discount already income-taxed)
    final fmvCostBasisEUR = fmvPerShare * quantity * exchangeRateAtPurchase!;
    final saleValueEUR = salePricePerShare! * quantity * exchangeRateAtSale!;
    
    return saleValueEUR - fmvCostBasisEUR;
  }
  
  // Capital gains tax based on TAXABLE capital gain (German tax law)
  double? get capitalGainsTaxEUR {
    if (taxableCapitalGainEUR == null || taxableCapitalGainEUR! <= 0) return 0;
    return taxableCapitalGainEUR! * capitalGainsTaxRate;
  }
  
  // Legacy getter for backwards compatibility (USD-based)
  double? get totalGain => totalCapitalGainUSD;
  
  // Legacy getter for backwards compatibility (USD-based) 
  double? get capitalGainsTax {
    if (totalCapitalGainUSD == null || totalCapitalGainUSD! <= 0) return 0;
    return totalCapitalGainUSD! * capitalGainsTaxRate;
  }
  
  double get totalPurchaseCost => purchasePricePerShare * quantity;
  
  double? get totalSaleProceeds => 
      salePricePerShare != null ? salePricePerShare! * quantity : null;
  
  double? get netProfitInUSD {
    if (totalSaleProceeds == null) return null;
    return totalSaleProceeds! - totalPurchaseCost - incomeTaxOnDiscount - (capitalGainsTax ?? 0);
  }
  
  // Correct EUR calculation considering German tax law
  double? get netProfitInEUR {
    if (totalSaleProceeds == null || exchangeRateAtPurchase == null || exchangeRateAtSale == null) {
      return null;
    }
    
    // Calculate in EUR basis for German tax purposes
    final saleProceedsEUR = totalSaleProceeds! * exchangeRateAtSale!;
    final purchaseCostEUR = totalPurchaseCost * exchangeRateAtPurchase!;
    final incomeTaxEUR = incomeTaxOnDiscount * exchangeRateAtPurchase!; // Tax on discount at purchase rate
    final capitalGainsTaxEURCorrect = capitalGainsTaxEUR ?? 0;
    
    return saleProceedsEUR - purchaseCostEUR - incomeTaxEUR - capitalGainsTaxEURCorrect;
  }
  
  // Helper getters for tax declaration documentation
  double? get purchaseValueEURForTax => 
      exchangeRateAtPurchase != null ? fmvPerShare * quantity * exchangeRateAtPurchase! : null;
  
  double? get saleValueEURForTax => 
      salePricePerShare != null && exchangeRateAtSale != null 
          ? salePricePerShare! * quantity * exchangeRateAtSale! : null;
  
  bool get isSold => saleDate != null && salePricePerShare != null;
  
  // Alias getters for backwards compatibility
  double get discount => geldwerterVorteil;
  double get totalDiscount => totalGeldwerterVorteil;
  double? get gainPerShareUSD => capitalGainPerShareUSD;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchaseDate': purchaseDate.toIso8601String(),
      'saleDate': saleDate?.toIso8601String(),
      'quantity': quantity,
      'fmvPerShare': fmvPerShare,
      'purchasePricePerShare': purchasePricePerShare,
      'salePricePerShare': salePricePerShare,
      'incomeTaxRate': incomeTaxRate,
      'capitalGainsTaxRate': capitalGainsTaxRate,
      'exchangeRateAtPurchase': exchangeRateAtPurchase,
      'exchangeRateAtSale': exchangeRateAtSale,
      'type': type.toString(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lookbackFmv': lookbackFmv,
      'offeringPeriod': offeringPeriod,
      'qualifiedDispositionDate': qualifiedDispositionDate?.toIso8601String(),
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
      saleDate: json['saleDate'] != null 
          ? DateTime.parse(json['saleDate'] as String) 
          : null,
      quantity: (json['quantity'] as num).toDouble(),
      fmvPerShare: (json['fmvPerShare'] as num).toDouble(),
      purchasePricePerShare: (json['purchasePricePerShare'] as num).toDouble(),
      salePricePerShare: json['salePricePerShare'] != null 
          ? (json['salePricePerShare'] as num).toDouble() 
          : null,
      incomeTaxRate: (json['incomeTaxRate'] as num).toDouble(),
      capitalGainsTaxRate: (json['capitalGainsTaxRate'] as num).toDouble(),
      exchangeRateAtPurchase: json['exchangeRateAtPurchase'] != null 
          ? (json['exchangeRateAtPurchase'] as num).toDouble() 
          : null,
      exchangeRateAtSale: json['exchangeRateAtSale'] != null 
          ? (json['exchangeRateAtSale'] as num).toDouble() 
          : null,
      type: TransactionType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
      lookbackFmv: json['lookbackFmv'] != null
          ? (json['lookbackFmv'] as num).toDouble()
          : null,
      offeringPeriod: json['offeringPeriod'] as String?,
      qualifiedDispositionDate: json['qualifiedDispositionDate'] != null
          ? DateTime.parse(json['qualifiedDispositionDate'] as String)
          : null,
    );
  }

  TransactionModel copyWith({
    String? id,
    DateTime? purchaseDate,
    DateTime? saleDate,
    double? quantity,
    double? fmvPerShare,
    double? purchasePricePerShare,
    double? salePricePerShare,
    double? incomeTaxRate,
    double? capitalGainsTaxRate,
    double? exchangeRateAtPurchase,
    double? exchangeRateAtSale,
    TransactionType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? lookbackFmv,
    String? offeringPeriod,
    DateTime? qualifiedDispositionDate,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      saleDate: saleDate ?? this.saleDate,
      quantity: quantity ?? this.quantity,
      fmvPerShare: fmvPerShare ?? this.fmvPerShare,
      purchasePricePerShare: purchasePricePerShare ?? this.purchasePricePerShare,
      salePricePerShare: salePricePerShare ?? this.salePricePerShare,
      incomeTaxRate: incomeTaxRate ?? this.incomeTaxRate,
      capitalGainsTaxRate: capitalGainsTaxRate ?? this.capitalGainsTaxRate,
      exchangeRateAtPurchase: exchangeRateAtPurchase ?? this.exchangeRateAtPurchase,
      exchangeRateAtSale: exchangeRateAtSale ?? this.exchangeRateAtSale,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lookbackFmv: lookbackFmv ?? this.lookbackFmv,
      offeringPeriod: offeringPeriod ?? this.offeringPeriod,
      qualifiedDispositionDate: qualifiedDispositionDate ?? this.qualifiedDispositionDate,
    );
  }

  @override
  List<Object?> get props => [
        id,
        purchaseDate,
        saleDate,
        quantity,
        fmvPerShare,
        purchasePricePerShare,
        salePricePerShare,
        incomeTaxRate,
        capitalGainsTaxRate,
        exchangeRateAtPurchase,
        exchangeRateAtSale,
        type,
        createdAt,
        updatedAt,
        lookbackFmv,
        offeringPeriod,
        qualifiedDispositionDate,
      ];
}

@HiveType(typeId: 1)
enum TransactionType {
  @HiveField(0)
  purchase,
  
  @HiveField(1)
  sale,
}