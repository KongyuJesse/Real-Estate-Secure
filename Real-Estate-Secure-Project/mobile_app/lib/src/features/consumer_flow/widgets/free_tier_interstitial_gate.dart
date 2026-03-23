import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../consumer_controller.dart';
import 'free_tier_ad_policy.dart';

class ConsumerFreeTierInterstitialGate {
  ConsumerFreeTierInterstitialGate._();

  static final ConsumerFreeTierInterstitialGate instance =
      ConsumerFreeTierInterstitialGate._();

  static const _androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _iosTestInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  bool _isShowing = false;
  DateTime? _lastShownAt;
  int _eligibleActionCount = 0;

  Future<void> warmUp() async {
    if (!ConsumerFreeTierAdPolicy.liveAdsEnabled ||
        _isLoading ||
        _interstitialAd != null) {
      return;
    }
    final unitId = _interstitialUnitId;
    if (unitId == null) {
      return;
    }

    _isLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isLoading = false;
          },
          onAdFailedToLoad: (_) {
            _interstitialAd = null;
            _isLoading = false;
          },
        ),
      );
    } catch (_) {
      _isLoading = false;
    }
  }

  Future<void> maybeShow({
    required ConsumerController controller,
    required String placement,
  }) async {
    if (!ConsumerFreeTierAdPolicy.liveAdsEnabled || _isShowing) {
      return;
    }

    final shouldMonetize = await _shouldMonetize(controller);
    if (!shouldMonetize) {
      return;
    }

    _eligibleActionCount += 1;
    final isOnCooldown =
        _lastShownAt != null &&
        DateTime.now().difference(_lastShownAt!) < const Duration(minutes: 2);
    if (_eligibleActionCount.isOdd || isOnCooldown) {
      unawaited(warmUp());
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      unawaited(warmUp());
      return;
    }

    final completer = Completer<void>();
    _isShowing = true;
    _interstitialAd = null;
    _lastShownAt = DateTime.now();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowing = false;
        completer.complete();
        unawaited(warmUp());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _isShowing = false;
        completer.complete();
        unawaited(warmUp());
      },
      onAdShowedFullScreenContent: (_) {
        debugPrint('Free-tier interstitial shown for $placement.');
      },
    );

    ad.show();
    await completer.future;
  }

  String? get _interstitialUnitId {
    if (!kReleaseMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosTestInterstitialId
          : _androidTestInterstitialId;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final value = const String.fromEnvironment(
        'ADMOB_ANDROID_INTERSTITIAL_ID',
      );
      return value.trim().isEmpty ? null : value.trim();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final value = const String.fromEnvironment('ADMOB_IOS_INTERSTITIAL_ID');
      return value.trim().isEmpty ? null : value.trim();
    }
    return null;
  }

  Future<bool> _shouldMonetize(ConsumerController controller) async {
    if (!controller.isAuthenticated) {
      return true;
    }

    try {
      final current = await controller.loadCurrentSubscription();
      if (current == null) {
        return true;
      }
      if (current.subscriptionStatus.toLowerCase() != 'active') {
        return true;
      }
      return const {
        'starter',
        'basic',
        'free',
      }.contains(current.planCode.toLowerCase());
    } catch (_) {
      return false;
    }
  }
}
