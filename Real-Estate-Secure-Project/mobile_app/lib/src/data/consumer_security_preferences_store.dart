import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ConsumerSecurityPreferencesStore {
  Future<bool> loadBiometricQuickUnlockEnabled();

  Future<void> saveBiometricQuickUnlockEnabled(bool enabled);
}

class SecureConsumerSecurityPreferencesStore
    implements ConsumerSecurityPreferencesStore {
  const SecureConsumerSecurityPreferencesStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  static const _biometricQuickUnlockKey =
      'consumer_security_biometric_quick_unlock_enabled';

  @override
  Future<bool> loadBiometricQuickUnlockEnabled() async {
    final value = await _storage.read(key: _biometricQuickUnlockKey);
    return value == 'true';
  }

  @override
  Future<void> saveBiometricQuickUnlockEnabled(bool enabled) {
    if (!enabled) {
      return _storage.delete(key: _biometricQuickUnlockKey);
    }
    return _storage.write(key: _biometricQuickUnlockKey, value: 'true');
  }
}

class MemoryConsumerSecurityPreferencesStore
    implements ConsumerSecurityPreferencesStore {
  MemoryConsumerSecurityPreferencesStore({bool biometricQuickUnlockEnabled = false})
    : _biometricQuickUnlockEnabled = biometricQuickUnlockEnabled;

  bool _biometricQuickUnlockEnabled;

  @override
  Future<bool> loadBiometricQuickUnlockEnabled() async =>
      _biometricQuickUnlockEnabled;

  @override
  Future<void> saveBiometricQuickUnlockEnabled(bool enabled) async {
    _biometricQuickUnlockEnabled = enabled;
  }
}