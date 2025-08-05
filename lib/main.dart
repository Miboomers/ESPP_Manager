import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/security/encryption_service.dart';
import 'core/security/secure_storage_service.dart';
import 'data/models/transaction_model.dart';
import 'data/models/settings_model.dart';
import 'data/repositories/stock_cache_repository.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/add_purchase_screen.dart';
import 'presentation/screens/portfolio_screen.dart';
import 'presentation/screens/transactions_screen.dart';
import 'presentation/screens/sell_transaction_screen.dart';
import 'presentation/screens/reports_screen.dart';
import 'presentation/screens/export_screen.dart';
import 'presentation/screens/recalculate_screen.dart';
import 'presentation/screens/import_screen.dart';
import 'presentation/screens/import_lookback_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive adapters
  Hive.registerAdapter(TransactionModelAdapter());
  Hive.registerAdapter(TransactionTypeAdapter());
  Hive.registerAdapter(SettingsModelAdapter());
  
  // Initialize encryption
  final encryptionService = EncryptionService();
  await encryptionService.initialize();
  
  // Initialize secure storage
  final secureStorageService = SecureStorageService(encryptionService);
  await secureStorageService.initialize();
  
  // Initialize cache repository
  final stockCacheRepository = StockCacheRepository();
  await stockCacheRepository.init();
  
  // Clean up expired cache on startup
  await stockCacheRepository.clearExpiredCache();
  
  runApp(
    const ProviderScope(
      child: ESPPManagerApp(),
    ),
  );
}

class ESPPManagerApp extends ConsumerWidget {
  const ESPPManagerApp({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'ESPP Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: const TextTheme().apply(fontSizeFactor: 0.9),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: const TextTheme().apply(fontSizeFactor: 0.9),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/portfolio': (context) => const PortfolioScreen(),
        '/transactions': (context) => const TransactionsScreen(),
        '/add-transaction': (context) => const AddPurchaseScreen(),
        '/sell-transaction': (context) => const SellTransactionScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/export': (context) => const ExportScreen(),
        '/recalculate': (context) => const RecalculateScreen(),
        '/import': (context) => const ImportScreen(),
        '/import-lookback': (context) => const ImportLookbackScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
