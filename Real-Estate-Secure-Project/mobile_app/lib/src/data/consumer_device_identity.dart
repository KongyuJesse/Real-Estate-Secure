import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConsumerDeviceIdentity {
  const ConsumerDeviceIdentity({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.appVersion,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String appVersion;
}

abstract interface class ConsumerDeviceIdentityProvider {
  Future<ConsumerDeviceIdentity> load();
}

class SecureConsumerDeviceIdentityStore
    implements ConsumerDeviceIdentityProvider {
  SecureConsumerDeviceIdentityStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _deviceIdKey = 'consumer_device_identity_id';

  @override
  Future<ConsumerDeviceIdentity> load() async {
    final existing = (await _storage.read(key: _deviceIdKey))?.trim() ?? '';
    final deviceId = existing.isNotEmpty ? existing : _generateDeviceId();
    if (existing.isEmpty) {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }

    const configuredVersion = String.fromEnvironment('RES_APP_VERSION');
    final platform = Platform.operatingSystem;

    return ConsumerDeviceIdentity(
      deviceId: deviceId,
      deviceName: 'consumer-mobile-app',
      platform: platform,
      appVersion: configuredVersion.trim().isNotEmpty
          ? configuredVersion.trim()
          : '1.0.0',
    );
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
