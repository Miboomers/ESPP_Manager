import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/auth_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../data/models/settings_model.dart';
import '../providers/settings_provider.dart';
import '../providers/stock_price_provider.dart';
import '../providers/transactions_provider.dart';
import 'auth/cloud_auth_screen.dart';
import 'security/trusted_devices_screen.dart';
import 'security/mfa_setup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _authService = AuthService();
  
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: settings.when(
        data: (settingsData) => ListView(
          children: [
            _buildSecuritySection(context, settingsData),
            const Divider(height: 32),
            _buildDefaultsSection(context, settingsData),
            const Divider(height: 32),
            _buildDisplaySection(context, settingsData),
            const Divider(height: 32),
            _buildDataSection(context, settingsData),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Fehler: $error'),
        ),
      ),
    );
  }

  Widget _buildSecuritySection(BuildContext context, SettingsModel settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Sicherheit',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.pin),
          title: const Text('PIN ändern'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showChangePinDialog(context),
        ),
        FutureBuilder<bool>(
          future: _authService.isBiometricAvailable(),
          builder: (context, snapshot) {
            if (snapshot.data == true) {
              return SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Biometrische Authentifizierung'),
                subtitle: const Text('Face ID / Touch ID verwenden'),
                value: settings.biometricEnabled,
                onChanged: (value) async {
                  await _authService.setBiometricEnabled(value);
                  ref.read(settingsProvider.notifier).updateSettings(
                    settings.copyWith(biometricEnabled: value),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
        ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('Auto-Lock'),
          subtitle: Text('Nach ${settings.autoLockMinutes} Minuten'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showAutoLockDialog(context, settings),
        ),
        const Divider(height: 1),
        _buildCloudSyncSection(context, settings),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Abmelden', style: TextStyle(color: Colors.red)),
          subtitle: const Text('Session beenden und zur PIN-Anmeldung zurückkehren'),
          onTap: () => _showLogoutDialog(context),
        ),
      ],
    );
  }
  
  Widget _buildCloudSyncSection(BuildContext context, SettingsModel settings) {
    final cloudService = ref.watch(cloudSyncServiceProvider);
    // Temporarily disable syncStatus to isolate the issue
    // final syncStatus = ref.watch(syncStatusProvider);
    
    // Simple Firebase check - always enable the toggle for testing
    bool isFirebaseInitialized = true;  // Force enable for testing
    
    
    // Use StreamBuilder to reactively watch Firebase Auth state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final currentUser = snapshot.data;
        
        return Column(
          children: [
            ListTile(
              leading: Icon(
                Icons.cloud_sync,
                color: currentUser != null ? Colors.green : null,
              ),
              title: const Text('Cloud Synchronisation'),
              subtitle: Text(
                currentUser != null 
                  ? 'Aktiv - ${currentUser.email}'
                  : isFirebaseInitialized 
                    ? 'Bereit für Aktivierung'
                    : 'Firebase nicht verfügbar',
              ),
              trailing: Switch(
                value: currentUser != null,
                onChanged: isFirebaseInitialized ? (value) async {
                  if (value) {
                    // Navigate to Cloud Auth Screen
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CloudAuthScreen(
                          isInitialSetup: true,
                        ),
                      ),
                    );
                    
                    if (result == true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cloud Sync aktiviert'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    // Disable cloud sync
                    await _disableCloudSync();
                  }
                } : null,
              ),
            ),
            
            if (currentUser != null) ...[
          // Sync Status
          const ListTile(
            leading: Icon(Icons.cloud_done),
            title: Text('Synchronisiert'),
            subtitle: Text('Daten werden automatisch synchronisiert'),
          ),
          
          // MFA Settings
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Zwei-Faktor-Authentifizierung'),
            subtitle: const Text('Zusätzliche Sicherheit für Ihr Konto'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MFASetupScreen(),
                ),
              );
            },
          ),
          
          // Trusted Devices
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Vertrauenswürdige Geräte'),
            subtitle: const Text('Geräte verwalten, die ohne MFA zugreifen'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrustedDevicesScreen(),
                ),
              );
            },
          ),
          
          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cloud-Konto abmelden'),
            onTap: () => _showSignOutDialog(context),
          ),
            ],
          ],
        );
      },
    );
  }
  
  String _getSyncStatusText(SyncState state) {
    switch (state) {
      case SyncState.idle:
        return 'Synchronisiert';
      case SyncState.syncing:
        return 'Synchronisiere...';
      case SyncState.error:
        return 'Sync-Fehler';
      case SyncState.offline:
        return 'Offline - wartet auf Verbindung';
    }
  }
  
  String _formatLastSync(DateTime lastSync) {
    final difference = DateTime.now().difference(lastSync);
    if (difference.inMinutes < 1) {
      return 'Gerade eben';
    } else if (difference.inHours < 1) {
      return 'Vor ${difference.inMinutes} Min.';
    } else if (difference.inDays < 1) {
      return 'Vor ${difference.inHours} Std.';
    } else {
      return 'Vor ${difference.inDays} Tagen';
    }
  }
  
  Future<void> _disableCloudSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cloud Sync deaktivieren?'),
        content: const Text(
          'Ihre Daten bleiben lokal gespeichert, werden aber nicht mehr zwischen Geräten synchronisiert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Deaktivieren'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      final cloudService = ref.read(cloudSyncServiceProvider);
      await cloudService.disableCloudSync();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud Sync deaktiviert'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  Future<void> _showSignOutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Von Cloud abmelden?'),
        content: const Text(
          'Sie können sich jederzeit wieder anmelden, um Ihre Daten zu synchronisieren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erfolgreich abgemeldet')),
        );
      }
    }
  }

  Widget _buildDefaultsSection(BuildContext context, SettingsModel settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Standardwerte',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.percent),
          title: const Text('Lohnsteuersatz'),
          subtitle: Text('${(settings.defaultIncomeTaxRate * 100).toStringAsFixed(0)}%'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showTaxRateDialog(
            context,
            'Lohnsteuersatz',
            settings.defaultIncomeTaxRate,
            (value) {
              ref.read(settingsProvider.notifier).updateSettings(
                settings.copyWith(defaultIncomeTaxRate: value),
              );
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.account_balance),
          title: const Text('Kapitalertragsteuersatz'),
          subtitle: Text('${(settings.defaultCapitalGainsTaxRate * 100).toStringAsFixed(0)}%'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showTaxRateDialog(
            context,
            'Kapitalertragsteuersatz',
            settings.defaultCapitalGainsTaxRate,
            (value) {
              ref.read(settingsProvider.notifier).updateSettings(
                settings.copyWith(defaultCapitalGainsTaxRate: value),
              );
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.business),
          title: const Text('Aktien-Symbol'),
          subtitle: Text(settings.defaultStockSymbol),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showStockSymbolDialog(context, settings),
        ),
      ],
    );
  }

  Widget _buildDisplaySection(BuildContext context, SettingsModel settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Anzeige',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.attach_money),
          title: const Text('Währung'),
          subtitle: Text(settings.displayCurrency),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showCurrencyDialog(context, settings),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.show_chart),
          title: const Text('Live-Kurse anzeigen'),
          subtitle: const Text('Aktuelle Kurse automatisch abrufen'),
          value: settings.showLivePrices,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).updateSettings(
              settings.copyWith(showLivePrices: value),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataSection(BuildContext context, SettingsModel settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Daten',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.backup, color: Colors.blue),
          title: const Text('Daten exportieren'),
          subtitle: const Text('Verschlüsseltes Backup erstellen'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            // TODO: Implement backup
          },
        ),
        ListTile(
          leading: const Icon(Icons.restore, color: Colors.green),
          title: const Text('Daten importieren'),
          subtitle: const Text('Backup wiederherstellen'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            // TODO: Implement restore
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.upload_file, color: Colors.indigo),
          title: const Text('Fidelity CSV Import'),
          subtitle: const Text('ESPP-Daten aus Fidelity importieren'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.pushNamed(context, '/import');
          },
        ),
        ListTile(
          leading: const Icon(Icons.bug_report, color: Colors.purple),
          title: const Text('API Debug'),
          subtitle: const Text('Aktienkurs-API testen & diagnostizieren'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showApiDebugDialog(context, settings),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Alle Daten löschen'),
          subtitle: const Text('Unwiderruflich löschen'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _showDeleteDataDialog(context),
        ),
      ],
    );
  }

  Future<void> _showChangePinDialog(BuildContext context) async {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('PIN ändern'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bitte geben Sie Ihre aktuelle PIN und die neue PIN ein.\n\nAlle Cloud-Daten werden mit der neuen PIN neu verschlüsselt.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: currentPinController,
                decoration: const InputDecoration(
                  labelText: 'Aktuelle PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPinController,
                decoration: const InputDecoration(
                  labelText: 'Neue PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPinController,
                decoration: const InputDecoration(
                  labelText: 'Neue PIN bestätigen',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final currentPin = currentPinController.text.trim();
              final newPin = newPinController.text.trim();
              final confirmPin = confirmPinController.text.trim();
              
              // Validation
              if (currentPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bitte füllen Sie alle Felder aus'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (newPin != confirmPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Neue PINs stimmen nicht überein'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (newPin.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN muss mindestens 4 Ziffern haben'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              // Verify current PIN
              final authService = AuthService();
              final isValid = await authService.verifyPin(currentPin);
              if (!isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Aktuelle PIN ist falsch'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                // Change PIN
                await authService.setPin(newPin);
                
                // Re-encrypt all cloud data with new PIN
                final cloudService = ref.read(cloudSyncServiceProvider);
                await cloudService.reEncryptWithNewPin(currentPin, newPin);
                
                Navigator.pop(context);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN erfolgreich geändert. Alle Cloud-Daten wurden neu verschlüsselt.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Ändern der PIN: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('PIN ändern'),
          ),
        ],
      ),
    );
  }
  
  /// Show logout confirmation dialog
  Future<void> _showLogoutDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text(
          'Möchten Sie sich wirklich abmelden?\n\n'
          '• Ihre Daten bleiben verschlüsselt gespeichert\n'
          '• Cloud-Synchronisation wird beendet\n'
          '• Sie müssen sich beim nächsten Start mit Ihrer PIN anmelden',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                // Close dialog first
              Navigator.pop(context);
              
              // Show loading indicator
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sie werden abgemeldet...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              
              // Perform logout
              await _performLogout();
              
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Abmelden: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
  }
  
  /// Perform the actual logout
  Future<void> _performLogout() async {
    try {
      // 1. End Firebase Auth session
      await FirebaseAuth.instance.signOut();
      
      // 2. Reset local authentication state
      await _authService.logout();
      
      // 3. Navigate back to login screen
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login', // Assuming you have a login route
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      rethrow;
    }
  }

  Future<void> _showAutoLockDialog(
    BuildContext context,
    SettingsModel settings,
  ) async {
    final options = [1, 5, 10, 15, 30];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto-Lock Zeit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((minutes) {
            return RadioListTile<int>(
              title: Text('$minutes Minuten'),
              value: minutes,
              groupValue: settings.autoLockMinutes,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).updateSettings(
                    settings.copyWith(autoLockMinutes: value),
                  );
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showTaxRateDialog(
    BuildContext context,
    String title,
    double currentValue,
    Function(double) onSave,
  ) async {
    final controller = TextEditingController(
      text: (currentValue * 100).toStringAsFixed(0),
    );
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Steuersatz in %',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0 && value <= 100) {
                onSave(value / 100);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _showStockSymbolDialog(
    BuildContext context,
    SettingsModel settings,
  ) async {
    final controller = TextEditingController(text: settings.defaultStockSymbol);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktien-Symbol'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Symbol (z.B. RMD, AAPL, MSFT)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(defaultStockSymbol: controller.text.toUpperCase()),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCurrencyDialog(
    BuildContext context,
    SettingsModel settings,
  ) async {
    final currencies = ['EUR', 'USD'];
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anzeigewährung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies.map((currency) {
            return RadioListTile<String>(
              title: Text(currency),
              value: currency,
              groupValue: settings.displayCurrency,
              onChanged: (value) {
                if (value != null) {
                  ref.read(settingsProvider.notifier).updateSettings(
                    settings.copyWith(displayCurrency: value),
                  );
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showDeleteDataDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Daten löschen?'),
        content: const Text(
          'Diese Aktion kann nicht rückgängig gemacht werden. '
          'Alle Transaktionen und Einstellungen werden gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteAllData(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  Future<void> _showApiDebugDialog(BuildContext context, SettingsModel settings) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Debug'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aktien-Symbol: ${settings.defaultStockSymbol}', 
                   style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('API Test:'),
              Consumer(
                builder: (context, ref, child) {
                  final stockPriceAsync = ref.watch(stockPriceProvider(settings.defaultStockSymbol));
                  
                  return stockPriceAsync.when(
                    data: (stockPrice) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✅ API funktioniert', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Symbol: ${stockPrice.symbol}'),
                          Text('Preis: \$${stockPrice.price.toStringAsFixed(2)}'),
                          Text('Änderung: ${stockPrice.changePercent.toStringAsFixed(2)}%'),
                          Text('Zeitstempel: ${stockPrice.timestamp}'),
                        ],
                      ),
                    ),
                    loading: () => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text('API wird getestet...', style: TextStyle(color: Colors.blue[700])),
                        ],
                      ),
                    ),
                    error: (error, stack) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('❌ API Fehler', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Fehler: $error', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          const Text('Mögliche Ursachen:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Text('• Alpha Vantage Rate Limit (5/min)', style: TextStyle(fontSize: 11)),
                          const Text('• Netzwerkproblem', style: TextStyle(fontSize: 11)),
                          const Text('• API Server offline', style: TextStyle(fontSize: 11)),
                          const Text('• Ungültiges Symbol', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Cache leeren und neu laden
              final cacheRepo = ref.read(stockCacheRepositoryProvider);
              await cacheRepo.clearExpiredCache();
              await cacheRepo.clearAllCache(); // Alle Cache-Daten löschen
              ref.invalidate(stockPriceProvider(settings.defaultStockSymbol));
            },
            child: const Text('Cache leeren'),
          ),
          TextButton(
            onPressed: () {
              // Force refresh der API
              ref.invalidate(stockPriceProvider(settings.defaultStockSymbol));
            },
            child: const Text('Neu laden'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllData(BuildContext context) async {
    try {
      // Alle Transaktionen löschen
      await ref.read(transactionsProvider.notifier).deleteAllTransactions();
      
      // Alle Cache-Daten löschen
      final cacheRepo = ref.read(stockCacheRepositoryProvider);
      await cacheRepo.clearAllCache();
      
      // Alle Provider invalidieren
      ref.invalidate(transactionsProvider);
      ref.invalidate(stockPriceProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alle Daten wurden erfolgreich gelöscht'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Zurück zum Home Screen navigieren
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}