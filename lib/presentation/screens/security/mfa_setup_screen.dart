import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/mfa_service.dart';

class MFASetupScreen extends ConsumerStatefulWidget {
  const MFASetupScreen({super.key});

  @override
  ConsumerState<MFASetupScreen> createState() => _MFASetupScreenState();
}

class _MFASetupScreenState extends ConsumerState<MFASetupScreen> {
  final MFAService _mfaService = MFAService();
  MFAMethod? _selectedMethod;
  bool _isLoading = false;
  String _verificationCode = '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zwei-Faktor-Authentifizierung'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schützen Sie Ihr Konto mit 2FA',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Wählen Sie eine Methode für die Zwei-Faktor-Authentifizierung:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            _buildMFAOption(
              icon: Icons.sms,
              title: 'SMS',
              subtitle: 'Code per SMS empfangen',
              method: MFAMethod.sms,
            ),
            
            _buildMFAOption(
              icon: Icons.security,
              title: 'Authenticator App',
              subtitle: 'Google Authenticator oder ähnlich',
              method: MFAMethod.totp,
            ),
            
            _buildMFAOption(
              icon: Icons.email,
              title: 'E-Mail',
              subtitle: 'Code per E-Mail empfangen',
              method: MFAMethod.email,
            ),
            
            if (_selectedMethod != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              _buildVerificationSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMFAOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required MFAMethod method,
  }) {
    final isSelected = _selectedMethod == method;
    
    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          size: 32,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
            : null,
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
      ),
    );
  }

  Widget _buildVerificationSection() {
    switch (_selectedMethod) {
      case MFAMethod.sms:
        return _buildSMSVerification();
      case MFAMethod.totp:
        return _buildTOTPSetup();
      case MFAMethod.email:
        return _buildEmailVerification();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSMSVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Telefonnummer eingeben:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            hintText: '+49 123 456789',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendSMSCode,
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('SMS-Code senden'),
        ),
      ],
    );
  }

  Widget _buildTOTPSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Authenticator App einrichten:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // QR Code Placeholder
        Container(
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('QR-Code wird geladen...'),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        const Text(
          'Scannen Sie den QR-Code mit Google Authenticator oder einer ähnlichen App.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        
        TextField(
          decoration: const InputDecoration(
            labelText: 'Verifizierungscode eingeben',
            hintText: '123456',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) => _verificationCode = value,
        ),
        
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyTOTP,
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Authenticator aktivieren'),
        ),
      ],
    );
  }

  Widget _buildEmailVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'E-Mail-Verifizierung:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ein Verifizierungscode wird an Ihre registrierte E-Mail-Adresse gesendet.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendEmailCode,
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('E-Mail-Code senden'),
        ),
      ],
    );
  }

  Future<void> _sendSMSCode() async {
    setState(() => _isLoading = true);
    try {
      // SMS-Code senden
      await Future.delayed(const Duration(seconds: 2)); // Simulation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS-Code wurde gesendet!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyTOTP() async {
    if (_verificationCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte geben Sie einen 6-stelligen Code ein')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      await _mfaService.enableMFA(method: MFAMethod.totp);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('2FA erfolgreich aktiviert!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendEmailCode() async {
    setState(() => _isLoading = true);
    try {
      await _mfaService.enableMFA(method: MFAMethod.email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Mail-Code wurde gesendet!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}