import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class ConsumerRuntimeConfigService {
  Future<String?> getDefaultApiBaseUrl();
}

class PlatformConsumerRuntimeConfigService
    implements ConsumerRuntimeConfigService {
  const PlatformConsumerRuntimeConfigService();

  static const MethodChannel _channel = MethodChannel(
    'real_estate_secure/runtime_config',
  );

  @override
  Future<String?> getDefaultApiBaseUrl() async {
    if (kIsWeb) {
      return null;
    }

    try {
      final value = await _channel.invokeMethod<String>('getDefaultApiBaseUrl');
      final normalized = value?.trim() ?? '';
      return normalized.isEmpty ? null : normalized;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
