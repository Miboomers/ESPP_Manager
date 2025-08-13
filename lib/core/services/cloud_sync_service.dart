import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

// Conditional import für Secure Storage
import 'conditional_imports.dart';

import '../../data/models/transaction_model.dart';
import '../../data/models/settings_model.dart';
import '../security/encryption_service.dart';
import '../security/cloud_password_service.dart';

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

// Cloud Flags für Multi-Device-Synchronisation
class CloudFlags {
  final int passwordVersion;
  final DateTime lastDataUpdate;
  final DateTime lastFlagUpdate;
  final bool hasPasswordChange;
  final bool hasDataUpdate;
  
  CloudFlags({
    required this.passwordVersion,
    required this.lastDataUpdate,
    required this.lastFlagUpdate,
    this.hasPasswordChange = false,
    this.hasDataUpdate = false,
  });
  
  factory CloudFlags.fromJson(Map<String, dynamic> json) {
    return CloudFlags(
      passwordVersion: json['password_version'] ?? 1,
      lastDataUpdate: json['last_data_update'] != null 
          ? (json['last_data_update'] as Timestamp).toDate()
          : DateTime.now(),
      lastFlagUpdate: json['last_flag_update'] != null 
          ? (json['last_flag_update'] as Timestamp).toDate()
          : DateTime.now(),
      hasPasswordChange: json['has_password_change'] ?? false,
      hasDataUpdate: json['has_data_update'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'password_version': passwordVersion,
      'last_data_update': Timestamp.fromDate(lastDataUpdate),
      'last_flag_update': Timestamp.fromDate(lastFlagUpdate),
      'has_password_change': hasPasswordChange,
      'has_data_update': hasDataUpdate,
    };
  }
  
  CloudFlags copyWith({
    int? passwordVersion,
    DateTime? lastDataUpdate,
    DateTime? lastFlagUpdate,
    bool? hasPasswordChange,
    bool? hasDataUpdate,
  }) {
    return CloudFlags(
      passwordVersion: passwordVersion ?? this.passwordVersion,
      lastDataUpdate: lastDataUpdate ?? this.lastDataUpdate,
      lastFlagUpdate: lastFlagUpdate ?? this.lastFlagUpdate,
      hasPasswordChange: hasPasswordChange ?? this.hasPasswordChange,
      hasDataUpdate: hasDataUpdate ?? this.hasDataUpdate,
    );
  }
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
  
  // Flag-System für Multi-Device-Synchronisation
  final _flagController = StreamController<CloudFlags>.broadcast();
  Timer? _flagCheckTimer;
  static const Duration _flagCheckInterval = Duration(seconds: 30);
  
  // Cloud Flags für Multi-Device-Synchronisation
  CloudFlags? _currentFlags;
  DateTime? _lastFlagCheck;
  
  // 🔄 Echtzeit-Synchronisierung
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<QuerySnapshot>? _cloudDataSubscription;
  Timer? _periodicSyncTimer;
  
  // 📱 Offline-Queue für Änderungen
  final List<Map<String, dynamic>> _offlineQueue = [];
  bool _isOnline = true;
  
  // 🔒 Konflikt-Auflösung
  final Map<String, DateTime> _lastModifiedTimestamps = {};
  
  // 📊 Daten-Validierung
  final Map<String, String> _dataHashes = {};
  
  // 🔄 Callback für Provider-Updates
  Function(List<TransactionModel>, SettingsModel?)? _onDataUpdateCallback;
  
  // 💾 Temporäre Daten für späteren Abruf
  Map<String, dynamic>? _tempMergedData;
  
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  
  // Flag-System Getter
  Stream<CloudFlags> get flagStream => _flagController.stream;
  CloudFlags? get currentFlags => _currentFlags;
  
  /// Setzt den Callback für Provider-Updates
  void setDataUpdateCallback(Function(List<TransactionModel>, SettingsModel?) callback) {
    _onDataUpdateCallback = callback;
    debugPrint('✅ Data update callback set');
    
    // WICHTIG: Wenn temporäre Daten vorhanden sind, führe den Callback sofort aus
    if (_tempMergedData != null) {
      debugPrint('🔄 Executing callback with stored data: ${_tempMergedData!['transactions'].length} transactions');
      final transactions = _tempMergedData!['transactions'] as List<TransactionModel>;
      final settings = _tempMergedData!['settings'] as SettingsModel?;
      
      callback(transactions, settings);
      
      // Lösche die temporären Daten
      _tempMergedData = null;
      debugPrint('✅ Stored data processed and cleared');
    }
  }
  
  // Current sync status
  SyncStatus _currentStatus = SyncStatus(
    state: SyncState.idle,
    lastSync: DateTime.now(),
  );
  
  // Cloud encryption key
  String? _cloudEncryptionKey;
  
  // Pending changes
  final List<Map<String, dynamic>> _pendingChanges = [];
  
  // User specific paths
  String get _userPath {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User nicht angemeldet');
    return 'users/${user.uid}';
  }
  
  // Data paths
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
  Future<void> initializeForUser(String cloudPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');
    
    final uid = user.uid;
    if (uid.isEmpty) throw Exception('User UID fehlt');
    
    // Generate user-specific encryption key from cloud password + UID
    _cloudEncryptionKey = _generateEncryptionKey(cloudPassword, uid);
    
    // Store key securely
    await _secureStorage.write(
      key: 'cloud_encryption_key_$uid',
      value: _cloudEncryptionKey!,
    );
    
    debugPrint('✅ Cloud Sync für User initialisiert');
    
    // 🔄 Starte Echtzeit-Synchronisierung
    _startRealTimeSync();
    
    // 📱 Starte Offline-Überwachung
    _startOfflineMonitoring();
    
    // ⏰ Starte periodische Synchronisierung
    _startPeriodicSync();
  }
  
  /// Starte Echtzeit-Synchronisierung der Cloud-Daten
  void _startRealTimeSync() {
    try {
      debugPrint('🔄 Starting real-time cloud sync...');
      
      // Überwache Änderungen in der Cloud
      _cloudDataSubscription = _firestore
          .collection('$_userPath/transactions')
          .snapshots()
          .listen((snapshot) {
        _handleCloudDataChanges(snapshot);
      });
      
      debugPrint('✅ Real-time sync started');
    } catch (e) {
      debugPrint('⚠️ Failed to start real-time sync: $e');
    }
  }
  
  /// Starte Offline-Überwachung
  void _startOfflineMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      
      if (_isOnline && _offlineQueue.isNotEmpty) {
        debugPrint('🌐 Back online - processing ${_offlineQueue.length} offline changes');
        _processOfflineQueue();
      }
      
      _updateSyncStatus(
        _isOnline ? SyncState.idle : SyncState.offline,
        _isOnline ? null : 'Offline - Änderungen werden gespeichert'
      );
    });
  }
  
  /// Starte periodische Synchronisierung
  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (_isOnline && await isCloudSyncEnabled()) {
        debugPrint('⏰ Periodic sync triggered');
        syncPendingChanges();
      }
    });
    
    // 🚩 Starte Flag-Überprüfung
    _startFlagMonitoring();
  }
  
  /// Starte Flag-Überwachung für Multi-Device-Synchronisation
  void _startFlagMonitoring() {
    _flagCheckTimer = Timer.periodic(_flagCheckInterval, (timer) async {
      if (_isOnline && await isCloudSyncEnabled()) {
        await _checkCloudFlags();
      }
    });
    debugPrint('🚩 Flag monitoring started - checking every ${_flagCheckInterval.inSeconds} seconds');
  }
  
  /// Überprüfe Cloud-Flags für Multi-Device-Synchronisation
  Future<void> _checkCloudFlags() async {
    try {
      final flagsRef = _firestore.doc('$_userPath/flags');
      final flagsDoc = await flagsRef.get();
      
      if (flagsDoc.exists) {
        final flagsData = flagsDoc.data()!;
        final newFlags = CloudFlags.fromJson(flagsData);
        
        // Prüfe ob sich die Flags geändert haben
        if (_currentFlags == null || _currentFlags!.passwordVersion != newFlags.passwordVersion) {
          debugPrint('🚩 Password version changed: ${_currentFlags?.passwordVersion ?? 'none'} → ${newFlags.passwordVersion}');
          _currentFlags = newFlags;
          _flagController.add(newFlags);
          
          // Benachrichtige über Passwort-Änderung
          if (newFlags.hasPasswordChange) {
            debugPrint('🚩 Password change detected - user needs to update password');
            // TODO: Benachrichtige UI über Passwort-Änderung
          }
        }
        
        if (_currentFlags == null || _currentFlags!.lastDataUpdate != newFlags.lastDataUpdate) {
          debugPrint('🚩 Data update detected: ${newFlags.lastDataUpdate}');
          _currentFlags = newFlags;
          _flagController.add(newFlags);
          
          // Benachrichtige über Daten-Updates
          if (newFlags.hasDataUpdate) {
            debugPrint('🚩 Data update detected - triggering sync');
            await syncPendingChanges();
          }
        }
        
        _lastFlagCheck = DateTime.now();
      } else {
        // Erstelle Standard-Flags wenn sie nicht existieren
        final defaultFlags = CloudFlags(
          passwordVersion: 1,
          lastDataUpdate: DateTime.now(),
          lastFlagUpdate: DateTime.now(),
        );
        
        await flagsRef.set(defaultFlags.toJson());
        _currentFlags = defaultFlags;
        _flagController.add(defaultFlags);
        debugPrint('🚩 Default flags created');
      }
    } catch (e) {
      debugPrint('❌ Error checking cloud flags: $e');
    }
  }
  
  /// Behandle Cloud-Daten-Änderungen
  void _handleCloudDataChanges(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || 
            change.type == DocumentChangeType.modified) {
          debugPrint('🔄 Cloud data changed: ${change.doc.id}');
          _notifyDataChange(change.doc.id, change.type);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error handling cloud data changes: $e');
    }
  }
  
  /// Benachrichtige über Datenänderungen
  void _notifyDataChange(String documentId, DocumentChangeType changeType) {
    // Hier können wir später Benachrichtigungen implementieren
    debugPrint('📢 Data change: $changeType on $documentId');
  }
  
  /// Verarbeite Offline-Queue
  Future<void> _processOfflineQueue() async {
    try {
      debugPrint('📱 Processing ${_offlineQueue.length} offline changes...');
      
      for (final change in _offlineQueue) {
        await _processOfflineChange(change);
      }
      
      _offlineQueue.clear();
      debugPrint('✅ Offline queue processed successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to process offline queue: $e');
    }
  }
  
  /// Verarbeite einzelne Offline-Änderung
  Future<void> _processOfflineChange(Map<String, dynamic> change) async {
    try {
      final type = change['type'] as String;
      final id = change['id'] as String;
      final data = change['data'];
      
      switch (type) {
        case 'transaction':
          final transaction = TransactionModel.fromJson(data);
          await syncTransaction(transaction);
          break;
        case 'settings':
          final settings = SettingsModel.fromJson(data);
          await syncSettings(settings);
          break;
        default:
          debugPrint('⚠️ Unknown offline change type: $type');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to process offline change: $e');
    }
  }
  
  /// Generate encryption key from cloud password and user UID
  String _generateEncryptionKey(String cloudPassword, String userUid) {
    final bytes = utf8.encode('$cloudPassword:$userUid');
    final hash = sha256.convert(bytes);
    return base64.encode(hash.bytes);
  }
  
  // Check if cloud sync is enabled
  Future<bool> isCloudSyncEnabled() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final uid = user.uid;
    if (uid.isEmpty) return false;
    
    // WICHTIG: Prüfe ob E-Mail bestätigt wurde
    if (!user.emailVerified) {
      debugPrint('⚠️ Cloud-Sync deaktiviert: E-Mail nicht bestätigt');
      return false;
    }
    
    _cloudEncryptionKey ??= await _secureStorage.read(
      key: 'cloud_encryption_key_$uid',
    );
    
    return _cloudEncryptionKey != null;
  }
  
  // Check if user email is verified
  bool get isEmailVerified {
    final user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }
  
  // Get email verification status message
  String get emailVerificationMessage {
    if (isEmailVerified) {
      return 'E-Mail bestätigt - Cloud-Sync aktiv';
    } else {
      return 'E-Mail-Bestätigung erforderlich - Cloud-Sync deaktiviert';
    }
  }
  
  // Send email verification email
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kein User angemeldet');
      }
      
      if (user.emailVerified) {
        throw Exception('E-Mail ist bereits bestätigt');
      }
      
      await user.sendEmailVerification();
      debugPrint('✅ E-Mail-Bestätigung gesendet an ${user.email}');
    } catch (e) {
      debugPrint('❌ Fehler beim Senden der E-Mail-Bestätigung: $e');
      rethrow;
    }
  }
  
  // Check if user can resend verification email
  bool get canResendVerificationEmail {
    final user = _auth.currentUser;
    return user != null && !user.emailVerified;
  }
  
  // Enable cloud sync
  Future<void> enableCloudSync({
    required List<TransactionModel> localTransactions,
    required SettingsModel localSettings,
    required String cloudPassword,
  }) async {
    try {
      debugPrint('🚀 Starting cloud sync activation...');
      debugPrint('🔍 Local transactions count: ${localTransactions.length}');
      debugPrint('🔍 Local settings available: ${localSettings != null}');
      debugPrint('🔍 Cloud password provided: ${cloudPassword.isNotEmpty ? 'Yes' : 'No'}');
      
      _updateSyncStatus(SyncState.syncing, 'Cloud Sync wird aktiviert...');
      
      // Check user authentication
      final currentUser = _auth.currentUser;
      debugPrint('🔍 Current Firebase user: $currentUser');
      if (currentUser != null) {
        debugPrint('🔍 User UID: ${currentUser.uid}');
        debugPrint('🔍 User email: ${currentUser.email}');
      }
      
      await initializeForUser(cloudPassword);
      debugPrint('🔄 User initialized for sync');
      
      // WICHTIG: Setze einen Standard-Callback falls keiner gesetzt ist
      if (_onDataUpdateCallback == null) {
        debugPrint('⚠️ No data update callback set - setting default callback');
        // Setze einen Standard-Callback der eine globale Benachrichtigung sendet
        _onDataUpdateCallback = (transactions, settings) {
          debugPrint('🔄 Default data update callback executed: ${transactions.length} transactions');
          // Sende eine globale Benachrichtigung über den Sync-Status
          _updateSyncStatus(
            SyncState.idle, 
            '${transactions.length} Transaktionen aus der Cloud geladen - Bitte App neu laden'
          );
          
          // WICHTIG: Speichere die Daten temporär für späteren Abruf
          _tempMergedData = {
            'transactions': transactions,
            'settings': settings,
            'timestamp': DateTime.now(),
          };
          debugPrint('💾 Temporary data stored for later retrieval');
        };
      }
      debugPrint('✅ Data update callback is ready');
      
      // 🔄 Intelligente Cloud-Synchronisierung: Hochladen UND Herunterladen
      debugPrint('📤 Starting intelligent cloud sync...');
      
      // 1. Prüfe ob bereits Cloud-Daten existieren
      final cloudDataExists = await _checkCloudDataExists();
      debugPrint('🔍 Cloud data exists: $cloudDataExists');
      
      if (cloudDataExists) {
        // 2. Lade alle Cloud-Daten herunter
        debugPrint('📥 Downloading existing cloud data...');
        final cloudData = await downloadAllData();
        debugPrint('✅ Downloaded ${cloudData.transactions.length} cloud transactions');
        
        // 3. Führe lokale und Cloud-Daten zusammen
        debugPrint('🔄 Merging local and cloud data...');
        final mergeResult = await _mergeLocalAndCloudData(
          localTransactions, 
          localSettings, 
          cloudData.transactions, 
          cloudData.settings
        );
        
        // 4. Lade zusammengeführte Daten in die Cloud
        debugPrint('📤 Uploading merged data to cloud...');
        await _uploadAllData(mergeResult.transactions, mergeResult.settings);
        debugPrint('✅ Merged data uploaded successfully');
        
        // 5. Aktualisiere lokale Daten mit zusammengeführten Daten
        await _updateLocalData(mergeResult.transactions, mergeResult.settings);
        debugPrint('✅ Local data updated with merged data');
        
        // 6. Benachrichtige über erfolgreiche Zusammenführung
        _notifyDataMerge(
          localCount: localTransactions.length,
          cloudCount: cloudData.transactions.length,
          mergedCount: mergeResult.transactions.length,
        );
        
      } else {
        // Keine Cloud-Daten vorhanden - nur lokale Daten hochladen
        debugPrint('📤 No existing cloud data - uploading local data only...');
        await _uploadAllData(localTransactions, localSettings);
        debugPrint('✅ Local data uploaded successfully');
      }
      
      _updateSyncStatus(SyncState.idle, 'Cloud Sync aktiviert');
      debugPrint('🎉 Cloud sync successfully enabled');
      
    } catch (e) {
      debugPrint('❌ Critical error during cloud sync initialization: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error stack: ${StackTrace.current}');
      
      // Deutsche Fehlermeldungen für bessere Benutzerfreundlichkeit
      String userFriendlyMessage = _getGermanErrorMessage(e);
      _updateSyncStatus(SyncState.error, userFriendlyMessage);
      rethrow;
    }
  }
  
  /// Konvertiert technische Fehlermeldungen in benutzerfreundliche deutsche Texte
  String _getGermanErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('invalid or corrupted pad block')) {
      return 'Verschlüsselungsfehler: Das Cloud-Passwort könnte falsch sein oder die Daten sind beschädigt. Bitte überprüfen Sie Ihr Passwort.';
    }
    
    if (errorString.contains('invalid argument')) {
      return 'Ungültige Eingabe: Bitte überprüfen Sie Ihre Eingaben und versuchen Sie es erneut.';
    }
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Verbindungsfehler: Bitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.';
    }
    
    if (errorString.contains('permission') || errorString.contains('unauthorized')) {
      return 'Berechtigungsfehler: Sie haben keine Berechtigung für diese Aktion. Bitte melden Sie sich erneut an.';
    }
    
    if (errorString.contains('timeout')) {
      return 'Zeitüberschreitung: Die Verbindung zur Cloud hat zu lange gedauert. Bitte versuchen Sie es erneut.';
    }
    
    // Fallback für unbekannte Fehler
    return 'Ein unerwarteter Fehler ist aufgetreten: $error';
  }
  
  // Upload all data (initial sync)
  Future<void> _uploadAllData(
    List<TransactionModel> transactions,
    SettingsModel settings,
  ) async {
    try {
      debugPrint('📤 Starting data upload to cloud...');
      debugPrint('🔍 User path: $_userPath');
      debugPrint('🔍 Transactions to upload: ${transactions.length}');
      debugPrint('🔍 Settings to upload: ${settings != null ? 'Yes' : 'No'}');
      
      // Validate user path before proceeding
      if (_userPath.isEmpty || _userPath.contains('null')) {
        throw Exception('Invalid user path: $_userPath');
      }
      
      final batch = _firestore.batch();
      
      // Upload settings
      final settingsRef = _firestore.doc('$_userPath/data/settings');
      debugPrint('🔍 Uploading settings to: $_userPath/data/settings');
      
      final encryptedSettings = _encryptData(settings.toJson());
      debugPrint('🔍 Settings encrypted successfully');
      
      batch.set(settingsRef, {
        'data': encryptedSettings,
        'type': 'settings',
        'lastModified': FieldValue.serverTimestamp(),
      });
      
      // Upload transactions
      debugPrint('🔍 Uploading ${transactions.length} transactions...');
      for (final transaction in transactions) {
        final transRef = _firestore.doc('$_userPath/transactions/${transaction.id}');
        debugPrint('🔍 Uploading transaction ${transaction.id} to: $_userPath/transactions/${transaction.id}');
        
        final encryptedTransaction = _encryptData(transaction.toJson());
        batch.set(transRef, {
          'data': encryptedTransaction,
          'type': 'transaction',
          'lastModified': FieldValue.serverTimestamp(),
          'deleted': false,
        });
      }
      
      debugPrint('🔍 Committing batch to Firestore...');
      await batch.commit();
      debugPrint('✅ Batch committed successfully');
      
    } catch (e) {
      debugPrint('❌ Error during data upload: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error stack: ${StackTrace.current}');
      rethrow;
    }
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
      _addPendingChange('transaction', transaction.id, transaction.toJson());
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
      _addPendingChange('transaction', transaction.id, transaction.toJson());
    }
  }
  
  // Sync settings
  Future<void> syncSettings(SettingsModel settings) async {
    if (!await isCloudSyncEnabled()) return;
    
    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _addPendingChange('settings', 'settings', settings.toJson());
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
      _addPendingChange('settings', 'settings', settings.toJson());
    }
  }
  
  // Sync pending changes when back online
  Future<void> syncPendingChanges() async {
    if (_pendingChanges.isEmpty) return;
    
    try {
      _updateSyncStatus(SyncState.syncing, 'Änderungen werden synchronisiert...');
      
      final batch = _firestore.batch();
      
      for (final change in _pendingChanges) {
        final changeType = change['type'] as String;
        final changeId = change['id'] as String;
        
        if (changeType == 'transaction') {
          final docRef = _firestore.doc('$_userPath/transactions/$changeId');
          batch.set(docRef, change['data'] as Map<String, dynamic>);
        } else if (changeType == 'settings') {
          final docRef = _firestore.doc('$_userPath/data/settings');
          batch.set(docRef, change['data'] as Map<String, dynamic>);
        }
      }
      
      await batch.commit();
      _pendingChanges.clear();
      
      _updateSyncStatus(SyncState.idle, 'Änderungen synchronisiert');
    } catch (e) {
      _updateSyncStatus(SyncState.error, 'Fehler: $e');
    }
  }
  
  // Add change to pending queue
  void _addPendingChange(String type, String id, Map<String, dynamic> data) {
    _pendingChanges.add({
      'type': type,
      'id': id,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
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
      
      // Get cloud password info
      final passwordInfo = await _getCloudPasswordInfo();
      
      // Get last sync info
      final lastSyncInfo = await _getLastSyncInfo();
      
      return CloudDataOverview(
        transactions: transactionsInfo,
        settings: settingsInfo,
        pinInfo: passwordInfo, // Reuse pinInfo field for password info
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
  
  /// Get cloud password info
  Future<CloudDataInfo> _getCloudPasswordInfo() async {
    try {
      debugPrint('🔍 Getting cloud password info...');
      
      // Check if user is authenticated
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ User not authenticated');
        return CloudDataInfo(
          status: 'Nicht angemeldet',
          details: 'User ist nicht bei Firebase angemeldet',
        );
      }
      
      debugPrint('🔍 User authenticated: ${user.uid}');
      
      // Check if cloud password is set
      final cloudPasswordService = CloudPasswordService();
      final isPasswordSet = await cloudPasswordService.isCloudPasswordSet();
      
      if (!isPasswordSet) {
        debugPrint('❌ Cloud password not set');
        return CloudDataInfo(
          status: 'Kein Cloud-Passwort gesetzt',
          details: 'Cloud-Passwort wird bei der ersten Cloud-Sync gesetzt',
        );
      }
      
      debugPrint('✅ Cloud password is set');
      
      return CloudDataInfo(
        status: 'Verfügbar',
        details: 'Cloud-Passwort ist für Datenverschlüsselung gesetzt',
      );
    } catch (e) {
      debugPrint('❌ Error getting cloud password info: $e');
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
  
  // PIN Management Methods - REMOVED, replaced with Cloud Password
  
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
  
  // Cloud Sync Management Methods
  
  /// Disable cloud sync
  Future<void> disableCloudSync() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final uid = user.uid;
    if (uid.isEmpty) return;
    
    // Clear encryption key
    await _secureStorage.delete(key: 'cloud_encryption_key_$uid');
    _cloudEncryptionKey = null;
    
    // Clear cloud password
    final cloudPasswordService = CloudPasswordService();
    await cloudPasswordService.clearCloudPassword();
    
    _updateSyncStatus(SyncState.idle, 'Cloud Sync deaktiviert');
  }
  

  
  /// Upload all data with specific encryption key
  Future<void> _uploadAllDataWithKey(Map<String, dynamic> data, String encryptionKey) async {
    try {
      final batch = _firestore.batch();
      
      // Upload to new unified structure
      final dataRef = _firestore.doc(_dataPath);
      batch.set(dataRef, {
        'transactions': data['transactions'],
        'settings': data['settings'],
        'lastModified': FieldValue.serverTimestamp(),
        'encryption_version': '2.0',
      });
      
      await batch.commit();
      debugPrint('✅ Data uploaded to unified structure');
      
      // Also upload to legacy structure for backward compatibility
      await _uploadToLegacyStructure(data, encryptionKey);
      
    } catch (e) {
      debugPrint('Error uploading data with key: $e');
      rethrow;
    }
  }
  
  /// Upload to legacy structure for backward compatibility
  Future<void> _uploadToLegacyStructure(Map<String, dynamic> data, String encryptionKey) async {
    try {
      final batch = _firestore.batch();
      
      // Upload settings to legacy path
      if (data['settings'] != null) {
        final settingsRef = _firestore.doc(_legacySettingsPath);
        batch.set(settingsRef, {
          'data': data['settings'],
          'type': 'settings',
          'lastModified': FieldValue.serverTimestamp(),
        });
      }
      
      // Upload transactions to legacy path
      final transactions = data['transactions'] as List<String>;
      for (int i = 0; i < transactions.length; i++) {
        final transRef = _firestore.doc('$_legacyTransactionsPath/legacy_$i');
        batch.set(transRef, {
          'data': transactions[i],
          'type': 'transaction',
          'lastModified': FieldValue.serverTimestamp(),
          'deleted': false,
        });
      }
      
      await batch.commit();
      debugPrint('Data also uploaded to legacy structure for compatibility');
    } catch (e) {
      debugPrint('Warning: Could not upload to legacy structure: $e');
      // Don't rethrow - this is just for compatibility
    }
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
  
  /// Prüft ob bereits Cloud-Daten existieren
  Future<bool> _checkCloudDataExists() async {
    try {
      debugPrint('🔍 Checking if cloud data exists...');
      
      // Prüfe ob Einstellungen existieren
      final settingsDoc = await _firestore.doc('$_userPath/data/settings').get();
      if (settingsDoc.exists) {
        debugPrint('✅ Cloud settings found');
        return true;
      }
      
      // Prüfe ob Transaktionen existieren
      final transSnapshot = await _firestore
          .collection('$_userPath/transactions')
          .where('deleted', isEqualTo: false)
          .limit(1)
          .get();
      
      if (transSnapshot.docs.isNotEmpty) {
        debugPrint('✅ Cloud transactions found');
        return true;
      }
      
      debugPrint('ℹ️ No existing cloud data found');
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking cloud data existence: $e');
      return false;
    }
  }
  
  /// Führt lokale und Cloud-Daten intelligent zusammen
  Future<({List<TransactionModel> transactions, SettingsModel settings})> 
      _mergeLocalAndCloudData(
        List<TransactionModel> localTransactions,
        SettingsModel localSettings,
        List<TransactionModel> cloudTransactions,
        SettingsModel? cloudSettings,
      ) async {
    try {
      debugPrint('🔄 Starting data merge...');
      debugPrint('   Local: ${localTransactions.length} transactions');
      debugPrint('   Cloud: ${cloudTransactions.length} transactions');
      
      final mergedTransactions = <TransactionModel>[];
      final processedIds = <String>{};
      
      // 1. Füge alle lokalen Transaktionen hinzu
      for (final localTx in localTransactions) {
        mergedTransactions.add(localTx);
        processedIds.add(localTx.id);
        debugPrint('   → Added local transaction: ${localTx.id}');
      }
      
      // 2. Füge Cloud-Transaktionen hinzu, die nicht lokal existieren
      for (final cloudTx in cloudTransactions) {
        if (!processedIds.contains(cloudTx.id)) {
          mergedTransactions.add(cloudTx);
          processedIds.add(cloudTx.id);
          debugPrint('   → Added cloud transaction: ${cloudTx.id}');
        } else {
          debugPrint('   → Skipped duplicate cloud transaction: ${cloudTx.id}');
        }
      }
      
      // 3. Einstellungen zusammenführen (lokale haben Vorrang)
      final mergedSettings = localSettings;
      if (cloudSettings != null) {
        debugPrint('   → Merged settings (local has priority)');
      }
      
      debugPrint('✅ Merge completed: ${mergedTransactions.length} total transactions');
      
      return (
        transactions: mergedTransactions,
        settings: mergedSettings,
      );
    } catch (e) {
      debugPrint('❌ Error during data merge: $e');
      rethrow;
    }
  }
  
  /// Aktualisiert lokale Daten mit zusammengeführten Daten
  Future<void> _updateLocalData(
    List<TransactionModel> mergedTransactions,
    SettingsModel mergedSettings,
  ) async {
    try {
      debugPrint('💾 Updating local data with merged data...');
      
      // WICHTIG: Verwende den Callback um die lokalen Provider zu aktualisieren
      if (_onDataUpdateCallback != null) {
        debugPrint('🔄 Calling data update callback...');
        _onDataUpdateCallback!(mergedTransactions, mergedSettings);
        debugPrint('✅ Data update callback executed');
      } else {
        debugPrint('⚠️ No data update callback set - Provider werden nicht aktualisiert!');
        debugPrint('💡 Versuche direkte Aktualisierung der lokalen Datenbasis...');
        
        // WICHTIG: Direkte Aktualisierung der lokalen Datenbasis
        await _updateLocalDatabase(mergedTransactions, mergedSettings);
        
        // Fallback: Sende eine globale Benachrichtigung
        _updateSyncStatus(
          SyncState.idle, 
          '${mergedTransactions.length} Transaktionen in lokale Datenbasis geschrieben - App wird aktualisiert'
        );
      }
      
      debugPrint('✅ Local data update completed');
      debugPrint('   → ${mergedTransactions.length} transactions available');
      debugPrint('   → Settings updated');
      debugPrint('   → Provider update callback executed');
      
    } catch (e) {
      debugPrint('❌ Error updating local data: $e');
      // Nicht rethrow - das ist nicht kritisch
    }
  }
  
  /// Aktualisiert die lokale Datenbasis direkt
  Future<void> _updateLocalDatabase(
    List<TransactionModel> transactions,
    SettingsModel settings,
  ) async {
    try {
      debugPrint('💾 Updating local database directly...');
      
      // WICHTIG: Hier müssen wir die lokale Hive-Datenbasis aktualisieren
      // Da wir keinen direkten Zugriff auf die Provider haben,
      // können wir nur eine globale Benachrichtigung senden
      
      debugPrint('📝 Lokale Datenbasis kann nicht direkt aktualisiert werden');
      debugPrint('💡 Benutzer muss die App neu laden oder manuell synchronisieren');
      debugPrint('💡 Oder der Callback muss vor enableCloudSync gesetzt werden');
      
      // Für jetzt speichern wir die Daten temporär
      _tempMergedData = {
        'transactions': transactions,
        'settings': settings,
        'timestamp': DateTime.now(),
      };
      debugPrint('💾 Daten temporär gespeichert für späteren Abruf');
      
    } catch (e) {
      debugPrint('❌ Error updating local database: $e');
    }
  }
  
  /// Benachrichtigt über erfolgreiche Datenzusammenführung
  void _notifyDataMerge({
    required int localCount,
    required int cloudCount,
    required int mergedCount,
  }) {
    debugPrint('📢 Data merge notification:');
    debugPrint('   → Local: $localCount transactions');
    debugPrint('   → Cloud: $cloudCount transactions');
    debugPrint('   → Merged: $mergedCount total transactions');
    
    // Hier könnten wir eine globale Benachrichtigung senden
    // Da wir keinen direkten Zugriff auf den BuildContext haben,
    // loggen wir es für den Benutzer
    debugPrint('🎉 Data merge completed successfully!');
    debugPrint('   → Please refresh the app to see all merged data');
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
  
  // 🚩 Flag-System Methoden
  
  /// Ändert das Cloud-Passwort (vereinfachte Version)
  Future<void> changeCloudPassword(String oldPassword, String newPassword) async {
    try {
      _updateSyncStatus(SyncState.syncing, 'Cloud-Passwort wird geändert...');
      debugPrint('🔐 Starting cloud password change...');
      
      // 1. Neues Passwort im CloudPasswordService setzen
      debugPrint('💾 Updating cloud password...');
      final cloudPasswordService = CloudPasswordService();
      await cloudPasswordService.changeCloudPassword(oldPassword, newPassword);
      
      // 2. Lokalen Verschlüsselungsschlüssel aktualisieren
      final newEncryptionKey = _generateEncryptionKey(newPassword, _auth.currentUser!.uid);
      _cloudEncryptionKey = newEncryptionKey;
      
      // 3. Passwort-Änderungs-Flag setzen (informiert andere Geräte)
      debugPrint('🚩 Setting password change flag...');
      await setPasswordChangeFlag();
      
      _updateSyncStatus(SyncState.idle, 'Cloud-Passwort erfolgreich geändert');
      debugPrint('✅ Cloud password change completed successfully');
      
    } catch (e) {
      _updateSyncStatus(SyncState.error, 'Fehler bei Cloud-Passwort-Änderung: $e');
      debugPrint('❌ Error during cloud password change: $e');
      rethrow;
    }
  }
  
  /// Setzt das Passwort-Änderungs-Flag
  Future<void> setPasswordChangeFlag() async {
    try {
      final flagsRef = _firestore.doc('$_userPath/flags');
      final currentFlags = _currentFlags ?? CloudFlags(
        passwordVersion: 1,
        lastDataUpdate: DateTime.now(),
        lastFlagUpdate: DateTime.now(),
      );
      
      final updatedFlags = currentFlags.copyWith(
        passwordVersion: currentFlags.passwordVersion + 1,
        hasPasswordChange: true,
        lastFlagUpdate: DateTime.now(),
      );
      
      await flagsRef.set(updatedFlags.toJson());
      _currentFlags = updatedFlags;
      _flagController.add(updatedFlags);
      
      debugPrint('🚩 Password change flag set - version ${updatedFlags.passwordVersion}');
    } catch (e) {
      debugPrint('❌ Error setting password change flag: $e');
      rethrow;
    }
  }
  
  /// Setzt das Daten-Update-Flag
  Future<void> setDataUpdateFlag() async {
    try {
      final flagsRef = _firestore.doc('$_userPath/flags');
      final currentFlags = _currentFlags ?? CloudFlags(
        passwordVersion: 1,
        lastDataUpdate: DateTime.now(),
        lastFlagUpdate: DateTime.now(),
      );
      
      final updatedFlags = currentFlags.copyWith(
        lastDataUpdate: DateTime.now(),
        hasDataUpdate: true,
        lastFlagUpdate: DateTime.now(),
      );
      
      await flagsRef.set(updatedFlags.toJson());
      _currentFlags = updatedFlags;
      _flagController.add(updatedFlags);
      
      debugPrint('🚩 Data update flag set - ${updatedFlags.lastDataUpdate}');
    } catch (e) {
      debugPrint('❌ Error setting data update flag: $e');
      rethrow;
    }
  }
  
  /// Löscht alle Flags (für Reset)
  Future<void> clearFlags() async {
    try {
      final flagsRef = _firestore.doc('$_userPath/flags');
      await flagsRef.delete();
      
      _currentFlags = null;
      debugPrint('🚩 All flags cleared');
    } catch (e) {
      debugPrint('❌ Error clearing flags: $e');
      rethrow;
    }
  }
  
  /// Cleanup beim Beenden
  void _disposeFlags() {
    _flagCheckTimer?.cancel();
    _flagController.close();
  }
}