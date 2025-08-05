import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  bool _obscurePin = true;
  bool _isSettingPin = false;
  String? _confirmPin;

  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final isPinSet = await _authService.isPinSet();
    if (!isPinSet) {
      setState(() {
        _isSettingPin = true;
      });
    } else {
      final biometricEnabled = await _authService.isBiometricEnabled();
      if (biometricEnabled) {
        _authenticateWithBiometric();
      }
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() => _isLoading = true);
    
    final authenticated = await _authService.authenticateWithBiometric();
    
    setState(() => _isLoading = false);
    
    if (authenticated && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _handlePinSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (_isSettingPin) {
        if (_confirmPin == null) {
          setState(() {
            _confirmPin = _pinController.text;
            _pinController.clear();
          });
          // Auto-focus für PIN-Bestätigung
          Future.delayed(const Duration(milliseconds: 100), () {
            _focusNode.requestFocus();
          });
        } else {
          if (_confirmPin == _pinController.text) {
            await _authService.setPin(_pinController.text);
            
            final biometricAvailable = await _authService.isBiometricAvailable();
            if (biometricAvailable && mounted) {
              _showBiometricSetupDialog();
            } else if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          } else {
            _showError('PINs stimmen nicht überein');
            setState(() {
              _confirmPin = null;
              _pinController.clear();
            });
            // Auto-focus nach Fehler
            Future.delayed(const Duration(milliseconds: 100), () {
              _focusNode.requestFocus();
            });
          }
        }
      } else {
        final authenticated = await _authService.authenticate(pin: _pinController.text);
        if (authenticated && mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          _showError('Falscher PIN');
          _pinController.clear();
          // Auto-focus nach falscher PIN
          Future.delayed(const Duration(milliseconds: 100), () {
            _focusNode.requestFocus();
          });
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showBiometricSetupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Biometrische Authentifizierung'),
        content: const Text(
          'Möchten Sie die biometrische Authentifizierung (Face ID/Touch ID) aktivieren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Nein'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      await _authService.setBiometricEnabled(true);
    }
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'ESPP Manager',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSettingPin
                        ? (_confirmPin == null ? 'PIN erstellen' : 'PIN bestätigen')
                        : 'PIN eingeben',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: TextFormField(
                      controller: _pinController,
                      focusNode: _focusNode,
                      autofocus: true,
                      obscureText: _obscurePin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        hintText: '6-stelliger PIN',
                        prefixIcon: const Icon(Icons.pin),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePin ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePin = !_obscurePin;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Bitte PIN eingeben';
                        }
                        if (value.length != 6) {
                          return 'PIN muss 6-stellig sein';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handlePinSubmit(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handlePinSubmit,
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _isSettingPin
                                    ? (_confirmPin == null ? 'Weiter' : 'PIN erstellen')
                                    : 'Anmelden',
                              ),
                      ),
                    ),
                  ),
                  if (!_isSettingPin) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<bool>(
                      future: _authService.isBiometricEnabled(),
                      builder: (context, snapshot) {
                        if (snapshot.data == true) {
                          return TextButton.icon(
                            onPressed: _isLoading ? null : _authenticateWithBiometric,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Mit Biometrie anmelden'),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}