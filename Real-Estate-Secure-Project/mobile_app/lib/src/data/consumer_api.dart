import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'consumer_device_identity.dart';
import '../features/consumer_flow/consumer_models.dart';
import '../features/consumer_flow/pages/workspace/cameroon_location_catalog.dart';

typedef ConsumerSessionUpdateCallback =
    FutureOr<void> Function(ConsumerSession session);

class ConsumerApiFailure implements Exception {
  const ConsumerApiFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ConsumerMfaRequired extends ConsumerApiFailure {
  const ConsumerMfaRequired({
    required String message,
    required this.mfaToken,
    required this.expiresIn,
  }) : super(message, statusCode: 401);

  final String mfaToken;
  final int expiresIn;
}

class ConsumerAuthResult {
  const ConsumerAuthResult({required this.session, required this.profile});

  final ConsumerSession session;
  final ConsumerUserProfile profile;
}

class ConsumerApiClient {
  ConsumerApiClient({
    HttpClient? client,
    ConsumerDeviceIdentityProvider? deviceIdentityProvider,
    this.onSessionUpdated,
  }) : _client =
           client ??
           (HttpClient()..connectionTimeout = const Duration(seconds: 15)),
       _deviceIdentityProvider =
           deviceIdentityProvider ?? SecureConsumerDeviceIdentityStore();

  final HttpClient _client;
  final ConsumerDeviceIdentityProvider _deviceIdentityProvider;
  ConsumerSessionUpdateCallback? onSessionUpdated;
  Future<ConsumerSession>? _refreshInFlight;

  Future<ConsumerAuthResult> refreshSession(ConsumerSession session) async {
    if (session.refreshToken.trim().isEmpty) {
      throw const ConsumerApiFailure(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
      );
    }

    final payload = await _request(
      baseUrl: session.normalizedBaseUrl,
      method: 'POST',
      path: '/auth/refresh',
      body: {'refresh_token': session.refreshToken.trim()},
    );
    return _parseAuthPayload(payload, session.normalizedBaseUrl);
  }

  Future<ConsumerAuthResult> register({
    required String baseUrl,
    required String email,
    required String password,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String role,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'phone_number': phoneNumber.trim(),
        'phone_country_code': '+237',
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'date_of_birth': dateOfBirth.trim(),
        'role': role.trim(),
      },
    );
    return _parseAuthPayload(payload, baseUrl);
  }

  Future<ConsumerAuthResult> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    final map = _asMap(payload);
    if (map['mfa_required'] == true) {
      throw ConsumerMfaRequired(
        message: 'Two-factor authentication is required to finish sign-in.',
        mfaToken: map['mfa_token']?.toString() ?? '',
        expiresIn: (map['expires_in'] as num?)?.toInt() ?? 300,
      );
    }
    return _parseAuthPayload(payload, baseUrl);
  }

  Future<ConsumerAuthResult> completeTwoFactorLogin({
    required String baseUrl,
    required String mfaToken,
    required String code,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/auth/2fa/verify',
      body: {'mfa_token': mfaToken.trim(), 'code': code.trim()},
    );
    return _parseAuthPayload(payload, baseUrl);
  }

  Future<ConsumerActionPreview> requestPasswordReset({
    required String baseUrl,
    required String email,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/auth/forgot-password',
      body: {'email': email.trim()},
    );
    return ConsumerActionPreview.fromJson(_asMap(payload));
  }

  Future<void> completePasswordReset({
    required String baseUrl,
    required String token,
    required String password,
  }) async {
    await _request(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/auth/reset-password',
      body: {'token': token.trim(), 'password': password},
    );
  }

  Future<ConsumerTwoFactorSetup> beginTwoFactorEnrollment(
    ConsumerSession session, {
    bool force = false,
  }) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/auth/2fa/enable',
      body: {'force': force},
    );
    return ConsumerTwoFactorSetup.fromJson(_asMap(payload));
  }

  Future<void> confirmTwoFactorEnrollment(
    ConsumerSession session, {
    required String code,
  }) async {
    await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/auth/2fa/verify',
      body: {'code': code.trim()},
    );
  }

  Future<ConsumerUserProfile> getProfile(ConsumerSession session) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/users/profile',
    );
    return ConsumerUserProfile.fromJson(_asMap(payload));
  }

  Future<ConsumerUserProfile> updateProfile(
    ConsumerSession session, {
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? preferredLanguage,
    String? bio,
    String? profileImageUrl,
  }) async {
    final body = <String, dynamic>{};
    if (firstName != null) {
      body['first_name'] = firstName.trim();
    }
    if (lastName != null) {
      body['last_name'] = lastName.trim();
    }
    if (phoneNumber != null) {
      body['phone_number'] = phoneNumber.trim();
    }
    if (preferredLanguage != null) {
      body['preferred_language'] = preferredLanguage;
    }
    if (bio != null) {
      body['bio'] = bio.trim();
    }
    if (profileImageUrl != null) {
      body['profile_image_url'] = profileImageUrl.trim();
    }

    final payload = await _requestAuthenticated(
      session,
      method: 'PUT',
      path: '/users/profile',
      body: body,
    );
    return ConsumerUserProfile.fromJson(_asMap(payload));
  }

  Future<ConsumerUploadedAsset> uploadAsset(
    ConsumerSession session, {
    required String category,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/uploads',
      body: {
        'category': category,
        'file_name': fileName,
        'mime_type': mimeType,
        'base64_data': base64Encode(bytes),
      },
    );
    return ConsumerUploadedAsset.fromJson(_asMap(payload));
  }

  Future<ConsumerUploadCapabilities> getUploadCapabilities(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/uploads/capabilities',
    );
    return ConsumerUploadCapabilities.fromJson(_asMap(payload));
  }

  Future<List<ConsumerTask>> getTasks(ConsumerSession session) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/users/tasks?limit=12',
    );
    return _asList(payload)
        .map((item) => ConsumerTask.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<ConsumerPropertySummary>> listProperties({
    required String baseUrl,
    bool featuredOnly = false,
    int limit = 8,
    int page = 1,
    String? query,
  }) async {
    final path = query != null && query.trim().isNotEmpty
        ? '/properties/search?q=${Uri.encodeQueryComponent(query.trim())}&limit=$limit&page=$page'
        : '/properties?limit=$limit&page=$page${featuredOnly ? '&featured=true' : ''}';
    final payload = await _request(baseUrl: baseUrl, method: 'GET', path: path);
    return _asList(payload)
        .map((item) => ConsumerPropertySummary.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<ConsumerPropertyMapPoint>> listMapPoints({
    required String baseUrl,
    int limit = 24,
    int page = 1,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/properties/map?limit=$limit&page=$page',
    );
    return _asList(payload)
        .map((item) => ConsumerPropertyMapPoint.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<ConsumerPropertyDetail> getPropertyDetail({
    required String baseUrl,
    required String propertyId,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/properties/$propertyId',
    );
    return ConsumerPropertyDetail.fromJson(_asMap(payload));
  }

  Future<List<ConsumerPropertyDocument>> getPropertyDocuments({
    required String baseUrl,
    required String propertyId,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/properties/$propertyId/documents',
    );
    return _asList(payload)
        .map((item) => ConsumerPropertyDocument.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<ConsumerPropertyImage>> getPropertyImages({
    required String baseUrl,
    required String propertyId,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/properties/$propertyId/images',
    );
    return _asList(payload)
        .map((item) => ConsumerPropertyImage.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<ConsumerNotificationRecord>> listNotifications(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/notifications?limit=20',
    );
    return _asList(payload)
        .map((item) => ConsumerNotificationRecord.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<void> markNotificationRead(
    ConsumerSession session,
    String notificationId,
  ) async {
    await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/notifications/$notificationId/read',
    );
  }

  Future<void> dismissNotification(
    ConsumerSession session,
    String notificationId,
  ) async {
    await _requestAuthenticated(
      session,
      method: 'DELETE',
      path: '/notifications/$notificationId',
    );
  }

  Future<void> markAllNotificationsRead(ConsumerSession session) async {
    await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/notifications/read-all',
    );
  }

  Future<int> unreadNotificationCount(ConsumerSession session) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/notifications/unread-count',
    );
    final map = _asMap(payload);
    final count = map['unread_count'];
    if (count is int) {
      return count;
    }
    return int.tryParse(count?.toString() ?? '') ?? 0;
  }

  Future<ConsumerUserPreferences> getPreferences(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/users/preferences',
    );
    return ConsumerUserPreferences.fromJson(_asMap(payload));
  }

  Future<void> updatePreferences(
    ConsumerSession session, {
    String? locale,
    bool? emailNotificationsEnabled,
    bool? smsNotificationsEnabled,
    bool? pushNotificationsEnabled,
    bool? marketingNotificationsEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (locale != null) {
      body['locale'] = locale;
    }
    if (emailNotificationsEnabled != null) {
      body['email_notifications_enabled'] = emailNotificationsEnabled;
    }
    if (smsNotificationsEnabled != null) {
      body['sms_notifications_enabled'] = smsNotificationsEnabled;
    }
    if (pushNotificationsEnabled != null) {
      body['push_notifications_enabled'] = pushNotificationsEnabled;
    }
    if (marketingNotificationsEnabled != null) {
      body['marketing_notifications_enabled'] = marketingNotificationsEnabled;
    }

    await _requestAuthenticated(
      session,
      method: 'PUT',
      path: '/users/preferences',
      body: body,
    );
  }

  Future<List<ConsumerKycRecord>> getKycStatus(ConsumerSession session) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/users/kyc/status',
    );
    return _asList(payload)
        .map((item) => ConsumerKycRecord.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<ConsumerKycRecord>> refreshKycStatus(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/users/kyc/refresh',
    );
    final data = _asMap(payload);
    return _asList(data['records'])
        .map((item) => ConsumerKycRecord.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<ConsumerKycProviderSummary> getKycProviderSummary(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/users/kyc/provider-summary',
    );
    return ConsumerKycProviderSummary.fromJson(_asMap(payload));
  }

  Future<ConsumerKycSession> createKycSession(ConsumerSession session) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/users/kyc/session',
    );
    return ConsumerKycSession.fromJson(_asMap(payload));
  }

  Future<ConsumerKycSession> createContactVerificationSession(
    ConsumerSession session, {
    required String channel,
  }) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/users/contact-verification/session',
      body: {'channel': channel.trim().toLowerCase()},
    );
    return ConsumerKycSession.fromJson(_asMap(payload));
  }

  Future<ConsumerContactVerificationResult> refreshContactVerification(
    ConsumerSession session, {
    required String channel,
    String? externalActionId,
  }) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/users/contact-verification/refresh',
      body: {
        'channel': channel.trim().toLowerCase(),
        if ((externalActionId ?? '').trim().isNotEmpty)
          'external_action_id': externalActionId!.trim(),
      },
    );
    return ConsumerContactVerificationResult.fromJson(_asMap(payload));
  }

  Future<ConsumerKycRecord> submitKyc(
    ConsumerSession session, {
    required String documentType,
    required String documentNumber,
    required String issueDate,
    String? expiryDate,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String frontImagePath,
    String? backImagePath,
    String? portraitImagePath,
    String? livenessVideoPath,
  }) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/users/kyc/upload',
      body: {
        'document_type': documentType,
        'document_number': documentNumber,
        'issue_date': issueDate,
        'expiry_date': expiryDate,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'front_image_path': frontImagePath,
        'back_image_path': backImagePath,
        'portrait_image_path': portraitImagePath,
        'liveness_video_path': livenessVideoPath,
      },
    );
    return ConsumerKycRecord.fromJson(_asMap(payload));
  }

  Future<List<ConsumerTransactionSummary>> listTransactions(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/transactions?limit=20',
    );
    return _asList(payload)
        .map((item) => ConsumerTransactionSummary.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<ConsumerTransactionSummary> initiateTransaction(
    ConsumerSession session, {
    required String propertyId,
    required String sellerId,
    required String transactionType,
    required double propertyPrice,
    String settlementMode = 'platform_escrow',
  }) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/transactions/initiate',
      body: {
        'property_id': propertyId,
        'seller_id': sellerId,
        'transaction_type': transactionType,
        'property_price': propertyPrice,
        'settlement_mode': settlementMode,
      },
    );
    return ConsumerTransactionSummary.fromJson(_asMap(payload));
  }

  Future<ConsumerTransactionDetail> getTransactionDetail(
    ConsumerSession session,
    String transactionId,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/transactions/$transactionId',
    );
    return ConsumerTransactionDetail.fromJson(_asMap(payload));
  }

  Future<ConsumerTransactionCompliance> getTransactionCompliance(
    ConsumerSession session,
    String transactionId,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/transactions/$transactionId/compliance',
    );
    return ConsumerTransactionCompliance.fromJson(_asMap(payload));
  }

  Future<List<ConsumerTimelineEvent>> getTransactionTimeline(
    ConsumerSession session,
    String transactionId,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/transactions/$transactionId/timeline',
    );
    return _asList(payload)
        .map((item) => ConsumerTimelineEvent.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<ConsumerSubscriptionPlan>> listSubscriptionPlans({
    required String baseUrl,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/subscriptions/plans',
    );
    return _asList(payload)
        .map((item) => ConsumerSubscriptionPlan.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<CameroonRegionCatalog>> listCameroonLocationCatalog({
    required String baseUrl,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/properties/location-catalog/cameroon',
    );
    final data = _asMap(payload);
    final regions = data['regions'];
    if (regions is! List) {
      return const [];
    }
    return regions
        .map((item) => CameroonRegionCatalog.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<ConsumerSubscriptionPlan>> listSubscriptionPlansAuthenticated(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/subscriptions/plans',
    );
    return _asList(payload)
        .map((item) => ConsumerSubscriptionPlan.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<ConsumerCurrentSubscription?> getCurrentSubscription(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/subscriptions/current',
    );
    final data = _asMap(payload);
    if (data.isEmpty) {
      return null;
    }
    return ConsumerCurrentSubscription.fromJson(data);
  }

  Future<ConsumerPaymentGatewaySummary> getPaymentGatewaySummary({
    required String baseUrl,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/payments/gateway/summary',
    );
    return ConsumerPaymentGatewaySummary.fromJson(_asMap(payload));
  }

  Future<ConsumerSubscriptionCheckoutSession> createSubscriptionCheckout(
    ConsumerSession session, {
    required int planId,
    required String billingCycle,
    String? redirectUrl,
  }) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/payments/gateway/subscriptions/checkout',
      body: {
        'plan_id': planId,
        'billing_cycle': billingCycle,
        if ((redirectUrl ?? '').trim().isNotEmpty) 'redirect_url': redirectUrl,
      },
    );
    return ConsumerSubscriptionCheckoutSession.fromJson(_asMap(payload));
  }

  Future<ConsumerSubscriptionCheckoutState?> getLatestSubscriptionCheckout(
    ConsumerSession session, {
    String? reference,
  }) async {
    final query = StringBuffer('/payments/gateway/subscriptions/latest');
    final normalizedReference = reference?.trim() ?? '';
    if (normalizedReference.isNotEmpty) {
      query.write(
        '?reference=${Uri.encodeQueryComponent(normalizedReference)}',
      );
    }

    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: query.toString(),
    );
    final data = _asMap(payload);
    if (data.isEmpty) {
      return null;
    }
    return ConsumerSubscriptionCheckoutState.fromJson(data);
  }

  Future<void> createSubscription(
    ConsumerSession session, {
    required ConsumerSubscriptionPlan plan,
    required String billingCycle,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/subscriptions',
      body: {
        'plan_id': plan.id,
        'billing_cycle': billingCycle,
        'start_date': _toDate(startDate),
        'end_date': _toDate(endDate),
        'next_billing_date': _toDate(endDate),
        'price_paid': billingCycle == 'yearly'
            ? (plan.priceYearly ?? plan.priceMonthly * 12)
            : plan.priceMonthly,
      },
    );
  }

  Future<void> upgradeSubscription(
    ConsumerSession session, {
    required int planId,
  }) async {
    await _requestAuthenticated(
      session,
      method: 'PUT',
      path: '/subscriptions/upgrade',
      body: {'plan_id': planId},
    );
  }

  Future<void> cancelSubscription(
    ConsumerSession session, {
    String? reason,
  }) async {
    await _requestAuthenticated(
      session,
      method: 'PUT',
      path: '/subscriptions/cancel',
      body: {'cancellation_reason': reason},
    );
  }

  Future<List<ConsumerServiceCatalogItem>> listServiceCatalog({
    required String baseUrl,
  }) async {
    final payload = await _request(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/services/catalog',
    );
    return _asList(payload)
        .map((item) => ConsumerServiceCatalogItem.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<String> createProperty(
    ConsumerSession session, {
    required String propertyType,
    required String listingType,
    required String title,
    required String description,
    required double price,
    required String region,
    required String department,
    required String city,
    String? district,
    String? neighborhood,
    String? streetAddress,
    String? landmark,
    required double latitude,
    required double longitude,
  }) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/properties',
      body: {
        'property_type': propertyType,
        'listing_type': listingType,
        'title': title,
        'description': description,
        'price': price,
        'region': region,
        'department': department,
        'city': city,
        'district': district,
        'neighborhood': neighborhood,
        'street_address': streetAddress,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return _asMap(payload)['id']?.toString() ?? '';
  }

  Future<void> addPropertyImage(
    ConsumerSession session, {
    required String propertyId,
    required ConsumerUploadedAsset asset,
    required String imageType,
    String? title,
    String? description,
  }) async {
    await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/properties/$propertyId/images',
      body: {
        'file_path_original': asset.storagePath,
        'mime_type': asset.mimeType,
        'file_hash': asset.fileHash,
        'file_size': asset.fileSize,
        'image_type': imageType,
        'title': title,
        'description': description,
      },
    );
  }

  Future<void> addPropertyDocument(
    ConsumerSession session, {
    required String propertyId,
    required ConsumerUploadedAsset asset,
    required String documentType,
    required String documentNumber,
    required String documentTitle,
    required String issuingAuthority,
    required String issueDate,
    String? expiryDate,
  }) async {
    await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/properties/$propertyId/documents',
      body: {
        'document_type': documentType,
        'document_number': documentNumber,
        'document_title': documentTitle,
        'issuing_authority': issuingAuthority,
        'issue_date': issueDate,
        'expiry_date': expiryDate,
        'file_path': asset.storagePath,
        'mime_type': asset.mimeType,
        'file_hash': asset.fileHash,
        'file_size': asset.fileSize,
      },
    );
  }

  Future<void> submitPropertyForVerification(
    ConsumerSession session,
    String propertyId,
  ) async {
    await _requestAuthenticated(
      session,
      method: 'POST',
      path: '/properties/$propertyId/verify',
    );
  }

  Future<List<ConsumerPropertySummary>> listFavorites(
    ConsumerSession session,
  ) async {
    final payload = await _requestAuthenticated(
      session,
      method: 'GET',
      path: '/users/favorites?limit=20',
    );
    return _asList(payload)
        .map((item) => ConsumerPropertySummary.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<void> setFavoriteStatus(
    ConsumerSession session, {
    required String propertyId,
    required bool isFavorite,
  }) async {
    await _requestAuthenticated(
      session,
      method: isFavorite ? 'POST' : 'DELETE',
      path: '/properties/$propertyId/favorite',
    );
  }

  ConsumerAuthResult _parseAuthPayload(Object? payload, String baseUrl) {
    final map = _asMap(payload);
    final profile = ConsumerUserProfile.fromJson(_asMap(map['user']));
    final session = ConsumerSession(
      baseUrl: baseUrl,
      bearerToken: map['token']?.toString() ?? '',
      refreshToken: map['refresh_token']?.toString() ?? '',
      userUuid: profile.uuid,
      email: profile.email,
      fullName: profile.displayName,
    );
    return ConsumerAuthResult(session: session, profile: profile);
  }

  Future<Object?> _requestAuthenticated(
    ConsumerSession session, {
    required String method,
    required String path,
    JsonMap? body,
  }) async {
    try {
      return await _request(
        baseUrl: session.normalizedBaseUrl,
        method: method,
        path: path,
        bearerToken: session.bearerToken,
        body: body,
      );
    } on ConsumerApiFailure catch (error) {
      if (error.statusCode != 401 || session.refreshToken.trim().isEmpty) {
        rethrow;
      }

      final refreshedSession = await _refreshActiveSession(session);
      await Future.sync(() => onSessionUpdated?.call(refreshedSession));
      return _request(
        baseUrl: refreshedSession.normalizedBaseUrl,
        method: method,
        path: path,
        bearerToken: refreshedSession.bearerToken,
        body: body,
      );
    }
  }

  Future<ConsumerSession> _refreshActiveSession(ConsumerSession session) {
    final inFlightRefresh = _refreshInFlight;
    if (inFlightRefresh != null) {
      return inFlightRefresh;
    }

    final refreshFuture = () async {
      final result = await refreshSession(session);
      return result.session.copyWith(
        preferredTabIndex: session.preferredTabIndex,
      );
    }();

    _refreshInFlight = refreshFuture;
    return refreshFuture.whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<Object?> _request({
    required String baseUrl,
    required String method,
    required String path,
    String? bearerToken,
    JsonMap? body,
  }) async {
    try {
      final normalizedBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final uri = Uri.parse('$normalizedBaseUrl$path');
      final request = await _client.openUrl(method, uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      final deviceIdentity = await _deviceIdentityProvider.load();
      request.headers.set('x-device-id', deviceIdentity.deviceId);
      request.headers.set('x-device-name', deviceIdentity.deviceName);
      request.headers.set('x-client-platform', deviceIdentity.platform);
      request.headers.set('x-app-version', deviceIdentity.appVersion);
      if (bearerToken != null && bearerToken.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${bearerToken.trim()}',
        );
      }
      if (body != null) {
        request.add(utf8.encode(jsonEncode(body)));
      }

      final response = await request.close();
      final raw = await response.transform(utf8.decoder).join();
      final decoded = raw.isEmpty ? null : jsonDecode(raw);

      if (response.statusCode >= 400) {
        throw ConsumerApiFailure(
          _extractError(decoded) ?? 'Request failed.',
          statusCode: response.statusCode,
        );
      }

      if (decoded is JsonMap && decoded['status'] == 'error') {
        throw ConsumerApiFailure(
          _extractError(decoded) ?? 'Request failed.',
          statusCode: response.statusCode,
        );
      }

      if (decoded is JsonMap && decoded.containsKey('data')) {
        return decoded['data'];
      }
      return decoded;
    } on ConsumerApiFailure {
      rethrow;
    } on SocketException {
      throw const ConsumerApiFailure(
        'We could not connect right now. Please try again.',
      );
    } on HandshakeException {
      throw const ConsumerApiFailure(
        'A secure connection to the server could not be established.',
      );
    } on HttpException {
      throw const ConsumerApiFailure(
        'The server connection was interrupted. Please try again.',
      );
    } on FormatException {
      throw const ConsumerApiFailure(
        'The server returned an invalid response. Please try again shortly.',
      );
    } on TimeoutException {
      throw const ConsumerApiFailure(
        'The server took too long to respond. Please try again.',
      );
    }
  }

  String? _extractError(Object? decoded) {
    if (decoded case {'error': final Object? error}) {
      final payload = _asMap(error);
      return payload['message']?.toString();
    }
    return null;
  }

  JsonMap _asMap(Object? value) {
    if (value is JsonMap) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  List<Object?> _asList(Object? value) {
    if (value is List) {
      return value.cast<Object?>();
    }
    return const <Object?>[];
  }

  String _toDate(DateTime value) => value.toIso8601String().split('T').first;
}
