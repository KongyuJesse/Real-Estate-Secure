import 'package:flutter/foundation.dart';

class ConsumerFreeTierAdPolicy {
  const ConsumerFreeTierAdPolicy._();

  static const bool _enableDebugAds = bool.fromEnvironment(
    'ENABLE_DEBUG_ADS',
    defaultValue: false,
  );

  static bool get supportsPlatformAds {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool get liveAdsEnabled =>
      supportsPlatformAds && (kReleaseMode || _enableDebugAds);
}
