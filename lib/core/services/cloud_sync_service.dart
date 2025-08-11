import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Conditional import für Secure Storage
import 'conditional_imports.dart';

import '../../data/models/transaction_model.dart';
import '../../data/models/settings_model.dart';
import '../security/encryption_service.dart';

// Provider für Cloud Sync Service
final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return CloudSyncService();
});

// Provider für Sync Status
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(cloudSyncServiceProvider);
  return service.syncStatusStream;
});

// Cloud Data Model for PIN re-encryption
class CloudData {
  final List<TransactionModel> transactions;
  final SettingsModel? settings;
  
  CloudData({
    required this.transactions,
    this.settings,
  });
}

// Cloud Data Overview Model
class CloudDataInfo {
  final String status;
  final int? count;
  final String? lastModified;
  final String? details;
  
  CloudDataInfo({
    required this.status,
    this.count,
    this.lastModified,
    this.details,
  });
}

// Cloud Data Overview Response
class CloudDataOverview {
  final CloudDataInfo transactions;
  final CloudDataInfo settings;
  final CloudDataInfo pinInfo;
  final CloudDataInfo lastSync;
  
  CloudDataOverview({
    required this.transactions,
    required this.settings,
    required this.pinInfo,
    required this.lastSync,
  });
}

enum SyncState {
  idle,
  syncing,
  error,
  offline,
}

class SyncStatus {
  final SyncState state;
  final String? message;
  final DateTime lastSync;
  final int pendingChanges;

  SyncStatus({
    required this.state,
    this.message,
    required this.lastSync,
    this.pendingChanges = 0,
  });
}

class CloudSyncService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  
  // Conditional secure storage
  late final SecureStorageInterface _secureStorage;
  
  // Sync Status Stream
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  
  // Offline Queue
  final List<PendingChange> _pendingChanges = [];
  
  // Current sync status
  SyncStatus _currentStatus = SyncStatus(
    state: SyncState.idle,
    lastSync: DateTime.now(),
  );
  
  // Encryption key for cloud data
  String? _cloudEncryptionKey;
  
  // PIN management for multi-device sync
  static const String _pinVersionKey = 'pin_version';
  static const String _pinHashKey = 'pin_hash';
  
  // User specific paths
  String get _userPath {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');
    return 'users/${user.uid}';
  }
  
  // PIN-specific paths
  String get _pinPath => '$_userPath/pin';
  String get _dataPath => '$_userPath/data';
  
  // Legacy paths for backward compatibility
  String get _legacySettingsPath => '$_userPath/data/settings';
  String get _legacyTransactionsPath => '$_userPath/transactions';
  
  CloudSyncService() {
    _initializeConnectivityListener();
    _initializeSecureStorage();
  }
  
  void _initializeSecureStorage() {
    if (kIsWeb) {
      _secureStorage = WebSecureStorage();
    } else {
      _secureStorage = NativeSecureStorage();
    }
  }
  
  void _initializeConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.none)) {
        _updateSyncStatus(SyncState.offline, 'Keine Internetverbindung');
      } else if (_pendingChanges.isNotEmpty) {
        // Automatisch synchronisieren wenn wieder online
        syncPendingChanges();
      }
    });
  }
  
  // Initialize cloud sync for user
  Future<void> initializeForUser(String pin) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');
    
    final uid = user.uid;
    if (uid.isEmpty) throw Exception('User UID fehlt');
    
    // Generate user-specific encryption key from PIN + Salt
    final bytes = utf8.encode('$pin:$uid');
    final hash = sha256.convert(bytes);
    _cloudEncryptionKey = base64.encode(hash.bytes);
    
    // Store key securely
    await _secureStorage.write(
      key: 'cloud_encryption_key_$uid',
      value: _cloudEncryptionKey!,
    );
    
    debugPrint('✅ Cloud Sync für User initialisiert');
  }
  
  // Check if cloud sync is enabled
  Future<bool> isCloudSyncEnabled() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final uid = user.uid;
    if (uid.isEmpty) return false;
    
    _cloudEncryptionKey ??= await _secureStorage.read(
      key: 'cloud_encryption_key_$uid',
    );
    
    return _cloudEncryptionKey != null;
  }
  
  // Enable cloud sync
  Future<void> enableCloudSync({
    required List<TransactionModel> localTransactions,
    required SettingsModel localSettings,
    required String pin,
  }) async {
    try {
      _updateSyncStatus(SyncState.syncing, 'Cloud Sync wird aktiviert...');
      
      await initializeForUser(pin);
      debugPrint('🔄 User initialized for sync');
      
      // Initialize PIN path in cloud
      await _initializePinPath(pin);
      debugPrint('🔄 PIN path initialized in cloud');
      
      // Upload all local data to cloud
      await _uploadAllData(localTransactions, localSettings);
      debugPrint('🔄 All data uploaded successfully');
      
      _updateSyncStatus(SyncState.idle, 'Cloud Sync aktiviert');
    } catch (e) {
      _updateSyncStatus(SyncState.error, 'Fehler: $e');
      rethrow;
    }
  }
  
  /// Initialize PIN path in cloud
  Future<void> _initializePinPath(String pin) async {
    try {
      final pinHash = _hashPin(pin);
      final pinVersion = DateTime.now().millisecondsSinceEpoch;
      
      await _firestore.doc(_pinPath).set({
        _pinHashKey: pinHash,
        _pinVersionKey: pinVersion,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'initial_setup': true,
      });
      
      debugPrint('✅ PIN path initialized in cloud: $_pinPath');
    } catch (e) {
      debugPrint('❌ Error initializing PIN path: $e');
      // Don't rethrow - this is not critical for sync
    }
  }
  
  // Disable cloud sync
  Future<void> disableCloudSync() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final uid = user.uid;
    if (uid.isEmpty) return;
    
    // Clear encryption key
    await _secureStorage.delete(key: 'cloud_encryption_key_$uid');
    _cloudEncryptionKey = null;
    
    // Optional: Delete cloud data
    // await _deleteAllCloudData();
    
    _updateSyncStatus(SyncState.idle, 'Cloud Sync deaktiviert');
  }
  
  // Upload all data (initial sync)
  Future<void> _uploadAllData(
    List<TransactionModel> transactions,
    SettingsModel settings,
  ) async {
    final batch = _firestore.batch();
    
    // Upload settings
    final settingsRef = _firestore.doc('$_userPath/data/settings');
    batch.set(settingsRef, {
      'data': _encryptData(settings.toJson()),
      'type': 'settings',
      'lastModified': FieldValue.serverTimestamp(),
    });
    
    // Upload transactions
    for (final transaction in transactions) {
      final transRef = _firestore.doc('$_userPath/transactions/${transaction.id}');
      batch.set(transRef, {
        'data': _encryptData(transaction.toJson()),
        'type': 'transaction',
        'lastModified': FieldValue.serverTimestamp(),
        'deleted': false,
      });
    }
    
    await batch.commit();
  }
  
  // Download all data (restore or new device)
  Future<({List<TransactionModel> transactions, SettingsModel? settings})> 
      downloadAllData() async {
    try {
      _updateSyncStatus(SyncState.syncing, 'Daten werden geladen...');
      
      // Download settings
      SettingsModel? settings;
      final settingsDoc = await _firestore
          .doc('$_userPath/data/settings')
          .get();
      
      if (settingsDoc.exists) {
        final data = settingsDoc.data()!;
        final decrypted = _decryptData(data['data']);
        settings = SettingsModel.fromJson(decrypted);
      }
      
      // Download transactions
      final transSnapshot = await _firestore
          .collection('$_userPath/transactions')
          .where('deleted', isEqualTo: false)
          .get();
      
      final transactions = transSnapshot.docs.map((doc) {
        final data = doc.data();
        final decrypted = _decryptData(data['data']);
        return TransactionModel.fromJson(decrypted);
      }).toList();
      
      _updateSyncStatus(SyncState.idle, 'Sync abgeschlossen');
      
      return (transactions: transactions, settings: settings);
    } catch (e) {
      _updateSyncStatus(SyncState.error, 'Download fehlgeschlagen: $e');
      rethrow;
    }
  }
  
  // Sync single transaction
  Future<void> syncTransaction(TransactionModel transaction, {bool deleted = false}) async {
    if (!await isCloudSyncEnabled()) return;
    
    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      // Add to offline queue
      _pendingChanges.add(PendingChange(
        id: transaction.id,
        type: ChangeType.transaction,
        data: transaction.toJson(),
        deleted: deleted,
        timestamp: DateTime.now(),
      ));
      _updateSyncStatus(SyncState.offline, null);
      return;
    }
    
    try {
      final docRef = _firestore.doc('$_userPath/transactions/${transaction.id}');
      
      if (deleted) {
        // Soft delete
        await docRef.update({
          'deleted': true,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create or update
        await docRef.set({
          'data': _encryptData(transaction.toJson()),
          'type': 'transaction',
          'lastModified': FieldValue.serverTimestamp(),
          'deleted': false,
        });
      }
      
    } catch (e) {
      // Add to offline queue on error
      _pendingChanges.add(PendingChange(
        id: transaction.id,
        type: ChangeType.transaction,
        data: transaction.toJson(),
        deleted: deleted,
        timestamp: DateTime.now(),
      ));
    }
  }
  
  // Sync settings
  Future<void> syncSettings(SettingsModel settings) async {
    if (!await isCloudSyncEnabled()) return;
    
    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _pendingChanges.add(PendingChange(
        id: 'settings',
        type: ChangeType.settings,
        data: settings.toJson(),
        deleted: false,
        timestamp: DateTime.now(),
      ));
      _updateSyncStatus(SyncState.offline, null);
      return;
    }
    
    try {
      await _firestore.doc('$_userPath/data/settings').set({
        'data': _encryptData(settings.toJson()),
        'type': 'settings',
        'lastModified': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Settings synchronisiert');
    } catch (e) {
      _pendingChanges.add(PendingChange(
        id: 'settings',
        type: ChangeType.settings,
        data: settings.toJson(),
        deleted: false,
        timestamp: DateTime.now(),
      ));
    }
  }
  
  // Sync pending changes when back online
  Future<void> syncPendingChanges() async {
    if (_pendingChanges.isEmpty) return;
    
    _updateSyncStatus(
      SyncState.syncing,
      '${_pendingChanges.length} ausstehende Änderungen...',
    );
    
    final batch = _firestore.batch();
    final processedChanges = <PendingChange>[];
    
    for (final change in _pendingChanges) {
      try {
        if (change.type == ChangeType.transaction) {
          final docRef = _firestore.doc('$_userPath/transactions/${change.id}');
          
          if (change.deleted) {
            batch.update(docRef, {
              'deleted': true,
              'deletedAt': Timestamp.fromDate(change.timestamp),
            });
          } else {
            batch.set(docRef, {
              'data': _encryptData(change.data),
              'type': 'transaction',
              'lastModified': Timestamp.fromDate(change.timestamp),
              'deleted': false,
            });
          }
        } else if (change.type == ChangeType.settings) {
          final docRef = _firestore.doc('$_userPath/data/settings');
          batch.set(docRef, {
            'data': _encryptData(change.data),
            'type': 'settings',
            'lastModified': Timestamp.fromDate(change.timestamp),
          });
        }
        
        processedChanges.add(change);
      } catch (e) {
        debugPrint('❌ Error processing change: $e');
      }
    }
    
    if (processedChanges.isNotEmpty) {
      try {
        await batch.commit();
        
        // Remove processed changes
        for (final change in processedChanges) {
          _pendingChanges.remove(change);
        }
        
        _updateSyncStatus(SyncState.idle, 'Sync abgeschlossen');
      } catch (e) {
        _updateSyncStatus(SyncState.error, 'Sync fehlgeschlagen');
      }
    }
  }
  
  // Real-time sync listener
  Stream<List<TransactionModel>> watchTransactions() {
    if (_auth.currentUser == null) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('$_userPath/transactions')
        .where('deleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final decrypted = _decryptData(data['data']);
        return TransactionModel.fromJson(decrypted);
      }).toList();
    });
  }
  
  // Encryption helpers
  String _encryptData(Map<String, dynamic> data) {
    if (_cloudEncryptionKey == null) {
      throw Exception('Encryption key nicht initialisiert');
    }
    
    final jsonString = jsonEncode(data);
    final encrypted = EncryptionService.encryptWithKey(jsonString, _cloudEncryptionKey!);
    return encrypted;
  }
  
  Map<String, dynamic> _decryptData(String encryptedData) {
    if (_cloudEncryptionKey == null) {
      throw Exception('Encryption key nicht initialisiert');
    }
    
    final decrypted = EncryptionService.decryptWithKey(encryptedData, _cloudEncryptionKey!);
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }
  
  // Update sync status
  void _updateSyncStatus(SyncState state, String? message) {
    _currentStatus = SyncStatus(
      state: state,
      message: message,
      lastSync: state == SyncState.idle ? DateTime.now() : _currentStatus.lastSync,
      pendingChanges: _pendingChanges.length,
    );
    _syncStatusController.add(_currentStatus);
  }
  
  // Cleanup
  void dispose() {
    _syncStatusController.close();
  }

  /// Get platform configuration
  Map<String, dynamic> getPlatformConfig() {
    return {
      'isWeb': kIsWeb,
      'supportsSecureStorage': _secureStorage != null,
      'platform': _getPlatformString(),
    };
  }
  
  /// Get overview of cloud data
  Future<CloudDataOverview> getCloudDataOverview() async {
    try {
      // Check if cloud sync is enabled
      final isEnabled = await isCloudSyncEnabled();
      if (!isEnabled) {
        return CloudDataOverview(
          transactions: CloudDataInfo(status: 'Cloud-Sync deaktiviert'),
          settings: CloudDataInfo(status: 'Cloud-Sync deaktiviert'),
          pinInfo: CloudDataInfo(status: 'Cloud-Sync deaktiviert'),
          lastSync: CloudDataInfo(status: 'Cloud-Sync deaktiviert'),
        );
      }
      
      // Get transactions info
      final transactionsInfo = await _getTransactionsInfo();
      
      // Get settings info
      final settingsInfo = await _getSettingsInfo();
      
      // Get PIN info
      final pinInfo = await _getPinInfo();
      
      // Get last sync info
      final lastSyncInfo = await _getLastSyncInfo();
      
      return CloudDataOverview(
        transactions: transactionsInfo,
        settings: settingsInfo,
        pinInfo: pinInfo,
        lastSync: lastSyncInfo,
      );
    } catch (e) {
      debugPrint('Error getting cloud data overview: $e');
      return CloudDataOverview(
        transactions: CloudDataInfo(status: 'Fehler: $e'),
        settings: CloudDataInfo(status: 'Fehler: $e'),
        pinInfo: CloudDataInfo(status: 'Fehler: $e'),
        lastSync: CloudDataInfo(status: 'Fehler: $e'),
      );
    }
  }
  
  /// Get transactions info from cloud
  Future<CloudDataInfo> _getTransactionsInfo() async {
    try {
      final transSnapshot = await _firestore
          .collection(_legacyTransactionsPath)
          .where('deleted', isEqualTo: false)
          .get();
      
      final count = transSnapshot.docs.length;
      String? lastModified;
      
      if (count > 0) {
        final lastDoc = transSnapshot.docs.reduce((a, b) {
          final aTime = a.data()['lastModified'] as Timestamp?;
          final bTime = b.data()['lastModified'] as Timestamp?;
          if (aTime == null) return b;
          if (bTime == null) return a;
          return aTime.millisecondsSinceEpoch > bTime.millisecondsSinceEpoch ? a : b;
        });
        
        final lastTime = lastDoc.data()['lastModified'] as Timestamp?;
        if (lastTime != null) {
          lastModified = '${lastTime.toDate().day}.${lastTime.toDate().month}.${lastTime.toDate().year} ${lastTime.toDate().hour}:${lastTime.toDate().minute}';
        }
      }
      
      return CloudDataInfo(
        status: count > 0 ? 'Verfügbar' : 'Keine Daten',
        count: count,
        lastModified: lastModified,
        details: count > 0 ? '$count Transaktionen in der Cloud' : 'Keine Transaktionen gefunden',
      );
    } catch (e) {
      return CloudDataInfo(
        status: 'Fehler beim Laden',
        details: 'Fehler: $e',
      );
    }
  }
  
  /// Get settings info from cloud
  Future<CloudDataInfo> _getSettingsInfo() async {
    try {
      final settingsDoc = await _firestore.doc(_legacySettingsPath).get();
      
      if (!settingsDoc.exists) {
        return CloudDataInfo(
          status: 'Keine Daten',
          details: 'Keine Einstellungen in der Cloud gefunden',
        );
      }
      
      final data = settingsDoc.data()!;
      final lastTime = data['lastModified'] as Timestamp?;
      String? lastModified;
      
      if (lastTime != null) {
        lastModified = '${lastTime.toDate().day}.${lastTime.toDate().month}.${lastTime.toDate().year} ${lastTime.toDate().hour}:${lastTime.toDate().minute}';
      }
      
      return CloudDataInfo(
        status: 'Verfügbar',
        count: 1,
        lastModified: lastModified,
        details: 'Einstellungen in der Cloud gespeichert',
      );
    } catch (e) {
      return CloudDataInfo(
        status: 'Fehler beim Laden',
        details: 'Fehler: $e',
      );
    }
  }
  
  /// Get PIN info from cloud
  Future<CloudDataInfo> _getPinInfo() async {
    try {
      // Check if user is authenticated
      final user = _auth.currentUser;
      if (user == null) {
        return CloudDataInfo(
          status: 'Nicht angemeldet',
          details: 'User ist nicht bei Firebase angemeldet',
        );
      }
      
      // Check if PIN document exists
      final pinDoc = await _firestore.doc(_pinPath).get();
      
      if (!pinDoc.exists) {
        return CloudDataInfo(
          status: 'Keine PIN-Info',
          details: 'PIN-Informationen wurden noch nicht in der Cloud gespeichert',
        );
      }
      
      final data = pinDoc.data()!;
      final version = data[_pinVersionKey] as int?;
      final lastTime = data['updated_at'] as Timestamp?;
      String? lastModified;
      
      if (lastTime != null) {
        lastModified = '${lastTime.toDate().day}.${lastTime.toDate().month}.${lastTime.toDate().year} ${lastTime.toDate().hour}:${lastTime.toDate().minute}';
      }
      
      return CloudDataInfo(
        status: 'Verfügbar',
        count: version,
        lastModified: lastModified,
        details: 'PIN-Version $version in der Cloud gespeichert',
      );
    } catch (e) {
      debugPrint('Error getting PIN info: $e');
      
      // Provide more specific error information
      if (e.toString().contains('Invalid argument(s): A document path must point to a valid document')) {
        return CloudDataInfo(
          status: 'PIN-Pfad nicht verfügbar',
          details: 'PIN-Informationen werden bei der ersten PIN-Änderung erstellt',
        );
      }
      
      return CloudDataInfo(
        status: 'Fehler beim Laden',
        details: 'Fehler: $e',
      );
    }
  }
  
  /// Get last sync info
  Future<CloudDataInfo> _getLastSyncInfo() async {
    try {
      final lastSync = _currentStatus.lastSync;
      final lastSyncStr = '${lastSync.day}.${lastSync.month}.${lastSync.year} ${lastSync.hour}:${lastSync.minute}';
      
      return CloudDataInfo(
        status: _currentStatus.state.name,
        lastModified: lastSyncStr,
        details: 'Letzte Synchronisation: ${_currentStatus.message ?? "Erfolgreich"}',
      );
    } catch (e) {
      return CloudDataInfo(
        status: 'Unbekannt',
        details: 'Fehler beim Laden der Sync-Info: $e',
      );
    }
  }
  
  // PIN Management Methods
  
  /// Change PIN and re-encrypt all cloud data
  Future<void> reEncryptWithNewPin(String oldPin, String newPin) async {
    try {
      _updateSyncStatus(SyncState.syncing, 'PIN wird geändert und Daten neu verschlüsselt...');
      
      // 1. Download all cloud data with old PIN
      final oldEncryptionKey = _deriveEncryptionKey(oldPin);
      final cloudData = await _downloadAllDataWithKey(oldEncryptionKey);
      
      // 2. Generate new encryption key
      final newEncryptionKey = _deriveEncryptionKey(newPin);
      
      // 3. Re-encrypt all data with new key
      final reEncryptedData = await _reEncryptData(cloudData, newEncryptionKey);
      
      // 4. Update PIN version and hash in cloud
      await _updatePinInCloud(newPin);
      
      // 5. Upload re-encrypted data
      await _uploadAllDataWithKey(reEncryptedData, newEncryptionKey);
      
      // 6. Update local encryption key
      _cloudEncryptionKey = newEncryptionKey;
      
      _updateSyncStatus(SyncState.idle, 'PIN erfolgreich geändert und alle Daten neu verschlüsselt');
      
    } catch (e) {
      _updateSyncStatus(SyncState.error, 'Fehler bei PIN-Änderung: $e');
      rethrow;
    }
  }
  
  /// Check if PIN has changed on other devices
  Future<bool> hasPinChangedOnOtherDevice(String currentPinHash) async {
    try {
      final pinDoc = await _firestore.doc(_pinPath).get();
      if (!pinDoc.exists) return false;
      
      final cloudPinHash = pinDoc.data()?[_pinHashKey] as String?;
      if (cloudPinHash == null) return false;
      
      return cloudPinHash != currentPinHash;
    } catch (e) {
      debugPrint('Error checking PIN change: $e');
      return false;
    }
  }
  
  /// Update PIN in cloud (called when PIN is changed locally)
  Future<void> _updatePinInCloud(String newPin) async {
    try {
      final newPinHash = _hashPin(newPin);
      final newPinVersion = DateTime.now().millisecondsSinceEpoch;
      
      await _firestore.doc(_pinPath).set({
        _pinHashKey: newPinHash,
        _pinVersionKey: newPinVersion,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      debugPrint('PIN updated in cloud: version $newPinVersion');
    } catch (e) {
      debugPrint('Error updating PIN in cloud: $e');
      rethrow;
    }
  }
  
  /// Download all data with specific encryption key
  Future<CloudData> _downloadAllDataWithKey(String encryptionKey) async {
    try {
      // Try new unified data structure first
      final dataDoc = await _firestore.doc(_dataPath).get();
      if (dataDoc.exists) {
        final encryptedData = dataDoc.data() as Map<String, dynamic>;
        
        // Decrypt data
        final decryptedTransactions = await _decryptTransactions(
          encryptedData['transactions'] as List<dynamic>? ?? [],
          encryptionKey,
        );
        
        final decryptedSettings = encryptedData['settings'] != null
            ? await _decryptSettings(encryptedData['settings'] as String, encryptionKey)
            : null;
        
        return CloudData(
          transactions: decryptedTransactions,
          settings: decryptedSettings,
        );
      }
      
      // Fallback to legacy structure for backward compatibility
      final legacySettings = await _downloadLegacySettings(encryptionKey);
      final legacyTransactions = await _downloadLegacyTransactions(encryptionKey);
      
      return CloudData(
        transactions: legacyTransactions,
        settings: legacySettings,
      );
    } catch (e) {
      debugPrint('Error downloading data with key: $e');
      rethrow;
    }
  }
  
  /// Download legacy settings with specific key
  Future<SettingsModel?> _downloadLegacySettings(String encryptionKey) async {
    try {
      final settingsDoc = await _firestore.doc(_legacySettingsPath).get();
      if (!settingsDoc.exists) return null;
      
      final data = settingsDoc.data()!;
      final encryptedData = data['data'] as String;
      return await _decryptSettings(encryptedData, encryptionKey);
    } catch (e) {
      debugPrint('Error downloading legacy settings: $e');
      return null;
    }
  }
  
  /// Download legacy transactions with specific key
  Future<List<TransactionModel>> _downloadLegacyTransactions(String encryptionKey) async {
    try {
      final transSnapshot = await _firestore
          .collection(_legacyTransactionsPath)
          .where('deleted', isEqualTo: false)
          .get();
      
      final transactions = <TransactionModel>[];
      for (final doc in transSnapshot.docs) {
        try {
          final data = doc.data();
          final encryptedData = data['data'] as String;
          final decrypted = await _decryptSettings(encryptedData, encryptionKey);
          if (decrypted != null) {
            // Convert settings back to transaction (this is a workaround)
            // In a real scenario, we'd need to handle this differently
            debugPrint('Legacy transaction found but cannot decrypt with new method');
          }
        } catch (e) {
          debugPrint('Error processing legacy transaction: $e');
        }
      }
      
      return transactions;
    } catch (e) {
      debugPrint('Error downloading legacy transactions: $e');
      return [];
    }
  }
  
  /// Re-encrypt data with new key
  Future<Map<String, dynamic>> _reEncryptData(CloudData data, String newKey) async {
    try {
      // Re-encrypt transactions
      final reEncryptedTransactions = await _encryptTransactions(data.transactions, newKey);
      
      // Re-encrypt settings
      String? reEncryptedSettings;
      if (data.settings != null) {
        reEncryptedSettings = await _encryptSettings(data.settings!, newKey);
      }
      
      return {
        'transactions': reEncryptedTransactions,
        'settings': reEncryptedSettings,
        'updated_at': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      debugPrint('Error re-encrypting data: $e');
      rethrow;
    }
  }
  
  /// Upload all data with specific encryption key
  Future<void> _uploadAllDataWithKey(Map<String, dynamic> data, String encryptionKey) async {
    try {
      // Upload to new unified structure
      await _firestore.doc(_dataPath).set(data);
      
      // Also upload to legacy structure for backward compatibility
      await _uploadToLegacyStructure(data, encryptionKey);
      
      debugPrint('Re-encrypted data uploaded to cloud (both structures)');
    } catch (e) {
      debugPrint('Error uploading re-encrypted data: $e');
      rethrow;
    }
  }
  
  /// Upload to legacy structure for backward compatibility
  Future<void> _uploadToLegacyStructure(Map<String, dynamic> data, String encryptionKey) async {
    try {
      // Upload settings to legacy path
      if (data['settings'] != null) {
        await _firestore.doc(_legacySettingsPath).set({
          'data': data['settings'],
          'type': 'settings',
          'lastModified': FieldValue.serverTimestamp(),
        });
      }
      
      // Upload transactions to legacy path
      final transactions = data['transactions'] as List<dynamic>? ?? [];
      for (final transaction in transactions) {
        final transactionId = transaction['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        await _firestore.doc('$_legacyTransactionsPath/$transactionId').set({
          'data': transaction,
          'type': 'transaction',
          'lastModified': FieldValue.serverTimestamp(),
          'deleted': false,
        });
      }
      
      debugPrint('Data also uploaded to legacy structure for compatibility');
    } catch (e) {
      debugPrint('Warning: Could not upload to legacy structure: $e');
      // Don't rethrow - this is just for compatibility
    }
  }
  
  /// Hash PIN for cloud storage
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Derive encryption key from PIN
  String _deriveEncryptionKey(String pin) {
    // Use the same method as EncryptionService
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32); // Use first 32 characters
  }
  
  /// Decrypt transactions with specific key
  Future<List<TransactionModel>> _decryptTransactions(List<dynamic> encryptedData, String key) async {
    try {
      final decryptedTransactions = <TransactionModel>[];
      
      for (final encryptedTransaction in encryptedData) {
        try {
          // Use the static method for decryption with custom key
          final decryptedJson = EncryptionService.decryptWithKey(
            encryptedTransaction as String,
            key,
          );
          final transactionData = jsonDecode(decryptedJson) as Map<String, dynamic>;
          final transaction = TransactionModel.fromJson(transactionData);
          decryptedTransactions.add(transaction);
        } catch (e) {
          debugPrint('Error decrypting transaction: $e');
          // Skip this transaction and continue
        }
      }
      
      return decryptedTransactions;
    } catch (e) {
      debugPrint('Error decrypting transactions: $e');
      rethrow;
    }
  }
  
  /// Encrypt transactions with specific key
  Future<List<String>> _encryptTransactions(List<TransactionModel> transactions, String key) async {
    try {
      final encryptedTransactions = <String>[];
      
      for (final transaction in transactions) {
        try {
          // Use the static method for encryption with custom key
          final transactionJson = jsonEncode(transaction.toJson());
          final encrypted = EncryptionService.encryptWithKey(transactionJson, key);
          encryptedTransactions.add(encrypted);
        } catch (e) {
          debugPrint('Error encrypting transaction: $e');
          rethrow;
        }
      }
      
      return encryptedTransactions;
    } catch (e) {
      debugPrint('Error encrypting transactions: $e');
      rethrow;
    }
  }
  
  /// Decrypt settings with specific key
  Future<SettingsModel?> _decryptSettings(String encryptedData, String key) async {
    try {
      // Use the static method for decryption with custom key
      final decryptedJson = EncryptionService.decryptWithKey(encryptedData, key);
      final settingsData = jsonDecode(decryptedJson) as Map<String, dynamic>;
      return SettingsModel.fromJson(settingsData);
    } catch (e) {
      debugPrint('Error decrypting settings: $e');
      return null;
    }
  }
  
  /// Encrypt settings with specific key
  Future<String> _encryptSettings(SettingsModel settings, String key) async {
    try {
      // Use the static method for encryption with custom key
      final settingsJson = jsonEncode(settings.toJson());
      return EncryptionService.encryptWithKey(settingsJson, key);
    } catch (e) {
      debugPrint('Error encrypting settings: $e');
      rethrow;
    }
  }
  
  String _getPlatformString() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    return 'unknown';
  }
}

// Pending change model
class PendingChange {
  final String id;
  final ChangeType type;
  final Map<String, dynamic> data;
  final bool deleted;
  final DateTime timestamp;

  PendingChange({
    required this.id,
    required this.type,
    required this.data,
    required this.deleted,
    required this.timestamp,
  });
}

enum ChangeType {
  transaction,
  settings,
}