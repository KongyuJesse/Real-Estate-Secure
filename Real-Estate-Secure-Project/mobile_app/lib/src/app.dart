import 'package:flutter/material.dart';

import 'data/consumer_api.dart';
import 'data/consumer_security_preferences_store.dart';
import 'data/device_permission_service.dart';
import 'data/device_biometric_service.dart';
import 'data/deep_link_service.dart';
import 'data/consumer_session_store.dart';
import 'features/consumer_flow/consumer_experience.dart';
import 'ui/brand.dart';

class RealEstateSecureApp extends StatelessWidget {
  const RealEstateSecureApp({
    super.key,
    this.consumerSessionStore,
    this.consumerApiClient,
    this.consumerBiometricService,
    this.consumerDevicePermissionService,
    this.consumerSecurityPreferencesStore,
    this.deepLinkService,
    this.defaultConsumerApiBaseUrl,
  });

  final ConsumerSessionStore? consumerSessionStore;
  final ConsumerApiClient? consumerApiClient;
  final ConsumerBiometricService? consumerBiometricService;
  final ConsumerDevicePermissionService? consumerDevicePermissionService;
  final ConsumerSecurityPreferencesStore? consumerSecurityPreferencesStore;
  final ConsumerDeepLinkService? deepLinkService;
  final String? defaultConsumerApiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final consumerStore = consumerSessionStore ?? SecureConsumerSessionStore();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Real Estate Secure',
      theme: ResTheme.build(),
      home: ConsumerExperiencePage(
        sessionStore: consumerStore,
        apiClient: consumerApiClient,
        biometricService:
            consumerBiometricService ??
            const PlatformConsumerBiometricService(),
        devicePermissionService:
            consumerDevicePermissionService ??
            const PlatformConsumerDevicePermissionService(),
        securityPreferencesStore:
            consumerSecurityPreferencesStore ??
            const SecureConsumerSecurityPreferencesStore(),
        deepLinkService: deepLinkService,
        defaultConsumerApiBaseUrl: defaultConsumerApiBaseUrl,
      ),
    );
  }
}
