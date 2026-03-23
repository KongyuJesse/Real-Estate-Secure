import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../ui/brand.dart';
import '../consumer_controller.dart';
import '../consumer_models.dart';
import 'free_tier_ad_policy.dart';

class ConsumerFreeTierAdSlot extends StatefulWidget {
  const ConsumerFreeTierAdSlot({
    super.key,
    required this.controller,
    required this.placement,
  });

  final ConsumerController controller;
  final String placement;

  @override
  State<ConsumerFreeTierAdSlot> createState() => _ConsumerFreeTierAdSlotState();
}

class _ConsumerFreeTierAdSlotState extends State<ConsumerFreeTierAdSlot> {
  static const _androidTestBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestBannerId = 'ca-app-pub-3940256099942544/2934735716';

  Future<ConsumerCurrentSubscription?>? _subscriptionFuture;
  BannerAd? _bannerAd;
  AdSize? _bannerSize;
  bool _bannerLoaded = false;
  bool _isLoadingBanner = false;
  int? _lastRequestedWidth;
  String? _lastRequestedUnitId;
  int? _pendingWidth;
  String? _pendingUnitId;

  @override
  void initState() {
    super.initState();
    if (ConsumerFreeTierAdPolicy.liveAdsEnabled) {
      _subscriptionFuture = widget.controller.loadCurrentSubscription();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ConsumerFreeTierAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller &&
        ConsumerFreeTierAdPolicy.liveAdsEnabled) {
      _subscriptionFuture = widget.controller.loadCurrentSubscription();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ConsumerFreeTierAdPolicy.liveAdsEnabled) {
      return const SizedBox.shrink();
    }

    final subscriptionFuture = _subscriptionFuture ??= widget.controller
        .loadCurrentSubscription();

    return LayoutBuilder(
      builder: (context, constraints) {
        return FutureBuilder<ConsumerCurrentSubscription?>(
          future: subscriptionFuture,
          builder: (context, snapshot) {
            if (!_shouldShowAd(snapshot.data)) {
              return const SizedBox.shrink();
            }

            final unitId = _bannerUnitId;
            if (unitId == null) {
              return const SizedBox.shrink();
            }

            final adWidth = constraints.maxWidth.floor();
            _scheduleBannerLoad(unitId, adWidth);

            if (!_bannerLoaded || _bannerAd == null || _bannerSize == null) {
              return _AdPlaceholder(placement: widget.placement);
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: constraints.maxWidth,
                height: _bannerSize!.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            );
          },
        );
      },
    );
  }

  String? get _bannerUnitId {
    if (!kReleaseMode) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _iosTestBannerId
          : _androidTestBannerId;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final value = const String.fromEnvironment('ADMOB_ANDROID_BANNER_ID');
      return value.trim().isEmpty ? null : value;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final value = const String.fromEnvironment('ADMOB_IOS_BANNER_ID');
      return value.trim().isEmpty ? null : value;
    }
    return null;
  }

  bool _shouldShowAd(ConsumerCurrentSubscription? current) {
    if (!widget.controller.isAuthenticated) {
      return true;
    }
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
  }

  void _scheduleBannerLoad(String unitId, int width) {
    if (width <= 0) {
      return;
    }
    if (_bannerAd != null &&
        _lastRequestedWidth == width &&
        _lastRequestedUnitId == unitId) {
      return;
    }
    if (_pendingWidth == width && _pendingUnitId == unitId) {
      return;
    }

    _pendingWidth = width;
    _pendingUnitId = unitId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final pendingWidth = _pendingWidth;
      final pendingUnitId = _pendingUnitId;
      _pendingWidth = null;
      _pendingUnitId = null;
      if (pendingWidth == null || pendingUnitId == null) {
        return;
      }
      _loadBanner(pendingUnitId, pendingWidth);
    });
  }

  void _loadBanner(String unitId, int width) {
    if (width <= 0 || _isLoadingBanner) {
      return;
    }
    if (_bannerAd != null &&
        _lastRequestedWidth == width &&
        _lastRequestedUnitId == unitId) {
      return;
    }

    final adaptiveSize = AdSize.getCurrentOrientationInlineAdaptiveBannerAdSize(
      width,
    );
    final previousAd = _bannerAd;
    BannerAd? banner;
    banner = BannerAd(
      adUnitId: unitId,
      size: adaptiveSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          final loadedBanner = ad as BannerAd;
          if (!mounted || _bannerAd != loadedBanner) {
            loadedBanner.dispose();
            return;
          }

          final platformSize = await loadedBanner.getPlatformAdSize();
          if (!mounted || _bannerAd != loadedBanner) {
            loadedBanner.dispose();
            return;
          }

          setState(() {
            _bannerLoaded = true;
            _isLoadingBanner = false;
            _bannerSize = platformSize ?? adaptiveSize;
          });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted || _bannerAd != ad) {
            return;
          }
          setState(() {
            _bannerAd = null;
            _bannerLoaded = false;
            _bannerSize = null;
            _isLoadingBanner = false;
          });
        },
      ),
    );

    setState(() {
      _isLoadingBanner = true;
      _bannerLoaded = false;
      _lastRequestedWidth = width;
      _lastRequestedUnitId = unitId;
      _bannerAd = banner;
      _bannerSize = adaptiveSize;
    });
    previousAd?.dispose();
    banner.load();
  }
}

class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder({required this.placement});

  final String placement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ResColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Sponsored',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: ResColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(flex: 7, child: _PlaceholderBar()),
              const SizedBox(width: 10),
              Expanded(
                flex: placement.length > 10 ? 3 : 2,
                child: const _PlaceholderBar(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaceholderBar extends StatelessWidget {
  const _PlaceholderBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
