import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/mfa_service.dart';

class TrustedDevicesScreen extends ConsumerStatefulWidget {
  const TrustedDevicesScreen({super.key});

  @override
  ConsumerState<TrustedDevicesScreen> createState() => _TrustedDevicesScreenState();
}

class _TrustedDevicesScreenState extends ConsumerState<TrustedDevicesScreen> {
  final MFAService _mfaService = MFAService();
  List<TrustedDevice> _trustedDevices = [];
  bool _isLoading = true;
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _loadTrustedDevices();
  }

  Future<void> _loadTrustedDevices() async {
    setState(() => _isLoading = true);
    try {
      _currentDeviceId = await _mfaService.getDeviceId();
      final devices = await _mfaService.getTrustedDevices();
      
      // Markiere aktuelles Gerät
      for (var device in devices) {
        if (device.deviceId == _currentDeviceId) {
          device = TrustedDevice(
            deviceId: device.deviceId,
            deviceName: device.deviceName,
            platform: device.platform,
            trustedUntil: device.trustedUntil,
            lastUsed: device.lastUsed,
            isCurrentDevice: true,
          );
        }
      }
      
      setState(() {
        _trustedDevices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vertrauenswürdige Geräte'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrustedDevices,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trustedDevices.isEmpty
              ? _buildEmptyState()
              : _buildDevicesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTrustDeviceDialog,
        icon: const Icon(Icons.add_moderator),
        label: const Text('Dieses Gerät vertrauen'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Keine vertrauenswürdigen Geräte',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fügen Sie dieses Gerät hinzu, um MFA zu überspringen',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trustedDevices.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildInfoCard();
        }
        
        final device = _trustedDevices[index - 1];
        return _buildDeviceCard(device);
      },
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sicherheitshinweis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vertrauenswürdige Geräte müssen keine MFA durchführen. Entfernen Sie unbekannte Geräte sofort!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(TrustedDevice device) {
    final isExpired = DateTime.now().isAfter(device.trustedUntil);
    final isCurrentDevice = device.deviceId == _currentDeviceId;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: isCurrentDevice ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrentDevice 
              ? Theme.of(context).primaryColor 
              : Colors.transparent,
          width: isCurrentDevice ? 2 : 0,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpired 
              ? Colors.red[100] 
              : isCurrentDevice 
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.grey[200],
          child: Text(
            device.platformIcon,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.deviceName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isExpired ? Colors.red : null,
                ),
              ),
            ),
            if (isCurrentDevice)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Dieses Gerät',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isExpired ? Icons.timer_off : Icons.timer,
                  size: 14,
                  color: isExpired ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isExpired 
                      ? 'Abgelaufen' 
                      : 'Noch ${device.timeRemaining}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired ? Colors.red : Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (device.lastUsed != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Zuletzt: ${_formatDate(device.lastUsed!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'remove') {
              _removeDevice(device);
            } else if (value == 'extend') {
              _extendTrust(device);
            }
          },
          itemBuilder: (context) => [
            if (!isExpired && !isCurrentDevice)
              const PopupMenuItem(
                value: 'extend',
                child: Row(
                  children: [
                    Icon(Icons.update, size: 20),
                    SizedBox(width: 8),
                    Text('Verlängern'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: isCurrentDevice ? Colors.orange : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCurrentDevice ? 'Vertrauen entziehen' : 'Entfernen',
                    style: TextStyle(
                      color: isCurrentDevice ? Colors.orange : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrustDeviceDialog() {
    int selectedDays = 30;
    String deviceName = '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerät als vertrauenswürdig markieren'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Gerätename (optional)',
                  hintText: 'z.B. iPhone von Michael',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => deviceName = value,
              ),
              const SizedBox(height: 16),
              const Text('Vertrauen für:'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDurationChip(
                    '30 Tage',
                    30,
                    selectedDays == 30,
                    () => setDialogState(() => selectedDays = 30),
                  ),
                  _buildDurationChip(
                    '90 Tage',
                    90,
                    selectedDays == 90,
                    () => setDialogState(() => selectedDays = 90),
                  ),
                  _buildDurationChip(
                    '1 Jahr',
                    365,
                    selectedDays == 365,
                    () => setDialogState(() => selectedDays = 365),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nach Ablauf müssen Sie sich erneut mit MFA anmelden.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
              Navigator.pop(context);
              await _trustDevice(selectedDays, deviceName);
            },
            child: const Text('Vertrauen'),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(String label, int days, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Future<void> _trustDevice(int days, String? customName) async {
    try {
      await _mfaService.trustDevice(
        days: days,
        customName: customName?.isEmpty ?? true ? null : customName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gerät für $days Tage als vertrauenswürdig markiert'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _loadTrustedDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _removeDevice(TrustedDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerät entfernen?'),
        content: Text(
          device.deviceId == _currentDeviceId
              ? 'Möchten Sie das Vertrauen für dieses Gerät wirklich entziehen? Sie müssen beim nächsten Login MFA durchführen.'
              : 'Möchten Sie "${device.deviceName}" wirklich aus den vertrauenswürdigen Geräten entfernen?',
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
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _mfaService.removeTrustedDevice(device.deviceId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gerät wurde entfernt'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        await _loadTrustedDevices();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    }
  }

  Future<void> _extendTrust(TrustedDevice device) async {
    // Similar dialog wie _showTrustDeviceDialog aber für Verlängerung
    _showTrustDeviceDialog(); // Vereinfacht für jetzt
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Gerade eben';
    } else if (difference.inHours < 1) {
      return 'Vor ${difference.inMinutes} Min.';
    } else if (difference.inDays < 1) {
      return 'Vor ${difference.inHours} Std.';
    } else if (difference.inDays < 7) {
      return 'Vor ${difference.inDays} Tagen';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}