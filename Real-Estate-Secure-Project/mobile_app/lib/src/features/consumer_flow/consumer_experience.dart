import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/consumer_api.dart';
import '../../data/consumer_security_preferences_store.dart';
import '../../data/device_permission_service.dart';
import '../../data/device_biometric_service.dart';
import '../../data/deep_link_service.dart';
import '../../data/consumer_session_store.dart';
import 'consumer_controller.dart';
import 'consumer_models.dart';
import 'pages/biometric_unlock_page.dart';
import 'pages/login_page.dart';
import 'pages/marketplace_shell.dart';
import 'pages/register_page.dart';
import 'pages/splash_page.dart';
import 'pages/welcome_page.dart';
import 'widgets/free_tier_interstitial_gate.dart';

class ConsumerExperiencePage extends StatefulWidget {
  const ConsumerExperiencePage({
    super.key,
    this.splashDuration = const Duration(milliseconds: 1800),
    this.sessionStore,
    this.apiClient,
    this.biometricService,
    this.devicePermissionService,
    this.securityPreferencesStore,
    this.deepLinkService,
    this.defaultConsumerApiBaseUrl,
  });

  final Duration splashDuration;
  final ConsumerSessionStore? sessionStore;
  final ConsumerApiClient? apiClient;
  final ConsumerBiometricService? biometricService;
  final ConsumerDevicePermissionService? devicePermissionService;
  final ConsumerSecurityPreferencesStore? securityPreferencesStore;
  final ConsumerDeepLinkService? deepLinkService;
  final String? defaultConsumerApiBaseUrl;

  @override
  State<ConsumerExperiencePage> createState() => _ConsumerExperiencePageState();
}

class _ConsumerExperiencePageState extends State<ConsumerExperiencePage> {
  late final ConsumerController _controller;
  StreamSubscription<ConsumerDeepLink>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    _controller = ConsumerController(
      apiClient: widget.apiClient ?? ConsumerApiClient(),
      sessionStore: widget.sessionStore ?? SecureConsumerSessionStore(),
      biometricService:
          widget.biometricService ?? const PlatformConsumerBiometricService(),
      devicePermissionService:
          widget.devicePermissionService ??
          const PlatformConsumerDevicePermissionService(),
      securityPreferencesStore:
          widget.securityPreferencesStore ??
          const SecureConsumerSecurityPreferencesStore(),
      splashDuration: widget.splashDuration,
      defaultBaseUrlOverride: widget.defaultConsumerApiBaseUrl,
    );
    _controller.bootstrap();
    unawaited(ConsumerFreeTierInterstitialGate.instance.warmUp());
    unawaited(_bindDeepLinks());
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOut,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                ...(currentChild == null
                    ? const <Widget>[]
                    : <Widget>[currentChild]),
              ],
            );
          },
          transitionBuilder: (child, animation) {
            final slideAnimation =
                Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slideAnimation, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_controller.stage),
            child: switch (_controller.stage) {
              ConsumerStage.splash => const ConsumerSplashPage(),
              ConsumerStage.welcome => ConsumerWelcomePage(
                onRegister: _controller.openRegister,
                onLogin: _controller.openLogin,
                onExploreGuest: _controller.continueAsGuest,
              ),
              ConsumerStage.register => ConsumerRegisterPage(
                controller: _controller,
                onBack: _controller.openWelcome,
              ),
              ConsumerStage.login => ConsumerLoginPage(
                controller: _controller,
                onBack: _controller.openWelcome,
              ),
              ConsumerStage.biometricUnlock => ConsumerBiometricUnlockPage(
                controller: _controller,
                onUseAnotherAccount: _controller.logout,
              ),
              ConsumerStage.marketplace => ConsumerMarketplaceShell(
                controller: _controller,
              ),
            },
          ),
        );
      },
    );
  }

  Future<void> _bindDeepLinks() async {
    final deepLinkService =
        widget.deepLinkService ?? PlatformConsumerDeepLinkService();
    await deepLinkService.getInitialLink();
    _deepLinkSubscription = deepLinkService.links.listen((_) {});
  }
}
