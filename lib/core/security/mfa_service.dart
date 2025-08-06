import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MFAService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static const String _trustedDeviceKey = 'trusted_device_id';
  static const String _deviceFingerprintKey = 'device_fingerprint';

  // MFA Methods
  Future<void> enableMFA({required MFAMethod method}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');

    switch (method) {
      case MFAMethod.sms:
        await _enableSMSMFA(user);
        break;
      case MFAMethod.totp:
        await _enableTOTPMFA(user);
        break;
      case MFAMethod.email:
        // Email MFA ist standardmäßig verfügbar
        break;
    }
  }

  Future<void> _enableSMSMFA(User user) async {
    // SMS MFA aktivieren
    try {
      // Schritt 1: Phone number verification starten
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+49123456789', // Wird vom User eingegeben
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android
        },
        verificationFailed: (FirebaseAuthException e) {
          throw Exception('SMS-Verifizierung fehlgeschlagen: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) async {
          // User gibt SMS-Code ein, dann:
          // final credential = PhoneAuthProvider.credential(
          //   verificationId: verificationId,
          //   smsCode: userInputCode,
          // );
          // await user.updatePhoneNumber(credential);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      throw Exception('Fehler beim Aktivieren von SMS-MFA: $e');
    }
  }

  Future<void> _enableTOTPMFA(User user) async {
    // TOTP wird in Firebase Auth noch nicht direkt unterstützt
    // Stattdessen verwenden wir eine eigene TOTP-Implementation
    // oder nutzen Phone/Email als MFA
    
    // Für jetzt: Email als zweiten Faktor nutzen
    try {
      // Email verification als zweiten Faktor
      await user.sendEmailVerification();
    } catch (e) {
      throw Exception('Fehler beim Aktivieren von TOTP: $e');
    }
  }

  // Trusted Device Management
  Future<String> getDeviceId() async {
    String? deviceId = await _secureStorage.read(key: _trustedDeviceKey);
    
    if (deviceId == null) {
      // Generiere neue Device ID
      deviceId = _generateDeviceId();
      await _secureStorage.write(key: _trustedDeviceKey, value: deviceId);
    }
    
    return deviceId;
  }

  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch;
    final combined = '$timestamp-$random';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  Future<String> generateDeviceFingerprint() async {
    final StringBuffer fingerprint = StringBuffer();
    
    if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      fingerprint.write('${iosInfo.model}-${iosInfo.systemVersion}');
      fingerprint.write('-${iosInfo.identifierForVendor}');
    } else if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      fingerprint.write('${androidInfo.model}-${androidInfo.version.release}');
      fingerprint.write('-${androidInfo.id}');
    } else if (Platform.isMacOS) {
      final macInfo = await _deviceInfo.macOsInfo;
      fingerprint.write('${macInfo.model}-${macInfo.majorVersion}');
      fingerprint.write('-${macInfo.systemGUID}');
    } else if (Platform.isWindows) {
      final windowsInfo = await _deviceInfo.windowsInfo;
      fingerprint.write('${windowsInfo.computerName}-${windowsInfo.numberOfCores}');
      fingerprint.write('-${windowsInfo.systemMemoryInMegabytes}');
    }
    
    return sha256.convert(utf8.encode(fingerprint.toString())).toString();
  }

  Future<void> trustDevice({
    required int days,
    String? customName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Nicht angemeldet');

    final deviceId = await getDeviceId();
    final fingerprint = await generateDeviceFingerprint();
    final deviceName = customName ?? await _getDefaultDeviceName();

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('trusted_devices')
        .doc(deviceId)
        .set({
      'deviceName': deviceName,
      'deviceId': deviceId,
      'fingerprint': fingerprint,
      'platform': Platform.operatingSystem,
      'trustedUntil': DateTime.now().add(Duration(days: days)),
      'addedAt': FieldValue.serverTimestamp(),
      'lastUsed': FieldValue.serverTimestamp(),
    });

    // Speichere Fingerprint lokal für Verifikation
    await _secureStorage.write(key: _deviceFingerprintKey, value: fingerprint);
  }

  Future<bool> isDeviceTrusted() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final deviceId = await getDeviceId();
      final currentFingerprint = await generateDeviceFingerprint();
      final storedFingerprint = await _secureStorage.read(key: _deviceFingerprintKey);

      // Prüfe ob Fingerprint sich geändert hat (OS Update etc.)
      if (storedFingerprint != null && storedFingerprint != currentFingerprint) {
        // Device hat sich verändert, Vertrauen entziehen
        await removeTrustedDevice(deviceId);
        return false;
      }

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('trusted_devices')
          .doc(deviceId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final trustedUntil = (data['trustedUntil'] as Timestamp).toDate();
      
      if (DateTime.now().isAfter(trustedUntil)) {
        // Vertrauen abgelaufen
        await removeTrustedDevice(deviceId);
        return false;
      }

      // Update last used
      await doc.reference.update({
        'lastUsed': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('Fehler beim Prüfen des Trusted Device Status: $e');
      return false;
    }
  }

  Future<List<TrustedDevice>> getTrustedDevices() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('trusted_devices')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return TrustedDevice(
        deviceId: doc.id,
        deviceName: data['deviceName'] ?? 'Unbekanntes Gerät',
        platform: data['platform'] ?? 'unknown',
        trustedUntil: (data['trustedUntil'] as Timestamp).toDate(),
        lastUsed: (data['lastUsed'] as Timestamp?)?.toDate(),
        isCurrentDevice: false, // Wird später gesetzt
      );
    }).toList();
  }

  Future<void> removeTrustedDevice(String deviceId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('trusted_devices')
        .doc(deviceId)
        .delete();

    // Wenn es das aktuelle Gerät ist, lösche lokale Daten
    final currentDeviceId = await getDeviceId();
    if (deviceId == currentDeviceId) {
      await _secureStorage.delete(key: _trustedDeviceKey);
      await _secureStorage.delete(key: _deviceFingerprintKey);
    }
  }

  Future<void> removeAllTrustedDevices() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('trusted_devices')
        .get();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    
    // Lösche lokale Daten
    await _secureStorage.delete(key: _trustedDeviceKey);
    await _secureStorage.delete(key: _deviceFingerprintKey);
  }

  Future<String> _getDefaultDeviceName() async {
    if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return '${iosInfo.name} (iOS)';
    } else if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return '${androidInfo.model} (Android)';
    } else if (Platform.isMacOS) {
      final macInfo = await _deviceInfo.macOsInfo;
      return '${macInfo.computerName} (macOS)';
    } else if (Platform.isWindows) {
      final windowsInfo = await _deviceInfo.windowsInfo;
      return '${windowsInfo.computerName} (Windows)';
    }
    return 'Unbekanntes Gerät';
  }
}

enum MFAMethod {
  sms,
  totp,
  email,
}

class TrustedDevice {
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime trustedUntil;
  final DateTime? lastUsed;
  final bool? isCurrentDevice;

  TrustedDevice({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.trustedUntil,
    this.lastUsed,
    this.isCurrentDevice,
  });

  String get platformIcon {
    switch (platform) {
      case 'ios':
        return '📱';
      case 'android':
        return '🤖';
      case 'macos':
        return '💻';
      case 'windows':
        return '🖥️';
      default:
        return '📲';
    }
  }

  String get timeRemaining {
    final now = DateTime.now();
    final difference = trustedUntil.difference(now);
    
    if (difference.isNegative) {
      return 'Abgelaufen';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} Tage';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} Stunden';
    } else {
      return '${difference.inMinutes} Minuten';
    }
  }
}