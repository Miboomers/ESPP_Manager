class MarketHours {
  static const Map<String, Map<String, dynamic>> _marketData = {
    'NASDAQ': {
      'timezone': 'America/New_York',
      'openHour': 9,
      'openMinute': 30,
      'closeHour': 16,
      'closeMinute': 0,
      'name': 'NASDAQ',
    },
    'NYSE': {
      'timezone': 'America/New_York',
      'openHour': 9,
      'openMinute': 30,
      'closeHour': 16,
      'closeMinute': 0,
      'name': 'NYSE',
    },
  };

  static String getMarketName(String symbol) {
    // Most common US stocks trade on NASDAQ or NYSE
    // This is a simplified mapping - in production you'd want a proper symbol-to-exchange mapping
    final commonNasdaq = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA', 'META', 'NFLX', 'RMD'];
    final commonNYSE = ['JPM', 'JNJ', 'V', 'PG', 'MA', 'UNH', 'HD', 'DIS'];
    
    if (commonNasdaq.contains(symbol)) {
      return 'NASDAQ';
    } else if (commonNYSE.contains(symbol)) {
      return 'NYSE';
    }
    
    // Default to NASDAQ for unknown symbols
    return 'NASDAQ';
  }

  static bool isMarketOpen(String symbol, [DateTime? checkTime]) {
    final now = checkTime ?? DateTime.now();
    final marketName = getMarketName(symbol);
    final marketInfo = _marketData[marketName]!;
    
    // Convert to Eastern Time (market timezone)
    // Note: This is simplified - doesn't handle DST properly
    // In production, you'd use a proper timezone library
    final easternTime = now.toUtc().subtract(const Duration(hours: 5));
    
    // Check if it's a weekday
    if (easternTime.weekday > 5) { // Saturday = 6, Sunday = 7
      return false;
    }
    
    // Check if it's within market hours
    final marketOpen = DateTime(
      easternTime.year,
      easternTime.month,
      easternTime.day,
      marketInfo['openHour'],
      marketInfo['openMinute'],
    );
    
    final marketClose = DateTime(
      easternTime.year,
      easternTime.month,
      easternTime.day,
      marketInfo['closeHour'],
      marketInfo['closeMinute'],
    );
    
    return easternTime.isAfter(marketOpen) && easternTime.isBefore(marketClose);
  }

  static String getMarketStatus(String symbol, [DateTime? checkTime]) {
    final isOpen = isMarketOpen(symbol, checkTime);
    final marketName = getMarketName(symbol);
    
    if (isOpen) {
      return '$marketName: Geöffnet';
    } else {
      return '$marketName: Geschlossen';
    }
  }

  static String getNextMarketOpen(String symbol, [DateTime? fromTime]) {
    final now = fromTime ?? DateTime.now();
    final easternTime = now.toUtc().subtract(const Duration(hours: 5));
    
    // If it's currently market hours, return today's close time
    if (isMarketOpen(symbol, fromTime)) {
      return 'Schließt um 22:00 MEZ';
    }
    
    // If it's after market hours on a weekday, next open is tomorrow
    if (easternTime.weekday <= 5 && easternTime.hour >= 16) {
      return 'Öffnet morgen um 15:30 MEZ';
    }
    
    // If it's before market hours on a weekday, opens today
    if (easternTime.weekday <= 5 && easternTime.hour < 9 || 
        (easternTime.hour == 9 && easternTime.minute < 30)) {
      return 'Öffnet heute um 15:30 MEZ';
    }
    
    // If it's weekend, opens on Monday
    return 'Öffnet Montag um 15:30 MEZ';
  }
}