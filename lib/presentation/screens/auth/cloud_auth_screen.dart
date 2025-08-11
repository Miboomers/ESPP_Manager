import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../../../core/security/mfa_service.dart';
import '../../../core/security/auth_service.dart';
import '../../providers/transactions_provider.dart';
import '../../providers/settings_provider.dart';

class CloudAuthScreen extends ConsumerStatefulWidget {
  final bool isInitialSetup;
  
  const CloudAuthScreen({
    super.key,
    this.isInitialSetup = true,
  });

  @override
  ConsumerState<CloudAuthScreen> createState() => _CloudAuthScreenState();
}

class _CloudAuthScreenState extends ConsumerState<CloudAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _trustDevice = false;
  int _trustDays = 30;
  
  // Auth service für PIN-Zugriff
  late final AuthService _authService;
  
  @override
  void initState() {
    super.initState();
    _authService = AuthService();
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Cloud Sync einrichten' : 'Cloud Anmeldung'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isInitialSetup) ...[
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                ],
                
                _buildToggleButtons(),
                const SizedBox(height: 24),
                
                _buildEmailField(),
                const SizedBox(height: 16),
                
                _buildPasswordField(),
                const SizedBox(height: 16),
                
                if (!_isLogin) ...[
                  _buildConfirmPasswordField(),
                  const SizedBox(height: 16),
                ],
                
                if (_isLogin) ...[
                  _buildTrustDeviceOption(),
                  const SizedBox(height: 16),
                ],
                
                _buildSubmitButton(),
                const SizedBox(height: 16),
                
                if (!widget.isInitialSetup)
                  _buildAlternativeAuthOptions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Cloud Synchronisation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Mit Cloud Sync können Sie:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureItem('Daten auf mehreren Geräten nutzen'),
            _buildFeatureItem('Automatische Backups erstellen'),
            _buildFeatureItem('Ende-zu-Ende verschlüsselt speichern'),
            _buildFeatureItem('Jederzeit offline arbeiten'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggleButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLogin = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isLogin ? Theme.of(context).primaryColor : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'Anmelden',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isLogin ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLogin = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isLogin ? Theme.of(context).primaryColor : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'Registrieren',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isLogin ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'E-Mail',
        hintText: 'ihre.email@beispiel.de',
        prefixIcon: const Icon(Icons.email),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Bitte E-Mail eingeben';
        }
        if (!value.contains('@')) {
          return 'Bitte gültige E-Mail eingeben';
        }
        return null;
      },
    );
  }
  
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Passwort',
        hintText: _isLogin ? 'Ihr Passwort' : 'Mindestens 8 Zeichen',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Bitte Passwort eingeben';
        }
        if (!_isLogin && value.length < 8) {
          return 'Passwort muss mindestens 8 Zeichen haben';
        }
        return null;
      },
    );
  }
  
  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      decoration: InputDecoration(
        labelText: 'Passwort bestätigen',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Bitte Passwort bestätigen';
        }
        if (value != _passwordController.text) {
          return 'Passwörter stimmen nicht überein';
        }
        return null;
      },
    );
  }
  
  Widget _buildTrustDeviceOption() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Diesem Gerät vertrauen'),
              subtitle: Text(
                'MFA für $_trustDays Tage überspringen',
                style: const TextStyle(fontSize: 12),
              ),
              value: _trustDevice,
              onChanged: (value) => setState(() => _trustDevice = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_trustDevice) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTrustDurationChip('30 Tage', 30),
                  _buildTrustDurationChip('90 Tage', 90),
                  _buildTrustDurationChip('1 Jahr', 365),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrustDurationChip(String label, int days) {
    final isSelected = _trustDays == days;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _trustDays = days),
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
  
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              _isLogin ? 'Anmelden' : 'Registrieren',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
  
  Widget _buildAlternativeAuthOptions() {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('ODER'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _handleGoogleSignIn,
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text('Mit Google anmelden'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (Theme.of(context).platform == TargetPlatform.iOS)
          OutlinedButton.icon(
            onPressed: _handleAppleSignIn,
            icon: const Icon(Icons.apple, size: 28),
            label: const Text('Mit Apple anmelden'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (_isLogin) {
        await _handleLogin();
      } else {
        await _handleRegister();
      }
    } catch (e) {
      debugPrint('🔥 Firebase Auth Error: $e');
      if (mounted) {
        String errorMessage = 'Unbekannter Fehler';
        
        if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'Diese E-Mail-Adresse ist bereits registriert';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'Das Passwort ist zu schwach (min. 6 Zeichen)';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Ungültige E-Mail-Adresse';
        } else if (e.toString().contains('user-not-found')) {
          errorMessage = 'Benutzer nicht gefunden';
        } else if (e.toString().contains('wrong-password')) {
          errorMessage = 'Falsches Passwort';
        } else if (e.toString().contains('network-request-failed')) {
          errorMessage = 'Netzwerkfehler - bitte Internetverbindung prüfen';
        } else {
          errorMessage = 'Fehler: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _handleLogin() async {
    debugPrint('🔥 Attempting login for: ${_emailController.text.trim()}');
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    debugPrint('🔥 Login successful: ${credential.user?.email}');
    
    if (credential.user != null) {
      // Trust device if requested
      if (_trustDevice) {
        final mfaService = MFAService();
        await mfaService.trustDevice(days: _trustDays);
      }
      
      // Initialize cloud sync
      await _initializeCloudSync();
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }
  
  Future<void> _handleRegister() async {
    debugPrint('🔥 Attempting registration for: ${_emailController.text.trim()}');
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    debugPrint('🔥 Registration successful: ${credential.user?.email}');
    
    if (credential.user != null) {
      // Send verification email
      await credential.user!.sendEmailVerification();
      
      // Initialize cloud sync for new user
      await _initializeCloudSync();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrierung erfolgreich! Bitte E-Mail bestätigen.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }
  
  // Initialize cloud sync
  Future<void> _initializeCloudSync() async {
    try {
      final cloudService = ref.read(cloudSyncServiceProvider);
      
      // Get local data
      final transactionsAsync = ref.read(transactionsProvider);
      final settingsAsync = ref.read(settingsProvider);
      
      await transactionsAsync.when(
        data: (transactions) async {
          debugPrint('🔄 Local transactions loaded: ${transactions.length}');
          await settingsAsync.when(
            data: (settings) async {
              debugPrint('🔄 Local settings loaded, initializing cloud sync...');
              
              // Check if PIN is set
              if (!await _authService.isPinSet()) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Keine PIN gesetzt. Bitte setzen Sie zuerst eine PIN in den Einstellungen.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              
              // Show PIN input dialog for verification (only once)
              final pin = await _showPinInputDialog();
              if (pin == null) {
                debugPrint('❌ User cancelled PIN input');
                return;
              }
              
              // Verify PIN
              final isValid = await _authService.verifyPin(pin);
              if (!isValid) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Falsche PIN'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              
              // Initialize cloud sync with verified PIN
              await cloudService.enableCloudSync(
                localTransactions: transactions,
                localSettings: settings,
                pin: pin, // Use verified PIN
              );
              debugPrint('🔥 Cloud sync initialized with verified PIN!');
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cloud-Synchronisation mit App-PIN aktiviert'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            loading: () async {
              debugPrint('⚠️ Settings noch nicht geladen - warten...');
            },
            error: (error, stack) async {
              debugPrint('❌ Settings Fehler: $error');
            },
          );
        },
        loading: () async {
          debugPrint('⚠️ Transactions noch nicht geladen - warten...');
        },
        error: (error, stack) async {
          debugPrint('❌ Transactions Fehler: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Cloud sync initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloud-Sync Fehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Show PIN input dialog for cloud sync (only once)
  Future<String?> _showPinInputDialog() async {
    final pinController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('PIN für Cloud-Sync'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bitte geben Sie Ihre App-PIN ein, um die Cloud-Synchronisation zu aktivieren.\n\nDiese PIN wird für alle Cloud-Operationen verwendet.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'App-PIN',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.isNotEmpty) {
                Navigator.pop(context, pin);
              }
            },
            child: const Text('Bestätigen'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleGoogleSignIn() async {
    // TODO: Implement Google Sign-In
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google Sign-In noch nicht implementiert')),
    );
  }
  
  Future<void> _handleAppleSignIn() async {
    // TODO: Implement Apple Sign-In
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Apple Sign-In noch nicht implementiert')),
    );
  }
}