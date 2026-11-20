import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/platform/sms_gateway.dart';
import '../../../core/storage/key_value_store.dart';
import '../../devices/domain/repositories/device_repository.dart';
import '../domain/auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({
    required this._secure,
    required this._store,
    required this._devices,
    required this._gateway,
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  static const _pinHashKey = 'pin_hash';
  static const _pinSaltKey = 'pin_salt';
  static const _biometricKey = 'biometric_enabled';

  final SecureStore _secure;
  final KeyValueStore _store;
  final DeviceRepository _devices;
  final SmsGateway _gateway;
  final LocalAuthentication _localAuth;

  static String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  @override
  Future<bool> isRegistered() async => await _secure.read(_pinHashKey) != null;

  @override
  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
    await _secure.write(_pinSaltKey, salt);
    await _secure.write(_pinHashKey, _hash(salt, pin));
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final salt = await _secure.read(_pinSaltKey);
    final hash = await _secure.read(_pinHashKey);
    if (salt == null || hash == null) return false;
    return _hash(salt, pin) == hash;
  }

  @override
  Future<bool> isBiometricEnabled() async => _store.getBool(_biometricKey) ?? false;

  @override
  Future<void> setBiometricEnabled(bool enabled) => _store.setBool(_biometricKey, enabled);

  @override
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported || !await _localAuth.canCheckBiometrics) return false;
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'برای ورود به FiveStar هویت خود را تایید کنید',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }

  @override
  Future<void> resetApp() async {
    await _devices.clearAll();
    await _gateway.clear();
    await _secure.clear();
    await _store.clear();
  }
}
