class NumberFormatter {
  // Format quantity with up to 4 decimal places, but remove trailing zeros
  static String formatQuantity(double quantity) {
    // If it's a whole number, show no decimals
    if (quantity == quantity.roundToDouble()) {
      return quantity.toStringAsFixed(0);
    }
    
    // Format with up to 4 decimal places
    String formatted = quantity.toStringAsFixed(4);
    
    // Remove trailing zeros after decimal point
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      // Remove decimal point if no decimals remain
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }
    
    return formatted;
  }
  
  // Format currency values (always 2 decimal places)
  static String formatCurrency(double value) {
    return value.toStringAsFixed(2);
  }
  
  // Format percentages (no decimal places)
  static String formatPercentage(double value) {
    return value.toStringAsFixed(0);
  }
  
  // Parse German number format (comma as decimal separator) to double
  static double? parseGermanNumber(String value) {
    if (value.isEmpty) return null;
    
    // Replace comma with dot for parsing
    final normalizedValue = value.replaceAll(',', '.');
    
    return double.tryParse(normalizedValue);
  }
}