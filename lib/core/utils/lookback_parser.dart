import 'package:intl/intl.dart';

class LookbackData {
  final String offeringPeriod;
  final DateTime purchaseDate;
  final double lookbackFmv;
  final double fmvAtPurchase;
  final double actualPrice;
  final double shares;
  final double purchaseValue;
  final DateTime qualifiedDispositionDate;
  final String accountType;

  LookbackData({
    required this.offeringPeriod,
    required this.purchaseDate,
    required this.lookbackFmv,
    required this.fmvAtPurchase,
    required this.actualPrice,
    required this.shares,
    required this.purchaseValue,
    required this.qualifiedDispositionDate,
    required this.accountType,
  });

  Map<String, dynamic> toJson() => {
    'offeringPeriod': offeringPeriod,
    'purchaseDate': purchaseDate.toIso8601String(),
    'lookbackFmv': lookbackFmv,
    'fmvAtPurchase': fmvAtPurchase,
    'actualPrice': actualPrice,
    'shares': shares,
    'purchaseValue': purchaseValue,
    'qualifiedDispositionDate': qualifiedDispositionDate.toIso8601String(),
    'accountType': accountType,
  };

  factory LookbackData.fromJson(Map<String, dynamic> json) => LookbackData(
    offeringPeriod: json['offeringPeriod'],
    purchaseDate: DateTime.parse(json['purchaseDate']),
    lookbackFmv: json['lookbackFmv'],
    fmvAtPurchase: json['fmvAtPurchase'],
    actualPrice: json['actualPrice'],
    shares: json['shares'],
    purchaseValue: json['purchaseValue'],
    qualifiedDispositionDate: DateTime.parse(json['qualifiedDispositionDate']),
    accountType: json['accountType'],
  );
}

class LookbackParser {
  static final _monthYearFormat = DateFormat('MMM/dd/yyyy');
  static final _germanDateFormat = DateFormat('dd.MM.yyyy');
  
  // Header detection patterns for both languages
  static final _germanHeaders = [
    'angebotszeitraum',
    'kaufdatum',
    'fmv zum zeitpunkt',
    'erwerbspreis',
    'erwerbsmenge',
    'erwerbswert',
    'qualifizierter veräußerungszeitpunkt',
    'erwerbseinzahlung auf',
    'maklerkonto',
    'brokerage-konto'
  ];
  
  
  /// Parse Fidelity lookback data from clipboard text (supports German and English)
  static List<LookbackData> parseFromClipboard(String clipboardText) {
    final List<LookbackData> results = [];
    final lines = clipboardText.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    // Detect language from header or content
    bool isGerman = _isGermanFormat(clipboardText);
    
    for (final line in lines) {
      try {
        final lookbackData = _parseLine(line, isGerman);
        if (lookbackData != null) {
          results.add(lookbackData);
        }
      } catch (e) {
        // Skip invalid lines
        // Silently skip parse errors in production
      }
    }
    
    return results;
  }
  
  static bool _isGermanFormat(String text) {
    final lowerText = text.toLowerCase();
    
    // Check for German keywords
    for (final header in _germanHeaders) {
      if (lowerText.contains(header)) {
        return true;
      }
    }
    
    // Check for typical German date format (APR/30/2025 vs 30.04.2025)
    // German format still uses APR/30/2025 in the data, but headers are German
    return false;
  }
  
  static LookbackData? _parseLine(String line, bool isGerman) {
    // Clean up the line
    line = line.trim();
    
    // Skip header lines or empty lines
    if (_isHeaderLine(line)) {
      return null;
    }
    
    // Split by multiple spaces or tabs - be more flexible
    final parts = line.split(RegExp(r'\s{2,}|\t'));
    
    // We expect at least 8 parts for a valid data line (account type might be combined)
    if (parts.length < 8) {
      return null;
    }
    
    try {
      // Extract offering period (e.g., "MAY/01/2023 - OCT/31/2023" or "NOV/01/2024 - APR/30/2025")
      final offeringPeriod = parts[0].trim();
      
      // Extract purchase date
      final purchaseDateStr = parts[1].trim();
      final purchaseDate = _parseDate(purchaseDateStr);
      
      // Extract prices (remove $ and USD)
      final lookbackFmv = _parsePrice(parts[2]);
      final fmvAtPurchase = _parsePrice(parts[3]);
      final actualPrice = _parsePrice(parts[4]);
      
      // Extract shares (remove "shares" text)
      final shares = _parseShares(parts[5]);
      
      // Extract purchase value
      final purchaseValue = _parsePrice(parts[6]);
      
      // Extract qualified disposition date
      final qualifiedDateStr = parts[7].trim();
      final qualifiedDispositionDate = _parseDate(qualifiedDateStr);
      
      // Extract account type (last part)
      // Handle both "Maklerkonto (Brokerage-Konto)", "Brokerage Account", and single "Brokerage"
      String accountType = 'Brokerage';
      if (parts.length > 8) {
        accountType = parts.sublist(8).join(' ').trim();
      } else if (parts.length == 8) {
        // Sometimes account type might be missing or combined with previous field
        accountType = 'Brokerage';
      }
      
      // Normalize account type
      if (accountType.toLowerCase().contains('maklerkonto') || 
          accountType.toLowerCase().contains('brokerage')) {
        accountType = 'Brokerage';
      } else if (accountType.isEmpty) {
        accountType = 'Brokerage';
      }
      
      return LookbackData(
        offeringPeriod: offeringPeriod,
        purchaseDate: purchaseDate,
        lookbackFmv: lookbackFmv,
        fmvAtPurchase: fmvAtPurchase,
        actualPrice: actualPrice,
        shares: shares,
        purchaseValue: purchaseValue,
        qualifiedDispositionDate: qualifiedDispositionDate,
        accountType: accountType,
      );
    } catch (e) {
      throw Exception('Failed to parse line: $e');
    }
  }
  
  static bool _isHeaderLine(String line) {
    final lowerLine = line.toLowerCase();
    
    // Check if line starts with date pattern (likely data, not header)
    if (RegExp(r'^[a-z]{3}/\d{2}/\d{4}').hasMatch(lowerLine)) {
      return false; // This is likely a data line
    }
    
    // Check German headers - but exclude account type at end
    final headerKeywords = [
      'angebotszeitraum',
      'kaufdatum', 
      'fmv zum zeitpunkt',
      'erwerbspreis',
      'erwerbsmenge',
      'erwerbswert',
      'qualifizierter veräußerungszeitpunkt',
      'offering period',
      'purchase date',
      'fmv at offering start',
      'fmv at purchase date',
      'purchase price',
      'purchase quantity',
      'purchase value',
      'qualified disposition date'
    ];
    
    // Check if line contains actual header keywords (not just account types)
    for (final header in headerKeywords) {
      if (lowerLine.contains(header)) {
        return true;
      }
    }
    
    return false;
  }
  
  static DateTime _parseDate(String dateStr) {
    // Handle different date formats
    dateStr = dateStr.trim().toUpperCase();
    
    // Manual parsing for APR/30/2025 format
    if (RegExp(r'^[A-Z]{3}/\d{1,2}/\d{4}$').hasMatch(dateStr)) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final monthStr = parts[0];
        final day = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        
        // Map month abbreviations to numbers
        final monthMap = {
          'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
          'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
        };
        
        final month = monthMap[monthStr];
        if (month != null) {
          return DateTime(year, month, day);
        }
      }
    }
    
    // Try standard format parsers as fallback
    try {
      return _monthYearFormat.parse(dateStr);
    } catch (e) {
      // Try German format (30.04.2025)
      try {
        return _germanDateFormat.parse(dateStr);
      } catch (e2) {
        // Try ISO format
        if (dateStr.contains('-')) {
          try {
            return DateTime.parse(dateStr);
          } catch (e3) {
            // Continue
          }
        }
        throw Exception('Invalid date format: $dateStr');
      }
    }
  }
  
  static double _parsePrice(String priceStr) {
    // Remove currency symbols and text
    priceStr = priceStr
        .replaceAll('\$', '')  // Remove literal $ symbol
        .replaceAll('USD', '')
        .replaceAll('EUR', '')
        .replaceAll('€', '')
        .replaceAll(',', '')  // Remove thousand separators
        .trim();
    
    return double.parse(priceStr);
  }
  
  static double _parseShares(String sharesStr) {
    // Remove "shares" text in both languages
    sharesStr = sharesStr
        .replaceAll('shares', '')
        .replaceAll('share', '')
        .replaceAll('Aktien', '')
        .replaceAll('Aktie', '')
        .trim();
    
    return double.parse(sharesStr);
  }
  
  /// Validate parsed data
  static bool validateLookbackData(LookbackData data) {
    // Basic validation rules
    if (data.actualPrice > data.lookbackFmv) {
      return false; // Actual price should be lower (15% discount)
    }
    
    if (data.actualPrice > data.fmvAtPurchase) {
      return false; // Actual price should be lower than FMV
    }
    
    if (data.shares <= 0 || data.purchaseValue <= 0) {
      return false; // Must have positive values
    }
    
    // Check if purchase value roughly matches shares * actual price
    final expectedValue = data.shares * data.actualPrice;
    final difference = (data.purchaseValue - expectedValue).abs();
    if (difference > 1.0) { // Allow $1 rounding difference
      return false;
    }
    
    return true;
  }
}