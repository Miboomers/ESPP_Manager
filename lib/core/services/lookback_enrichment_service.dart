import '../utils/lookback_parser.dart';
import '../../data/models/transaction_model.dart';

/// Service für das Anreichern von Verkaufstransaktionen mit Lookback-Daten
class LookbackEnrichmentService {
  
  /// Reichert bestehende Verkaufstransaktionen mit Lookback-Daten an
  /// 
  /// [existingSales] - Alle bestehenden Verkaufstransaktionen
  /// [lookbackData] - Geparste Lookback-Daten von Fidelity
  /// 
  /// Returns: Liste der angereicherten Verkaufstransaktionen
  static List<TransactionModel> enrichSalesWithLookbackData(
    List<TransactionModel> existingSales,
    List<LookbackData> lookbackData,
  ) {
    print('🔍 DEBUG: Lookback-Enrichment gestartet');
    print('  - Verkaufstransaktionen: ${existingSales.length}');
    print('  - Lookback-Datensätze: ${lookbackData.length}');
    
    final enrichedSales = <TransactionModel>[];
    
    for (final sale in existingSales) {
      print('\n📊 Verarbeite Verkauf: ${sale.id}');
      print('  - Verkaufsdatum: ${sale.saleDate}');
      print('  - Ursprüngliches Kaufdatum: ${sale.purchaseDate}');
      print('  - Verkaufte Menge: ${sale.quantity}');
      
      // Finde passende Lookback-Daten für diesen Verkauf
      final matchingLookback = _findMatchingLookbackData(sale, lookbackData);
      
      if (matchingLookback != null) {
        print('  ✅ Passende Lookback-Daten gefunden:');
        print('    - Offering Period: ${matchingLookback.offeringPeriod}');
        print('    - Lookback FMV: ${matchingLookback.lookbackFmv}');
        print('    - FMV at Purchase: ${matchingLookback.fmvAtPurchase}');
        
        // Erstelle angereicherte Transaktion
        final enrichedSale = sale.copyWith(
          lookbackFmv: matchingLookback.lookbackFmv,
          offeringPeriod: matchingLookback.offeringPeriod,
          qualifiedDispositionDate: matchingLookback.qualifiedDispositionDate,
          updatedAt: DateTime.now(),
        );
        
        enrichedSales.add(enrichedSale);
        print('  🎯 Verkauf erfolgreich angereichert!');
      } else {
        print('  ❌ Keine passenden Lookback-Daten gefunden');
        // Verkauf ohne Lookback-Daten beibehalten
        enrichedSales.add(sale);
      }
    }
    
    final successfulEnrichments = enrichedSales.where((s) => s.lookbackFmv != null).length;
    print('\n📈 Enrichment-Ergebnis:');
    print('  - Erfolgreich angereichert: $successfulEnrichments von ${existingSales.length}');
    
    return enrichedSales;
  }
  
  /// Findet die passenden Lookback-Daten für eine Verkaufstransaktion
  static LookbackData? _findMatchingLookbackData(
    TransactionModel sale,
    List<LookbackData> lookbackData,
  ) {
    // Strategie 1: Exakte Übereinstimmung des Kaufdatums
    for (final lookback in lookbackData) {
      if (_isSamePurchaseDate(sale.purchaseDate, lookback.purchaseDate)) {
        print('    🎯 Exakte Kaufdatum-Übereinstimmung gefunden');
        return lookback;
      }
    }
    
    // Strategie 2: Kaufdatum liegt in der Offering Period
    for (final lookback in lookbackData) {
      if (_isPurchaseDateInOfferingPeriod(sale.purchaseDate, lookback.offeringPeriod)) {
        print('    🎯 Kaufdatum liegt in Offering Period: ${lookback.offeringPeriod}');
        return lookback;
      }
    }
    
    // Strategie 3: Nächstliegendes Kaufdatum (Fallback)
    LookbackData? closest;
    Duration? shortestDistance;
    
    for (final lookback in lookbackData) {
      final distance = sale.purchaseDate.difference(lookback.purchaseDate).abs();
      if (shortestDistance == null || distance < shortestDistance) {
        shortestDistance = distance;
        closest = lookback;
      }
    }
    
    // Akzeptiere nur wenn Abstand <= 7 Tage
    if (closest != null && shortestDistance != null && shortestDistance.inDays <= 7) {
      print('    🎯 Nächstliegendes Kaufdatum gefunden (${shortestDistance.inDays} Tage Unterschied)');
      return closest;
    }
    
    return null;
  }
  
  /// Prüft ob zwei Kaufdaten identisch sind (gleicher Tag)
  static bool _isSamePurchaseDate(DateTime saleOriginalPurchase, DateTime lookbackPurchase) {
    return saleOriginalPurchase.year == lookbackPurchase.year &&
           saleOriginalPurchase.month == lookbackPurchase.month &&
           saleOriginalPurchase.day == lookbackPurchase.day;
  }
  
  /// Prüft ob ein Kaufdatum in der Offering Period liegt
  static bool _isPurchaseDateInOfferingPeriod(DateTime purchaseDate, String offeringPeriod) {
    try {
      // Parse Offering Period (z.B. "NOV/01/2024 - APR/30/2025")
      final parts = offeringPeriod.split(' - ');
      if (parts.length != 2) return false;
      
      final startDate = _parseOfferingDate(parts[0].trim());
      final endDate = _parseOfferingDate(parts[1].trim());
      
      if (startDate == null || endDate == null) return false;
      
      return purchaseDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
             purchaseDate.isBefore(endDate.add(const Duration(days: 1)));
    } catch (e) {
      print('    ❌ Fehler beim Parsen der Offering Period: $offeringPeriod');
      return false;
    }
  }
  
  /// Parst ein Offering Period Datum (z.B. "NOV/01/2024")
  static DateTime? _parseOfferingDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      
      final monthStr = parts[0].toUpperCase();
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      
      final monthMap = {
        'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
        'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
      };
      
      final month = monthMap[monthStr];
      if (month == null) return null;
      
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }
  
  /// Validiert das Enrichment-Ergebnis
  static EnrichmentResult validateEnrichment(
    List<TransactionModel> originalSales,
    List<TransactionModel> enrichedSales,
  ) {
    final totalSales = originalSales.length;
    final enrichedCount = enrichedSales.where((s) => s.lookbackFmv != null).length;
    final successRate = totalSales > 0 ? (enrichedCount / totalSales) : 0.0;
    
    return EnrichmentResult(
      totalSales: totalSales,
      enrichedSales: enrichedCount,
      successRate: successRate,
      warnings: _generateWarnings(originalSales, enrichedSales),
    );
  }
  
  static List<String> _generateWarnings(
    List<TransactionModel> originalSales,
    List<TransactionModel> enrichedSales,
  ) {
    final warnings = <String>[];
    
    final unenrichedSales = enrichedSales.where((s) => s.lookbackFmv == null).length;
    if (unenrichedSales > 0) {
      warnings.add('$unenrichedSales Verkäufe konnten nicht mit Lookback-Daten angereichert werden');
    }
    
    return warnings;
  }
}

/// Ergebnis des Lookback-Enrichment-Prozesses
class EnrichmentResult {
  final int totalSales;
  final int enrichedSales;
  final double successRate;
  final List<String> warnings;
  
  EnrichmentResult({
    required this.totalSales,
    required this.enrichedSales,
    required this.successRate,
    required this.warnings,
  });
  
  bool get isSuccessful => successRate >= 0.8; // 80% Success Rate
  
  String get summary => 
    'Lookback-Enrichment: $enrichedSales von $totalSales Verkäufen angereichert '
    '(${(successRate * 100).toStringAsFixed(1)}%)';
}