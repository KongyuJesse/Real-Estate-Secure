import 'package:flutter/foundation.dart';

class ResMapConfig {
  const ResMapConfig._();

  static const _androidMapId = String.fromEnvironment(
    'GOOGLE_MAPS_ANDROID_MAP_ID',
  );
  static const _iosMapId = String.fromEnvironment('GOOGLE_MAPS_IOS_MAP_ID');

  static String? get mapId {
    if (kIsWeb) {
      return null;
    }

    final value = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidMapId,
      TargetPlatform.iOS => _iosMapId,
      _ => '',
    };

    return value.trim().isEmpty ? null : value.trim();
  }
}
