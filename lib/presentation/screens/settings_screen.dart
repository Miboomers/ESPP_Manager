import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/auth_service.dart';
import '../../core/security/cloud_password_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/transaction_model.dart';
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
          // E-Mail-Bestätigungsstatus
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              final user = authSnapshot.data;
              final isEmailVerified = user?.emailVerified ?? false;
              final emailMessage = isEmailVerified 
                ? 'E-Mail bestätigt - Cloud-Sync aktiv'
                : 'E-Mail-Bestätigung erforderlich - Cloud-Sync deaktiviert';
              
              return ListTile(
                leading: Icon(
                  isEmailVerified ? Icons.email : Icons.email_outlined,
                  color: isEmailVerified ? Colors.green : Colors.orange,
                ),
                title: Text(isEmailVerified ? 'E-Mail bestätigt' : 'E-Mail-Bestätigung erforderlich'),
                subtitle: Text(emailMessage),
                trailing: isEmailVerified 
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _refreshEmailVerification(context),
                      tooltip: 'E-Mail-Status prüfen',
                    ),
              );
            },
          ),
          
          // Sync Status (nur wenn E-Mail bestätigt)
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              final user = authSnapshot.data;
              final isEmailVerified = user?.emailVerified ?? false;
              
              if (!isEmailVerified) return const SizedBox.shrink();
              
              return const ListTile(
                leading: Icon(Icons.cloud_done),
                title: Text('Synchronisiert'),
                subtitle: Text('Daten werden automatisch synchronisiert'),
              );
            },
          ),
          
          // Manueller Sync
          ListTile(
            leading: const Icon(Icons.sync, color: Colors.blue),
            title: const Text('Manuell synchronisieren'),
            subtitle: const Text('Sofortige Synchronisierung aller Daten'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _performManualSync(context),
          ),
          
          // Cloud-Passwort ändern
          ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.orange),
            title: const Text('Cloud-Passwort ändern'),
            subtitle: const Text('Verschlüsselungspasswort für Cloud-Daten ändern'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showCloudPasswordChangeDialog(context),
          ),
          
          // Cloud Data Overview
          ListTile(
            leading: const Icon(Icons.cloud_queue),
            title: const Text('Cloud-Daten anzeigen'),
            subtitle: const Text('Übersicht der gespeicherten Daten in der Cloud'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showCloudDataOverview(context),
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
                // Change local PIN only
                final authService = AuthService();
                await authService.changePin(currentPin, newPin);
                
                Navigator.pop(context);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('PIN erfolgreich geändert'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
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
  
  /// Refresh email verification status
  Future<void> _refreshEmailVerification(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Reload user to get latest email verification status
        await user.reload();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                user.emailVerified 
                  ? '✅ E-Mail bestätigt! Cloud-Sync ist jetzt aktiv.'
                  : '⚠️ E-Mail noch nicht bestätigt. Bitte prüfen Sie Ihren Posteingang.'
              ),
              backgroundColor: user.emailVerified ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Prüfen des E-Mail-Status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Perform the actual logout
  Future<void> _performLogout() async {
    try {
      // 1. End Firebase Auth session
      //await FirebaseAuth.instance.signOut();
      
      // 2. Reset local authentication state
      await _authService.logout();
      
      // 3. Navigate back to login screen - simplified navigation
      if (mounted) {
        // Use a simple navigation approach to avoid null issues
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/', // Use root route instead of '/login'
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      // Don't rethrow - just log the error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout abgeschlossen, aber es gab einen Fehler: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  /// Show cloud data overview
  Future<void> _showCloudDataOverview(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Lade Cloud-Daten...'),
            ],
          ),
        ),
      );
      
      // Get cloud data
      final cloudService = ref.read(cloudSyncServiceProvider);
      final cloudData = await cloudService.getCloudDataOverview();
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      // Show data overview
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cloud-Daten Übersicht'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCloudDataSection('Transaktionen', cloudData.transactions),
                  const SizedBox(height: 16),
                  _buildCloudDataSection('Einstellungen', cloudData.settings),
                  const SizedBox(height: 16),
                  _buildCloudDataSection('PIN-Informationen', cloudData.pinInfo),
                  const SizedBox(height: 16),
                  _buildCloudDataSection('Letzte Synchronisation', cloudData.lastSync),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden der Cloud-Daten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Build cloud data section
  Widget _buildCloudDataSection(String title, CloudDataInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${info.status}'),
              if (info.count != null) Text('Anzahl: ${info.count}'),
              if (info.lastModified != null) Text('Letzte Änderung: ${info.lastModified}'),
              if (info.details != null) Text('Details: ${info.details}'),
            ],
          ),
        ),
      ],
    );
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

  /// Zeigt den Dialog zur Änderung des Cloud-Passworts
  Future<void> _showCloudPasswordChangeDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showPasswords = false;
    
    return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Cloud-Passwort ändern'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '⚠️ Wichtiger Hinweis:\n'
                    'Das Ändern des Cloud-Passworts führt dazu, dass alle Cloud-Daten neu verschlüsselt werden. '
                    'Dieser Vorgang kann einige Minuten dauern.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Aktuelles Passwort
                  TextField(
                    controller: currentPasswordController,
                    obscureText: !showPasswords,
                    decoration: InputDecoration(
                      labelText: 'Aktuelles Cloud-Passwort',
                      hintText: 'Geben Sie Ihr aktuelles Passwort ein',
                      suffixIcon: IconButton(
                        icon: Icon(showPasswords ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => showPasswords = !showPasswords),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Neues Passwort
                  TextField(
                    controller: newPasswordController,
                    obscureText: !showPasswords,
                    decoration: InputDecoration(
                      labelText: 'Neues Cloud-Passwort',
                      hintText: 'Mindestens 8 Zeichen',
                      suffixIcon: IconButton(
                        icon: Icon(showPasswords ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => showPasswords = !showPasswords),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Passwort bestätigen
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !showPasswords,
                    decoration: InputDecoration(
                      labelText: 'Neues Passwort bestätigen',
                      hintText: 'Passwort wiederholen',
                      suffixIcon: IconButton(
                        icon: Icon(showPasswords ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => showPasswords = !showPasswords),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Toggle für alle Passwörter
                  Row(
                    children: [
                      Checkbox(
                        value: showPasswords,
                        onChanged: (value) => setState(() => showPasswords = value ?? false),
                      ),
                      const Text('Alle Passwörter anzeigen'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final currentPassword = currentPasswordController.text;
                    final newPassword = newPasswordController.text;
                    final confirmPassword = confirmPasswordController.text;
                    
                    // Validierung
                    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bitte füllen Sie alle Felder aus.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (newPassword.length < 8) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Das neue Passwort muss mindestens 8 Zeichen haben.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (newPassword != confirmPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Die neuen Passwörter stimmen nicht überein.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    // Cloud-Passwort-Änderung durchführen
                    try {
                      Navigator.of(context).pop();
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cloud-Passwort wird geändert...'),
                            backgroundColor: Colors.blue,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                      
                      // Cloud-Passwort-Änderung durchführen
                      final cloudService = ref.read(cloudSyncServiceProvider);
                      await cloudService.changeCloudPassword(currentPassword, newPassword);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Cloud-Passwort erfolgreich geändert!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Fehler bei Passwort-Änderung: $e'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Passwort ändern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Führt eine manuelle Cloud-Synchronisierung durch
  Future<void> _performManualSync(BuildContext context) async {
    try {
      // Zeige Lade-Indikator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Synchronisiere mit der Cloud...'),
              ],
            ),
            duration: Duration(seconds: 30), // Länger für Sync-Vorgang
          ),
        );
      }

      // Hole Cloud-Service
      final cloudService = ref.read(cloudSyncServiceProvider);
      
      // WICHTIG: Setze den Callback für Provider-Updates
      cloudService.setDataUpdateCallback((transactions, settings) async {
        debugPrint('🔄 Data update callback received: ${transactions.length} transactions');
        
        try {
          // Aktualisiere lokale Provider mit den neuen Daten
          final transactionsNotifier = ref.read(transactionsProvider.notifier);
          
          // Hole aktuelle lokale Transaktionen
          final currentTransactions = await ref.read(transactionsProvider.future);
          debugPrint('🔍 Current local transactions: ${currentTransactions.length}');
          
          // Lösche alle lokalen Transaktionen
          debugPrint('🗑️ Deleting ${currentTransactions.length} local transactions...');
          for (final transaction in currentTransactions) {
            await transactionsNotifier.deleteTransaction(transaction.id);
          }
          debugPrint('✅ All local transactions deleted');
          
          // Füge alle neuen Transaktionen hinzu
          debugPrint('➕ Adding ${transactions.length} new transactions...');
          for (final transaction in transactions) {
            await transactionsNotifier.addTransaction(transaction);
          }
          debugPrint('✅ All new transactions added');
          
          // Aktualisiere Einstellungen
          if (settings != null) {
            debugPrint('⚙️ Updating settings...');
            final settingsNotifier = ref.read(settingsProvider.notifier);
            await settingsNotifier.updateSettings(settings);
            debugPrint('✅ Settings updated');
          }
          
          // Force Provider-Refresh
          debugPrint('🔄 Forcing provider refresh...');
          ref.invalidate(transactionsProvider);
          ref.invalidate(settingsProvider);
          
          debugPrint('✅ Provider update completed successfully');
          
        } catch (e) {
          debugPrint('❌ Error in data update callback: $e');
        }
      });
      
      // Prüfe ob Cloud-Sync aktiviert ist
      final syncStatus = await cloudService.syncStatusStream.first;
      if (syncStatus.state == SyncState.idle) {
        // 🔄 VOLLSTÄNDIGE manuelle Synchronisierung
        debugPrint('🔄 Starting full manual sync...');
        
        try {
          // 1. Lade alle Cloud-Daten herunter
          debugPrint('📥 Downloading all cloud data...');
          final cloudData = await cloudService.downloadAllData();
          debugPrint('✅ Downloaded ${cloudData.transactions.length} transactions from cloud');
          debugPrint('🔍 Cloud data details:');
          debugPrint('   - Transactions: ${cloudData.transactions.length}');
          debugPrint('   - Settings: ${cloudData.settings != null ? 'Available' : 'Not available'}');
          if (cloudData.transactions.isNotEmpty) {
            debugPrint('   - First transaction: ${cloudData.transactions.first.id}');
            debugPrint('   - Last transaction: ${cloudData.transactions.last.id}');
          }
          
          // 2. Aktualisiere lokale Provider mit Cloud-Daten
          debugPrint('💾 Updating local providers with cloud data...');
          await _updateLocalProvidersWithCloudData(cloudData);
          debugPrint('✅ Local providers updated successfully');
          
          // 3. Lade alle lokalen Änderungen in die Cloud hoch
          debugPrint('📤 Uploading local changes to cloud...');
          await cloudService.syncPendingChanges();
          debugPrint('✅ Local changes uploaded to cloud');
          
          // 4. WICHTIG: Warte kurz und prüfe den finalen Zustand
          await Future.delayed(const Duration(milliseconds: 500));
          final finalTransactions = await ref.read(transactionsProvider.future);
          debugPrint('🔍 Final check: ${finalTransactions.length} transactions in provider');
          
          if (mounted) {
            // Zeige detaillierte Informationen in der App
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('✅ Synchronisierung erfolgreich'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📥 ${cloudData.transactions.length} Transaktionen aus der Cloud geladen'),
                    if (cloudData.settings != null) 
                      const Text('⚙️ Einstellungen aktualisiert'),
                    const SizedBox(height: 8),
                    Text('🔍 Lokaler Provider: ${finalTransactions.length} Transaktionen'),
                    const SizedBox(height: 8),
                    if (finalTransactions.length > 0)
                      const Text('💡 Schauen Sie jetzt in Ihr Portfolio - die Daten sollten sichtbar sein!')
                    else
                      const Text('⚠️ Daten wurden geladen, aber der Provider wurde nicht aktualisiert!'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Verstanden'),
                  ),
                ],
              ),
            );
          }
          
        } catch (e) {
          debugPrint('❌ Error during manual sync: $e');
          debugPrint('❌ Error stack: ${StackTrace.current}');
          
          if (mounted) {
            // Zeige detaillierte Fehlerinformationen
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('❌ Synchronisierung fehlgeschlagen'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ein Fehler ist aufgetreten:'),
                    const SizedBox(height: 8),
                    Text('$e', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text('🔍 Fehlerdetails wurden in der Konsole protokolliert.'),
                    const SizedBox(height: 8),
                    const Text('💡 Versuchen Sie es später erneut oder kontaktieren Sie den Support.'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Verstanden'),
                  ),
                ],
              ),
            );
          }
        }
        
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Cloud-Sync läuft bereits (${_getSyncStatusText(syncStatus.state)})'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Manuelle Synchronisierung fehlgeschlagen: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Aktualisiert lokale Provider mit Cloud-Daten
  Future<void> _updateLocalProvidersWithCloudData(
    ({List<TransactionModel> transactions, SettingsModel? settings}) cloudData,
  ) async {
    try {
      debugPrint('💾 Updating local providers with cloud data...');
      
      // WICHTIG: Verwende eine andere Strategie - direkte Provider-Manipulation
      final transactionsNotifier = ref.read(transactionsProvider.notifier);
      
      // Hole aktuelle lokale Transaktionen
      final currentTransactions = await ref.read(transactionsProvider.future);
      debugPrint('🔍 Current local transactions: ${currentTransactions.length}');
      
      // Lösche alle lokalen Transaktionen
      debugPrint('🗑️ Deleting ${currentTransactions.length} local transactions...');
      for (final transaction in currentTransactions) {
        debugPrint('   - Deleting: ${transaction.id}');
        await transactionsNotifier.deleteTransaction(transaction.id);
      }
      debugPrint('✅ All local transactions deleted');
      
      // Warte kurz, bis alle Löschungen abgeschlossen sind
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Füge alle Cloud-Transaktionen hinzu
      debugPrint('➕ Adding ${cloudData.transactions.length} cloud transactions...');
      for (final transaction in cloudData.transactions) {
        debugPrint('   - Adding: ${transaction.id}');
        await transactionsNotifier.addTransaction(transaction);
      }
      debugPrint('✅ All cloud transactions added');
      
      // Warte kurz, bis alle Hinzufügungen abgeschlossen sind
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Aktualisiere Einstellungen
      if (cloudData.settings != null) {
        debugPrint('⚙️ Updating settings...');
        final settingsNotifier = ref.read(settingsProvider.notifier);
        await settingsNotifier.updateSettings(cloudData.settings!);
        debugPrint('✅ Settings updated');
      } else {
        debugPrint('ℹ️ No settings to update');
      }
      
      // WICHTIG: Force Provider-Refresh
      debugPrint('🔄 Forcing provider refresh...');
      ref.invalidate(transactionsProvider);
      ref.invalidate(settingsProvider);
      
      // Warte kurz und prüfe den finalen Zustand
      await Future.delayed(const Duration(milliseconds: 500));
      final finalTransactions = await ref.read(transactionsProvider.future);
      debugPrint('🔍 Final state: ${finalTransactions.length} transactions in provider');
      
      debugPrint('✅ Local providers successfully updated');
      
    } catch (e) {
      debugPrint('❌ Failed to update local providers: $e');
      debugPrint('❌ Error stack: ${StackTrace.current}');
      rethrow;
    }
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