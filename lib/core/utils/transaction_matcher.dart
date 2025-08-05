import '../../data/models/transaction_model.dart';

class TransactionMatcher {
  /// Match sale transactions with purchase transactions based on acquisition date
  /// This updates the sale transactions with lookback data from matching purchases
  static List<TransactionModel> matchSalesWithPurchases(
    List<TransactionModel> allTransactions,
  ) {
    // Separate purchases and sales
    final purchases = allTransactions
        .where((t) => t.type == TransactionType.purchase)
        .toList()
      ..sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));
    
    final sales = allTransactions
        .where((t) => t.type == TransactionType.sale)
        .toList();
    
    // Updated transactions list
    final updatedTransactions = <TransactionModel>[];
    
    // Add all purchases unchanged
    updatedTransactions.addAll(purchases);
    
    // Process each sale transaction
    for (final sale in sales) {
      // Find matching purchase by acquisition date
      final matchingPurchase = purchases.firstWhere(
        (purchase) => _isSameDate(purchase.purchaseDate, sale.purchaseDate),
        orElse: () => purchases.firstWhere(
          // Fallback: find closest purchase date within 7 days
          (purchase) => _isWithinDays(purchase.purchaseDate, sale.purchaseDate, 7),
          orElse: () => sale, // Return original if no match
        ),
      );
      
      if (matchingPurchase != sale) {
        // Update sale with lookback data from matching purchase
        final updatedSale = sale.copyWith(
          lookbackFmv: matchingPurchase.lookbackFmv,
          offeringPeriod: matchingPurchase.offeringPeriod,
          qualifiedDispositionDate: matchingPurchase.qualifiedDispositionDate,
          // Update FMV if the purchase has more accurate data
          fmvPerShare: matchingPurchase.fmvPerShare,
          // Update purchase price if needed
          purchasePricePerShare: matchingPurchase.purchasePricePerShare,
        );
        updatedTransactions.add(updatedSale);
      } else {
        // No match found, add original sale
        updatedTransactions.add(sale);
      }
    }
    
    return updatedTransactions;
  }
  
  /// Check if two dates are the same (ignoring time)
  static bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  /// Check if two dates are within a certain number of days
  static bool _isWithinDays(DateTime date1, DateTime date2, int days) {
    final difference = date1.difference(date2).abs();
    return difference.inDays <= days;
  }
  
  /// Calculate correct tax amounts based on German tax law
  /// Returns a map with 'incomeTax' and 'capitalGainsTax'
  static Map<String, double> calculateCorrectTaxes(TransactionModel transaction) {
    if (transaction.type != TransactionType.sale || !transaction.isSold) {
      return {'incomeTax': 0.0, 'capitalGainsTax': 0.0};
    }
    
    // Income tax on ESPP discount (already taxed at purchase)
    final incomeTax = transaction.incomeTaxOnDiscount;
    
    // Capital gains tax calculation (German law)
    // Tax basis is FMV at purchase (not discounted price)
    final taxBasis = transaction.fmvPerShare * transaction.quantity;
    final saleProceeds = transaction.totalSaleProceeds ?? 0;
    final capitalGain = saleProceeds - taxBasis;
    
    // Only tax positive gains
    final capitalGainsTax = capitalGain > 0 
        ? capitalGain * transaction.capitalGainsTaxRate 
        : 0.0;
    
    return {
      'incomeTax': incomeTax,
      'capitalGainsTax': capitalGainsTax,
    };
  }
}