import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class ConsumerBiometricCapability {
  const ConsumerBiometricCapability({
    this.isAvailable = false,
    this.isEnrolled = false,
    this.type = 'unavailable',
    this.platform = 'unknown',
  });

  final bool isAvailable;
  final bool isEnrolled;
  final String type;
  final String platform;

  bool get canAuthenticate => isAvailable;

  String get primaryLabel {
    switch (type) {
      case 'fingerprint':
      case 'fingerprint_unenrolled':
      case 'fingerprint_unavailable':
        return 'Fingerprint';
      case 'device_credential':
        return 'Screen lock';
      case 'biometric':
      case 'unenrolled':
        return 'Biometric';
      default:
        return 'Biometric';
    }
  }

  String get summary {
    if (isAvailable) {
      return '$primaryLabel quick unlock is ready on this device.';
    }
    if (isEnrolled) {
      return '$primaryLabel is enrolled, but secure quick unlock is currently unavailable.';
    }
    switch (type) {
      case 'fingerprint_unenrolled':
        return 'Enroll a fingerprint in Android settings to enable device quick unlock.';
      case 'unenrolled':
        return 'Enroll a biometric method in Android settings to enable quick unlock.';
      case 'device_credential':
        return 'Your secure screen lock can be used for quick unlock on this device.';
      case 'unsupported':
        return 'This Android version does not support the secure biometric prompt used by the app.';
      default:
        return 'This device does not currently expose an enrolled biometric method for secure quick unlock.';
    }
  }
}

abstract interface class ConsumerBiometricService {
  Future<ConsumerBiometricCapability> getCapability();

  Future<bool> authenticate({
    required String reason,
    String title,
    String subtitle,
    String negativeButton,
  });
}

class PlatformConsumerBiometricService implements ConsumerBiometricService {
  const PlatformConsumerBiometricService();

  static const MethodChannel _channel = MethodChannel(
    'real_estate_secure/security',
  );

  @override
  Future<ConsumerBiometricCapability> getCapability() async {
    if (kIsWeb) {
      return const ConsumerBiometricCapability(type: 'unsupported');
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getBiometricStatus',
      );
      if (result == null) {
        return const ConsumerBiometricCapability();
      }

      return ConsumerBiometricCapability(
        isAvailable: result['isAvailable'] == true,
        isEnrolled: result['isEnrolled'] == true,
        type: result['type']?.toString() ?? 'unavailable',
        platform: result['platform']?.toString() ?? 'android',
      );
    } on PlatformException {
      return const ConsumerBiometricCapability();
    }
  }

  @override
  Future<bool> authenticate({
    required String reason,
    String title = 'Real Estate Secure',
    String subtitle = 'Use your biometric or screen lock to continue',
    String negativeButton = 'Cancel',
  }) async {
    if (kIsWeb) {
      return false;
    }

    try {
      final result = await _channel
          .invokeMethod<bool>('authenticateBiometric', {
            'reason': reason,
            'title': title,
            'subtitle': subtitle,
            'negativeButton': negativeButton,
          });
      return result == true;
    } on PlatformException {
      return false;
    }
  }
}
