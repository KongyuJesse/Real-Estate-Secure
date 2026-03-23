typedef JsonMap = Map<String, dynamic>;

enum ConsumerStage {
  splash,
  welcome,
  register,
  login,
  biometricUnlock,
  marketplace,
}

enum ConsumerTab { home, map, listings, finance, profile }

class ConsumerSession {
  const ConsumerSession({
    required this.baseUrl,
    this.bearerToken = '',
    this.refreshToken = '',
    this.userUuid = '',
    this.email = '',
    this.fullName = '',
    this.preferredTabIndex = 0,
  });

  final String baseUrl;
  final String bearerToken;
  final String refreshToken;
  final String userUuid;
  final String email;
  final String fullName;
  final int preferredTabIndex;

  String get normalizedBaseUrl => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  bool get hasServer => normalizedBaseUrl.trim().isNotEmpty;

  bool get isAuthenticated =>
      normalizedBaseUrl.trim().isNotEmpty && bearerToken.trim().isNotEmpty;

  bool get hasValues =>
      baseUrl.trim().isNotEmpty ||
      bearerToken.trim().isNotEmpty ||
      email.trim().isNotEmpty;

  ConsumerSession copyWith({
    String? baseUrl,
    String? bearerToken,
    String? refreshToken,
    String? userUuid,
    String? email,
    String? fullName,
    int? preferredTabIndex,
  }) => ConsumerSession(
    baseUrl: baseUrl ?? this.baseUrl,
    bearerToken: bearerToken ?? this.bearerToken,
    refreshToken: refreshToken ?? this.refreshToken,
    userUuid: userUuid ?? this.userUuid,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    preferredTabIndex: preferredTabIndex ?? this.preferredTabIndex,
  );
}

class ConsumerUserProfile {
  const ConsumerUserProfile({
    required this.uuid,
    required this.email,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.profileImageUrl,
    required this.preferredLanguage,
    required this.bio,
    required this.roles,
    required this.primaryRole,
    required this.isActive,
    required this.emailVerified,
    required this.phoneVerified,
    required this.isVerified,
    required this.kycVerified,
    required this.kycStatus,
    required this.twoFactorEnabled,
  });

  final String uuid;
  final String email;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String profileImageUrl;
  final String preferredLanguage;
  final String bio;
  final List<String> roles;
  final String primaryRole;
  final bool isActive;
  final bool emailVerified;
  final bool phoneVerified;
  final bool isVerified;
  final bool kycVerified;
  final String kycStatus;
  final bool twoFactorEnabled;

  String get displayName => '$firstName $lastName'.trim();
  String get initials {
    final parts = displayName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'RE';
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  String get resolvedAvatarUrl {
    if (profileImageUrl.trim().isNotEmpty) {
      return profileImageUrl.trim();
    }
    return '';
  }

  String get resolvedPrimaryRole => resolvePrimaryConsumerRole(
    primaryRole.isNotEmpty ? [primaryRole, ...roles] : roles,
  );
  bool get hasRestrictedMobileRole => hasRestrictedConsumerRole(roles);

  factory ConsumerUserProfile.fromJson(JsonMap json) => ConsumerUserProfile(
    uuid: json['uuid']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phoneNumber: json['phone_number']?.toString() ?? '',
    firstName: json['first_name']?.toString() ?? '',
    lastName: json['last_name']?.toString() ?? '',
    profileImageUrl: json['profile_image_url']?.toString() ?? '',
    preferredLanguage: json['preferred_language']?.toString() ?? 'en',
    bio: json['bio']?.toString() ?? '',
    roles: (json['roles'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    primaryRole: json['primary_role']?.toString() ?? '',
    isActive: json['is_active'] == true,
    emailVerified: json['email_verified'] == true,
    phoneVerified: json['phone_verified'] == true,
    isVerified: json['is_verified'] == true,
    kycVerified: json['kyc_verified'] == true,
    kycStatus: json['kyc_status']?.toString() ?? 'pending',
    twoFactorEnabled: json['two_factor_enabled'] == true,
  );
}

class ConsumerUserPreferences {
  const ConsumerUserPreferences({
    required this.locale,
    required this.emailNotificationsEnabled,
    required this.smsNotificationsEnabled,
    required this.pushNotificationsEnabled,
    required this.marketingNotificationsEnabled,
  });

  final String locale;
  final bool emailNotificationsEnabled;
  final bool smsNotificationsEnabled;
  final bool pushNotificationsEnabled;
  final bool marketingNotificationsEnabled;

  factory ConsumerUserPreferences.fromJson(JsonMap json) =>
      ConsumerUserPreferences(
        locale: json['locale']?.toString() ?? 'en',
        emailNotificationsEnabled: json['email_notifications_enabled'] == true,
        smsNotificationsEnabled: json['sms_notifications_enabled'] == true,
        pushNotificationsEnabled: json['push_notifications_enabled'] == true,
        marketingNotificationsEnabled:
            json['marketing_notifications_enabled'] == true,
      );
}

class ConsumerKycRecord {
  const ConsumerKycRecord({
    required this.id,
    required this.provider,
    required this.flowKind,
    required this.title,
    required this.reference,
    required this.verificationStatus,
    this.documentType = '',
    this.documentNumber = '',
    this.reviewStatus = '',
    this.reviewAnswer = '',
    this.reviewRejectType = '',
    this.latestNote = '',
    this.createdAt,
    this.verifiedAt,
  });

  final String id;
  final String provider;
  final String flowKind;
  final String title;
  final String reference;
  final String documentType;
  final String documentNumber;
  final String verificationStatus;
  final String reviewStatus;
  final String reviewAnswer;
  final String reviewRejectType;
  final String latestNote;
  final DateTime? createdAt;
  final DateTime? verifiedAt;

  bool get isProviderFlow => flowKind == 'provider_sdk';

  factory ConsumerKycRecord.fromJson(JsonMap json) => ConsumerKycRecord(
    id: json['id']?.toString() ?? '',
    provider: json['provider']?.toString() ?? 'sumsub',
    flowKind: json['flow_kind']?.toString() ?? 'provider_sdk',
    title:
        json['title']?.toString() ??
        json['document_type']?.toString() ??
        'Identity check',
    reference:
        json['reference']?.toString() ??
        json['document_number']?.toString() ??
        '',
    documentType: json['document_type']?.toString() ?? '',
    documentNumber: json['document_number']?.toString() ?? '',
    verificationStatus: json['verification_status']?.toString() ?? 'pending',
    reviewStatus: json['review_status']?.toString() ?? '',
    reviewAnswer: json['review_answer']?.toString() ?? '',
    reviewRejectType: json['review_reject_type']?.toString() ?? '',
    latestNote: json['latest_note']?.toString() ?? '',
    createdAt: readDateTime(json['created_at']),
    verifiedAt: readDateTime(json['verified_at']),
  );
}

class ConsumerKycSession {
  const ConsumerKycSession({
    required this.provider,
    required this.displayName,
    required this.accessToken,
    required this.externalUserId,
    required this.levelName,
    required this.role,
    required this.roleLabel,
    required this.purpose,
    required this.expiresAt,
    required this.verificationStatus,
    required this.reviewStatus,
    required this.captureFallbackPolicy,
    this.externalActionId,
    this.reviewAnswer,
    this.reviewRejectType,
  });

  final String provider;
  final String displayName;
  final String accessToken;
  final String externalUserId;
  final String levelName;
  final String role;
  final String roleLabel;
  final String purpose;
  final DateTime? expiresAt;
  final String verificationStatus;
  final String reviewStatus;
  final String captureFallbackPolicy;
  final String? externalActionId;
  final String? reviewAnswer;
  final String? reviewRejectType;

  factory ConsumerKycSession.fromJson(JsonMap json) => ConsumerKycSession(
    provider: json['provider']?.toString() ?? 'sumsub',
    displayName: json['display_name']?.toString() ?? 'Secure identity check',
    accessToken: json['access_token']?.toString() ?? '',
    externalUserId: json['external_user_id']?.toString() ?? '',
    levelName: json['level_name']?.toString() ?? '',
    role: json['role']?.toString() ?? 'buyer',
    roleLabel: json['role_label']?.toString() ?? 'Buyer',
    purpose: json['purpose']?.toString() ?? 'kyc',
    expiresAt: readDateTime(json['expires_at']),
    verificationStatus: json['verification_status']?.toString() ?? 'pending',
    reviewStatus: json['review_status']?.toString() ?? 'init',
    captureFallbackPolicy:
        json['capture_fallback_policy']?.toString() ?? 'no_fallback',
    externalActionId: json['external_action_id']?.toString(),
    reviewAnswer: json['review_answer']?.toString(),
    reviewRejectType: json['review_reject_type']?.toString(),
  );
}

class ConsumerIntegrationStage {
  const ConsumerIntegrationStage({
    required this.code,
    required this.label,
    required this.title,
    required this.description,
  });

  final String code;
  final String label;
  final String title;
  final String description;

  factory ConsumerIntegrationStage.fromJson(JsonMap json) =>
      ConsumerIntegrationStage(
        code: json['code']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
      );
}

class ConsumerKycProviderSummary {
  const ConsumerKycProviderSummary({
    required this.provider,
    required this.displayName,
    required this.role,
    required this.roleLabel,
    required this.integrationMode,
    required this.appShellOwner,
    required this.captureUiOwner,
    required this.decisionOwner,
    required this.captureFallbackPolicy,
    required this.capabilities,
    required this.recommendation,
    required this.stages,
  });

  final String provider;
  final String displayName;
  final String role;
  final String roleLabel;
  final String integrationMode;
  final String appShellOwner;
  final String captureUiOwner;
  final String decisionOwner;
  final String captureFallbackPolicy;
  final List<String> capabilities;
  final String recommendation;
  final List<ConsumerIntegrationStage> stages;

  bool get isProviderCapture => captureUiOwner == 'provider';

  factory ConsumerKycProviderSummary.fromJson(JsonMap json) {
    final parsedCapabilities = (json['capabilities'] as List? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false);
    final parsedStages = (json['stages'] as List? ?? const [])
        .map(
          (item) => ConsumerIntegrationStage.fromJson(
            item is Map<String, dynamic> ? item : const <String, dynamic>{},
          ),
        )
        .toList(growable: false);

    return ConsumerKycProviderSummary(
      provider:
          json['provider']?.toString() ??
          defaultConsumerKycProviderSummary.provider,
      displayName:
          json['display_name']?.toString() ??
          defaultConsumerKycProviderSummary.displayName,
      role: json['role']?.toString() ?? defaultConsumerKycProviderSummary.role,
      roleLabel:
          json['role_label']?.toString() ??
          defaultConsumerKycProviderSummary.roleLabel,
      integrationMode: json['integration_mode']?.toString() ?? 'hybrid_sdk',
      appShellOwner: json['app_shell_owner']?.toString() ?? 'platform',
      captureUiOwner: json['capture_ui_owner']?.toString() ?? 'provider',
      decisionOwner: json['decision_owner']?.toString() ?? 'platform',
      captureFallbackPolicy:
          json['capture_fallback_policy']?.toString() ??
          defaultConsumerKycProviderSummary.captureFallbackPolicy,
      capabilities: parsedCapabilities.isEmpty
          ? defaultConsumerKycProviderSummary.capabilities
          : parsedCapabilities,
      recommendation:
          json['recommendation']?.toString() ??
          defaultConsumerKycProviderSummary.recommendation,
      stages: parsedStages.isEmpty
          ? defaultConsumerKycProviderSummary.stages
          : parsedStages,
    );
  }
}

const defaultConsumerKycProviderSummary = ConsumerKycProviderSummary(
  provider: 'sumsub',
  displayName: 'Secure identity check',
  role: 'buyer',
  roleLabel: 'Buyer',
  integrationMode: 'hybrid_sdk',
  appShellOwner: 'platform',
  captureUiOwner: 'provider',
  decisionOwner: 'platform',
  captureFallbackPolicy: 'no_fallback',
  capabilities: [
    'native_sdk',
    'access_token_refresh',
    'applicant_actions',
    'email_verification',
    'phone_verification',
  ],
  recommendation:
      'Keep the flow inside the app, open the guided identity check when needed, and return people to a clear status view.',
  stages: [
    ConsumerIntegrationStage(
      code: 'entry',
      label: 'Entry',
      title: 'In-app status',
      description: 'Keep the next step visible and easy to resume.',
    ),
    ConsumerIntegrationStage(
      code: 'capture',
      label: 'Capture',
      title: 'Guided identity check',
      description:
          'Handle document, selfie, liveness, email, and phone checks on mobile.',
    ),
    ConsumerIntegrationStage(
      code: 'result',
      label: 'Result',
      title: 'Clear status',
      description:
          'Bring the result back into the app with a simple trusted status.',
    ),
  ],
);

class ConsumerTask {
  const ConsumerTask({
    required this.code,
    required this.role,
    required this.priority,
    required this.title,
    required this.description,
    required this.resourceType,
    required this.resourceId,
    required this.actionPath,
    this.createdAt,
  });

  final String code;
  final String role;
  final String priority;
  final String title;
  final String description;
  final String resourceType;
  final String resourceId;
  final String actionPath;
  final DateTime? createdAt;

  factory ConsumerTask.fromJson(JsonMap json) => ConsumerTask(
    code: json['code']?.toString() ?? '',
    role: json['role']?.toString() ?? 'all',
    priority: json['priority']?.toString() ?? 'normal',
    title: json['title']?.toString() ?? 'Task',
    description: json['description']?.toString() ?? '',
    resourceType: json['resource_type']?.toString() ?? '',
    resourceId: json['resource_id']?.toString() ?? '',
    actionPath: json['action_path']?.toString() ?? '',
    createdAt: readDateTime(json['created_at']),
  );
}

class ConsumerNotificationRecord {
  const ConsumerNotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.category,
    required this.status,
    this.actionUrl,
    this.actionLabel,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String severity;
  final String category;
  final String status;
  final String? actionUrl;
  final String? actionLabel;
  final DateTime? createdAt;

  factory ConsumerNotificationRecord.fromJson(JsonMap json) =>
      ConsumerNotificationRecord(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Notification',
        body: json['body']?.toString() ?? '',
        severity: json['severity']?.toString() ?? 'info',
        category: json['category']?.toString() ?? 'activity',
        status: json['status']?.toString() ?? 'unread',
        actionUrl: json['action_url']?.toString(),
        actionLabel: json['action_label']?.toString(),
        createdAt: readDateTime(json['created_at']),
      );
}

class ConsumerActionPreview {
  const ConsumerActionPreview({
    required this.accepted,
    this.delivery,
    this.previewToken,
    this.previewCode,
    this.previewExpiresAt,
  });

  final bool accepted;
  final String? delivery;
  final String? previewToken;
  final String? previewCode;
  final DateTime? previewExpiresAt;

  factory ConsumerActionPreview.fromJson(JsonMap json) => ConsumerActionPreview(
    accepted: json['accepted'] == true,
    delivery: json['delivery']?.toString(),
    previewToken: json['preview_token']?.toString(),
    previewCode: json['preview_code']?.toString(),
    previewExpiresAt: readDateTime(json['preview_expires_at']),
  );
}

class ConsumerContactVerificationResult {
  const ConsumerContactVerificationResult({
    required this.channel,
    required this.verified,
    required this.verificationStatus,
    required this.reviewStatus,
    this.externalActionId,
    this.reviewAnswer,
    this.reviewRejectType,
    this.emailVerified = false,
    this.phoneVerified = false,
  });

  final String channel;
  final bool verified;
  final String verificationStatus;
  final String reviewStatus;
  final String? externalActionId;
  final String? reviewAnswer;
  final String? reviewRejectType;
  final bool emailVerified;
  final bool phoneVerified;

  factory ConsumerContactVerificationResult.fromJson(JsonMap json) =>
      ConsumerContactVerificationResult(
        channel: json['channel']?.toString() ?? '',
        verified: json['verified'] == true,
        verificationStatus:
            json['verification_status']?.toString() ?? 'pending',
        reviewStatus: json['review_status']?.toString() ?? 'init',
        externalActionId: json['external_action_id']?.toString(),
        reviewAnswer: json['review_answer']?.toString(),
        reviewRejectType: json['review_reject_type']?.toString(),
        emailVerified: json['email_verified'] == true,
        phoneVerified: json['phone_verified'] == true,
      );
}

class ConsumerTwoFactorSetup {
  const ConsumerTwoFactorSetup({
    required this.accepted,
    required this.secret,
    required this.otpAuthUrl,
    required this.issuer,
    required this.digits,
    required this.periodSec,
    required this.alreadyEnabled,
  });

  final bool accepted;
  final String secret;
  final String otpAuthUrl;
  final String issuer;
  final int digits;
  final int periodSec;
  final bool alreadyEnabled;

  factory ConsumerTwoFactorSetup.fromJson(JsonMap json) =>
      ConsumerTwoFactorSetup(
        accepted: json['accepted'] == true,
        secret: json['secret']?.toString() ?? '',
        otpAuthUrl: json['otpauth_url']?.toString() ?? '',
        issuer: json['issuer']?.toString() ?? 'Real Estate Secure',
        digits: (json['digits'] as num?)?.toInt() ?? 6,
        periodSec: (json['period_sec'] as num?)?.toInt() ?? 30,
        alreadyEnabled: json['already_enabled'] == true,
      );
}

class ConsumerPropertySummary {
  const ConsumerPropertySummary({
    required this.id,
    required this.title,
    required this.city,
    required this.region,
    required this.priceXaf,
    required this.type,
    required this.listingType,
    required this.isFeatured,
    this.status,
    this.verificationStatus,
    this.riskLane,
    this.admissionStatus,
    this.coverImageUrl,
  });

  final String id;
  final String title;
  final String city;
  final String region;
  final double priceXaf;
  final String type;
  final String listingType;
  final bool isFeatured;
  final String? status;
  final String? verificationStatus;
  final String? riskLane;
  final String? admissionStatus;
  final String? coverImageUrl;

  String get locationLabel => '$city, $region';

  factory ConsumerPropertySummary.fromJson(JsonMap json) =>
      ConsumerPropertySummary(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Property',
        city: json['city']?.toString() ?? 'Cameroon',
        region: json['region']?.toString() ?? 'Cameroon',
        priceXaf: (json['price_xaf'] as num?)?.toDouble() ?? 0,
        type: json['type']?.toString() ?? 'land',
        listingType: json['listing_type']?.toString() ?? 'sale',
        isFeatured: json['is_featured'] == true,
        status: json['status']?.toString(),
        verificationStatus: json['verification_status']?.toString(),
        riskLane: json['risk_lane']?.toString(),
        admissionStatus: json['admission_status']?.toString(),
        coverImageUrl: json['cover_image_url']?.toString(),
      );
}

class ConsumerPropertyMapPoint {
  const ConsumerPropertyMapPoint({
    required this.id,
    required this.title,
    required this.price,
    required this.currency,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.region,
  });

  final String id;
  final String title;
  final double price;
  final String currency;
  final double latitude;
  final double longitude;
  final String city;
  final String region;

  factory ConsumerPropertyMapPoint.fromJson(JsonMap json) =>
      ConsumerPropertyMapPoint(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Property',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        currency: json['currency']?.toString() ?? 'XAF',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        city: json['city']?.toString() ?? '',
        region: json['region']?.toString() ?? '',
      );
}

class ConsumerPropertyLocation {
  const ConsumerPropertyLocation({
    required this.country,
    required this.region,
    required this.department,
    required this.city,
    this.district,
    this.neighborhood,
    this.streetAddress,
    this.landmark,
    this.latitude,
    this.longitude,
  });

  final String country;
  final String region;
  final String department;
  final String city;
  final String? district;
  final String? neighborhood;
  final String? streetAddress;
  final String? landmark;
  final double? latitude;
  final double? longitude;

  String get label => [
    streetAddress,
    neighborhood,
    district,
    city,
    region,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');

  factory ConsumerPropertyLocation.fromJson(JsonMap json) =>
      ConsumerPropertyLocation(
        country: json['country']?.toString() ?? 'Cameroon',
        region: json['region']?.toString() ?? 'Unknown',
        department: json['department']?.toString() ?? 'Unknown',
        city: json['city']?.toString() ?? 'Unknown',
        district: json['district']?.toString(),
        neighborhood: json['neighborhood']?.toString(),
        streetAddress: json['street_address']?.toString(),
        landmark: json['landmark']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class ConsumerPropertyDetail {
  const ConsumerPropertyDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.propertyType,
    required this.listingType,
    required this.price,
    required this.currency,
    required this.status,
    required this.verificationStatus,
    required this.isFeatured,
    required this.sellerIdentityVerifiedSnapshot,
    required this.declaredEncumbrance,
    required this.declaredDispute,
    required this.foreignPartyExpected,
    required this.oldTitleRisk,
    required this.courtLinked,
    required this.ministryFilingRequired,
    required this.municipalCertificateRequired,
    this.ownerUuid,
    this.ownerName,
    this.inventoryType,
    this.riskLane,
    this.admissionStatus,
    this.location,
  });

  final String id;
  final String title;
  final String description;
  final String propertyType;
  final String listingType;
  final double price;
  final String currency;
  final String status;
  final String verificationStatus;
  final bool isFeatured;
  final bool sellerIdentityVerifiedSnapshot;
  final bool declaredEncumbrance;
  final bool declaredDispute;
  final bool foreignPartyExpected;
  final bool oldTitleRisk;
  final bool courtLinked;
  final bool ministryFilingRequired;
  final bool municipalCertificateRequired;
  final String? ownerUuid;
  final String? ownerName;
  final String? inventoryType;
  final String? riskLane;
  final String? admissionStatus;
  final ConsumerPropertyLocation? location;

  factory ConsumerPropertyDetail.fromJson(JsonMap json) =>
      ConsumerPropertyDetail(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Property',
        description: json['description']?.toString() ?? '',
        propertyType: json['property_type']?.toString() ?? 'land',
        listingType: json['listing_type']?.toString() ?? 'sale',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        currency: json['currency']?.toString() ?? 'XAF',
        status: json['status']?.toString() ?? 'draft',
        verificationStatus:
            json['verification_status']?.toString() ?? 'pending',
        isFeatured: json['is_featured'] == true,
        sellerIdentityVerifiedSnapshot:
            json['seller_identity_verified_snapshot'] == true,
        declaredEncumbrance: json['declared_encumbrance'] == true,
        declaredDispute: json['declared_dispute'] == true,
        foreignPartyExpected: json['foreign_party_expected'] == true,
        oldTitleRisk: json['old_title_risk'] == true,
        courtLinked: json['court_linked'] == true,
        ministryFilingRequired: json['ministry_filing_required'] == true,
        municipalCertificateRequired:
            json['municipal_certificate_required'] == true,
        ownerUuid: json['owner_uuid']?.toString(),
        ownerName: json['owner_name']?.toString(),
        inventoryType: json['inventory_type']?.toString(),
        riskLane: json['risk_lane']?.toString(),
        admissionStatus: json['admission_status']?.toString(),
        location: json['location'] is Map<String, dynamic>
            ? ConsumerPropertyLocation.fromJson(
                json['location'] as Map<String, dynamic>,
              )
            : null,
      );
}

class ConsumerPropertyDocument {
  const ConsumerPropertyDocument({
    required this.id,
    required this.documentType,
    required this.documentNumber,
    required this.documentTitle,
    required this.isVerified,
    this.issueDate,
    this.expiryDate,
  });

  final String id;
  final String documentType;
  final String documentNumber;
  final String documentTitle;
  final bool isVerified;
  final DateTime? issueDate;
  final DateTime? expiryDate;

  factory ConsumerPropertyDocument.fromJson(JsonMap json) =>
      ConsumerPropertyDocument(
        id: json['id']?.toString() ?? '',
        documentType: json['document_type']?.toString() ?? '',
        documentNumber: json['document_number']?.toString() ?? '',
        documentTitle: json['document_title']?.toString() ?? '',
        isVerified: json['is_verified'] == true,
        issueDate: readDateTime(json['issue_date']),
        expiryDate: readDateTime(json['expiry_date']),
      );
}

class ConsumerPropertyImage {
  const ConsumerPropertyImage({
    required this.id,
    required this.imageType,
    required this.filePathOriginal,
    required this.mimeType,
    this.title,
    this.description,
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  final String id;
  final String imageType;
  final String filePathOriginal;
  final String mimeType;
  final String? title;
  final String? description;
  final bool isPrimary;
  final int sortOrder;

  factory ConsumerPropertyImage.fromJson(JsonMap json) => ConsumerPropertyImage(
    id: json['id']?.toString() ?? '',
    imageType: json['image_type']?.toString() ?? 'exterior',
    filePathOriginal: json['file_path_original']?.toString() ?? '',
    mimeType: json['mime_type']?.toString() ?? '',
    title: json['title']?.toString(),
    description: json['description']?.toString(),
    isPrimary: json['is_primary'] == true,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );
}

class ConsumerUploadedAsset {
  const ConsumerUploadedAsset({
    required this.category,
    required this.cloudEnabled,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    required this.fileHash,
    required this.storageDriver,
    required this.storagePath,
    required this.publicUrl,
    required this.uploadedAt,
  });

  final String category;
  final bool cloudEnabled;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String fileHash;
  final String storageDriver;
  final String storagePath;
  final String publicUrl;
  final DateTime? uploadedAt;

  factory ConsumerUploadedAsset.fromJson(JsonMap json) => ConsumerUploadedAsset(
    category: json['category']?.toString() ?? 'misc',
    cloudEnabled: json['cloud_enabled'] == true,
    fileName: json['file_name']?.toString() ?? '',
    mimeType: json['mime_type']?.toString() ?? 'application/octet-stream',
    fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
    fileHash: json['file_hash']?.toString() ?? '',
    storageDriver: json['storage_driver']?.toString() ?? 'filesystem',
    storagePath: json['storage_path']?.toString() ?? '',
    publicUrl: json['public_url']?.toString() ?? '',
    uploadedAt: readDateTime(json['uploaded_at']),
  );
}

class ConsumerUploadCapabilities {
  const ConsumerUploadCapabilities({
    required this.storageDriver,
    required this.storageLabel,
    required this.cloudEnabled,
    required this.maxUploadBytes,
    required this.acceptedMimeTypes,
  });

  final String storageDriver;
  final String storageLabel;
  final bool cloudEnabled;
  final int maxUploadBytes;
  final List<String> acceptedMimeTypes;

  factory ConsumerUploadCapabilities.fromJson(JsonMap json) =>
      ConsumerUploadCapabilities(
        storageDriver: json['storage_driver']?.toString() ?? 'filesystem',
        storageLabel: json['storage_label']?.toString() ?? 'Secure upload',
        cloudEnabled: json['cloud_enabled'] == true,
        maxUploadBytes: (json['max_upload_bytes'] as num?)?.toInt() ?? 0,
        acceptedMimeTypes: (json['accepted_mime_types'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
      );
}

const defaultConsumerUploadCapabilities = ConsumerUploadCapabilities(
  storageDriver: 'filesystem',
  storageLabel: 'Secure upload',
  cloudEnabled: false,
  maxUploadBytes: 12 * 1024 * 1024,
  acceptedMimeTypes: [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'application/pdf',
  ],
);

class ConsumerTransactionSummary {
  const ConsumerTransactionSummary({
    required this.uuid,
    required this.transactionNumber,
    required this.transactionStatus,
    required this.totalAmount,
    required this.currency,
    this.createdAt,
  });

  final String uuid;
  final String transactionNumber;
  final String transactionStatus;
  final double totalAmount;
  final String currency;
  final DateTime? createdAt;

  factory ConsumerTransactionSummary.fromJson(JsonMap json) =>
      ConsumerTransactionSummary(
        uuid: json['uuid']?.toString() ?? '',
        transactionNumber: json['transaction_number']?.toString() ?? '',
        transactionStatus:
            json['transaction_status']?.toString() ?? 'initiated',
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency']?.toString() ?? 'XAF',
        createdAt: readDateTime(json['created_at']),
      );
}

class ConsumerTransactionDetail {
  const ConsumerTransactionDetail({
    required this.uuid,
    required this.transactionNumber,
    required this.transactionStatus,
    required this.transactionType,
    required this.settlementMode,
    required this.totalAmount,
    required this.currency,
    required this.propertyId,
    required this.buyerId,
    required this.sellerId,
    this.lawyerId,
    this.notaryId,
    this.createdAt,
    this.updatedAt,
  });

  final String uuid;
  final String transactionNumber;
  final String transactionStatus;
  final String transactionType;
  final String settlementMode;
  final double totalAmount;
  final String currency;
  final String propertyId;
  final String buyerId;
  final String sellerId;
  final String? lawyerId;
  final String? notaryId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ConsumerTransactionDetail.fromJson(
    JsonMap json,
  ) => ConsumerTransactionDetail(
    uuid: json['uuid']?.toString() ?? '',
    transactionNumber: json['transaction_number']?.toString() ?? '',
    transactionStatus: json['transaction_status']?.toString() ?? 'initiated',
    transactionType: json['transaction_type']?.toString() ?? 'sale',
    settlementMode: json['settlement_mode']?.toString() ?? 'platform_escrow',
    totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
    currency: json['currency']?.toString() ?? 'XAF',
    propertyId: json['property_id']?.toString() ?? '',
    buyerId: json['buyer_id']?.toString() ?? '',
    sellerId: json['seller_id']?.toString() ?? '',
    lawyerId: json['lawyer_id']?.toString(),
    notaryId: json['notary_id']?.toString(),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );
}

class ConsumerTransactionCompliance {
  const ConsumerTransactionCompliance({
    required this.transactionId,
    required this.transactionStatus,
    required this.settlementMode,
    required this.legalCaseType,
    required this.lawyerRequirementLevel,
    required this.notaryRequirementLevel,
    required this.foreignPartyInvolved,
    required this.automationFrozen,
    required this.automationFreezeReason,
    required this.offlineWorkflowRequired,
    required this.assistedLaneReason,
    required this.offlineStepCount,
    required this.legalCaseCount,
  });

  final String transactionId;
  final String transactionStatus;
  final String settlementMode;
  final String legalCaseType;
  final String lawyerRequirementLevel;
  final String notaryRequirementLevel;
  final bool foreignPartyInvolved;
  final bool automationFrozen;
  final String automationFreezeReason;
  final bool offlineWorkflowRequired;
  final String assistedLaneReason;
  final int offlineStepCount;
  final int legalCaseCount;

  factory ConsumerTransactionCompliance.fromJson(JsonMap json) {
    final counts = json['counts'] is Map<String, dynamic>
        ? json['counts'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ConsumerTransactionCompliance(
      transactionId: json['transaction_id']?.toString() ?? '',
      transactionStatus: json['transaction_status']?.toString() ?? 'initiated',
      settlementMode: json['settlement_mode']?.toString() ?? 'platform_escrow',
      legalCaseType: json['legal_case_type']?.toString() ?? 'standard_sale',
      lawyerRequirementLevel:
          json['lawyer_requirement_level']?.toString() ?? 'recommended',
      notaryRequirementLevel:
          json['notary_requirement_level']?.toString() ?? 'required',
      foreignPartyInvolved: json['foreign_party_involved'] == true,
      automationFrozen: json['automation_frozen'] == true,
      automationFreezeReason:
          json['automation_freeze_reason']?.toString() ?? '',
      offlineWorkflowRequired: json['offline_workflow_required'] == true,
      assistedLaneReason: json['assisted_lane_reason']?.toString() ?? '',
      offlineStepCount:
          (counts['offline_steps'] as num?)?.toInt() ??
          (json['offline_step_count'] as num?)?.toInt() ??
          0,
      legalCaseCount:
          (counts['legal_cases'] as num?)?.toInt() ??
          (json['legal_case_count'] as num?)?.toInt() ??
          0,
    );
  }
}

class ConsumerTimelineEvent {
  const ConsumerTimelineEvent({
    required this.type,
    required this.status,
    this.label,
    this.createdAt,
  });

  final String type;
  final String status;
  final String? label;
  final DateTime? createdAt;

  factory ConsumerTimelineEvent.fromJson(JsonMap json) => ConsumerTimelineEvent(
    type: json['type']?.toString() ?? 'event',
    status: json['status']?.toString() ?? '',
    label: json['label']?.toString(),
    createdAt: readDateTime(json['created_at']),
  );
}

class ConsumerSubscriptionPlan {
  const ConsumerSubscriptionPlan({
    required this.id,
    required this.planName,
    required this.planCode,
    required this.priceMonthly,
    required this.priceYearly,
    required this.currency,
    required this.maxListings,
    required this.maxPhotosPerListing,
    required this.maxVideosPerListing,
    required this.featuredListingsIncluded,
    required this.prioritySupport,
    required this.analyticsAccess,
    required this.apiAccess,
    required this.bulkListingTools,
    required this.companyProfile,
    required this.badgeDisplay,
    required this.description,
    required this.features,
  });

  final int id;
  final String planName;
  final String planCode;
  final double priceMonthly;
  final double? priceYearly;
  final String currency;
  final int maxListings;
  final int maxPhotosPerListing;
  final int maxVideosPerListing;
  final int featuredListingsIncluded;
  final bool prioritySupport;
  final bool analyticsAccess;
  final bool apiAccess;
  final bool bulkListingTools;
  final bool companyProfile;
  final String badgeDisplay;
  final String description;
  final List<String> features;

  double? get yearlySavings {
    if (priceYearly == null || priceMonthly <= 0) {
      return null;
    }
    final fullYear = priceMonthly * 12;
    final savings = fullYear - priceYearly!;
    return savings > 0 ? savings : null;
  }

  factory ConsumerSubscriptionPlan.fromJson(JsonMap json) =>
      ConsumerSubscriptionPlan(
        id: readInt(json['id']) ?? 0,
        planName: json['plan_name']?.toString() ?? '',
        planCode: json['plan_code']?.toString() ?? '',
        priceMonthly: readDouble(json['price_monthly']) ?? 0,
        priceYearly: readDouble(json['price_yearly']),
        currency: json['currency']?.toString() ?? 'XAF',
        maxListings: readInt(json['max_listings']) ?? 0,
        maxPhotosPerListing: readInt(json['max_photos_per_listing']) ?? 0,
        maxVideosPerListing: readInt(json['max_videos_per_listing']) ?? 0,
        featuredListingsIncluded:
            readInt(json['featured_listings_included']) ?? 0,
        prioritySupport: readBool(json['priority_support']),
        analyticsAccess: readBool(json['analytics_access']),
        apiAccess: readBool(json['api_access']),
        bulkListingTools: readBool(json['bulk_listing_tools']),
        companyProfile: readBool(json['company_profile']),
        badgeDisplay: json['badge_display']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        features: (json['features'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
      );
}

class ConsumerCurrentSubscription {
  const ConsumerCurrentSubscription({
    required this.planName,
    required this.planCode,
    required this.subscriptionStatus,
    required this.billingCycle,
    required this.startDate,
    required this.endDate,
    required this.currency,
    required this.pricePaid,
    required this.description,
    required this.badgeDisplay,
    required this.maxListings,
    required this.maxPhotosPerListing,
    required this.maxVideosPerListing,
    required this.featuredListingsIncluded,
    required this.prioritySupport,
    required this.analyticsAccess,
    required this.apiAccess,
    required this.bulkListingTools,
    required this.companyProfile,
  });

  final String planName;
  final String planCode;
  final String subscriptionStatus;
  final String billingCycle;
  final DateTime? startDate;
  final DateTime? endDate;
  final String currency;
  final double pricePaid;
  final String description;
  final String badgeDisplay;
  final int maxListings;
  final int maxPhotosPerListing;
  final int maxVideosPerListing;
  final int featuredListingsIncluded;
  final bool prioritySupport;
  final bool analyticsAccess;
  final bool apiAccess;
  final bool bulkListingTools;
  final bool companyProfile;

  factory ConsumerCurrentSubscription.fromJson(
    JsonMap json,
  ) => ConsumerCurrentSubscription(
    planName: json['plan_name']?.toString() ?? '',
    planCode: json['plan_code']?.toString() ?? '',
    subscriptionStatus: json['subscription_status']?.toString() ?? 'inactive',
    billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
    startDate: readDateTime(json['start_date']),
    endDate: readDateTime(json['end_date']),
    currency: json['currency']?.toString() ?? 'XAF',
    pricePaid: readDouble(json['price_paid']) ?? 0,
    description: json['description']?.toString() ?? '',
    badgeDisplay: json['badge_display']?.toString() ?? '',
    maxListings: readInt(json['max_listings']) ?? 0,
    maxPhotosPerListing: readInt(json['max_photos_per_listing']) ?? 0,
    maxVideosPerListing: readInt(json['max_videos_per_listing']) ?? 0,
    featuredListingsIncluded: readInt(json['featured_listings_included']) ?? 0,
    prioritySupport: readBool(json['priority_support']),
    analyticsAccess: readBool(json['analytics_access']),
    apiAccess: readBool(json['api_access']),
    bulkListingTools: readBool(json['bulk_listing_tools']),
    companyProfile: readBool(json['company_profile']),
  );
}

class ConsumerPaymentGatewaySummary {
  const ConsumerPaymentGatewaySummary({
    required this.provider,
    required this.configured,
    required this.currency,
    required this.collectionRails,
    required this.payoutRails,
    required this.recurringSupport,
    required this.checkoutMode,
    required this.selectionUiOwner,
    required this.checkoutUiOwner,
    required this.reconciliationOwner,
    required this.webhookReconciliation,
    required this.recommendedFor,
  });

  final String provider;
  final bool configured;
  final String currency;
  final List<String> collectionRails;
  final List<String> payoutRails;
  final bool recurringSupport;
  final String checkoutMode;
  final String selectionUiOwner;
  final String checkoutUiOwner;
  final String reconciliationOwner;
  final bool webhookReconciliation;
  final String recommendedFor;

  factory ConsumerPaymentGatewaySummary.fromJson(JsonMap json) =>
      ConsumerPaymentGatewaySummary(
        provider: json['provider']?.toString() ?? '',
        configured: readBool(json['configured']),
        currency: json['currency']?.toString() ?? 'XAF',
        collectionRails: (json['collection_rails'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        payoutRails: (json['payout_rails'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        recurringSupport: readBool(json['recurring_support']),
        checkoutMode: json['checkout_mode']?.toString() ?? 'provider_hosted',
        selectionUiOwner: json['selection_ui_owner']?.toString() ?? 'platform',
        checkoutUiOwner: json['checkout_ui_owner']?.toString() ?? 'provider',
        reconciliationOwner:
            json['reconciliation_owner']?.toString() ?? 'platform',
        webhookReconciliation: readBool(json['webhook_reconciliation']),
        recommendedFor: json['recommended_for']?.toString() ?? '',
      );
}

class ConsumerSubscriptionCheckoutSession {
  const ConsumerSubscriptionCheckoutSession({
    required this.provider,
    required this.txRef,
    required this.checkoutUrl,
    required this.amount,
    required this.currency,
    required this.planId,
    required this.planCode,
    required this.billingCycle,
  });

  final String provider;
  final String txRef;
  final String checkoutUrl;
  final double amount;
  final String currency;
  final int planId;
  final String planCode;
  final String billingCycle;

  factory ConsumerSubscriptionCheckoutSession.fromJson(JsonMap json) =>
      ConsumerSubscriptionCheckoutSession(
        provider: json['provider']?.toString() ?? '',
        txRef: json['tx_ref']?.toString() ?? '',
        checkoutUrl: json['checkout_url']?.toString() ?? '',
        amount: readDouble(json['amount']) ?? 0,
        currency: json['currency']?.toString() ?? 'XAF',
        planId: readInt(json['plan_id']) ?? 0,
        planCode: json['plan_code']?.toString() ?? '',
        billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      );
}

class ConsumerSubscriptionCheckoutState {
  const ConsumerSubscriptionCheckoutState({
    required this.id,
    required this.reference,
    required this.provider,
    required this.planId,
    required this.planName,
    required this.planCode,
    required this.billingCycle,
    required this.sessionStatus,
    required this.providerStatus,
    required this.checkoutUrl,
    required this.callbackUrl,
    required this.amount,
    required this.currency,
    required this.errorMessage,
    required this.canResumeCheckout,
    required this.needsAttention,
    required this.returnHint,
    this.createdAt,
    this.updatedAt,
    this.paidAt,
  });

  final int id;
  final String reference;
  final String provider;
  final int planId;
  final String planName;
  final String planCode;
  final String billingCycle;
  final String sessionStatus;
  final String providerStatus;
  final String checkoutUrl;
  final String callbackUrl;
  final double amount;
  final String currency;
  final String errorMessage;
  final bool canResumeCheckout;
  final bool needsAttention;
  final String returnHint;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;

  bool get isPaid => sessionStatus == 'paid';
  bool get isPending => sessionStatus == 'pending';
  bool get isProcessing => sessionStatus == 'processing';
  bool get isAwaitingConfirmation => isPending || isProcessing;
  bool get isFailed => sessionStatus == 'failed';

  factory ConsumerSubscriptionCheckoutState.fromJson(JsonMap json) =>
      ConsumerSubscriptionCheckoutState(
        id: readInt(json['id']) ?? 0,
        reference: json['reference']?.toString() ?? '',
        provider: json['provider']?.toString() ?? '',
        planId: readInt(json['plan_id']) ?? 0,
        planName: json['plan_name']?.toString() ?? '',
        planCode: json['plan_code']?.toString() ?? '',
        billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
        sessionStatus: json['session_status']?.toString() ?? 'pending',
        providerStatus: json['provider_status']?.toString() ?? '',
        checkoutUrl: json['checkout_url']?.toString() ?? '',
        callbackUrl: json['callback_url']?.toString() ?? '',
        amount: readDouble(json['amount']) ?? 0,
        currency: json['currency']?.toString() ?? 'XAF',
        errorMessage: json['error_message']?.toString() ?? '',
        canResumeCheckout: readBool(json['can_resume_checkout']),
        needsAttention: readBool(json['needs_attention']),
        returnHint: json['return_hint']?.toString() ?? '',
        createdAt: readDateTime(json['created_at']),
        updatedAt: readDateTime(json['updated_at']),
        paidAt: readDateTime(json['paid_at']),
      );
}

class ConsumerServiceCatalogItem {
  const ConsumerServiceCatalogItem({
    required this.id,
    required this.serviceCode,
    required this.serviceName,
    required this.serviceType,
    required this.billingModel,
    required this.priceXaf,
    required this.description,
  });

  final int id;
  final String serviceCode;
  final String serviceName;
  final String serviceType;
  final String billingModel;
  final double priceXaf;
  final String description;

  factory ConsumerServiceCatalogItem.fromJson(JsonMap json) =>
      ConsumerServiceCatalogItem(
        id: readInt(json['id']) ?? 0,
        serviceCode: json['service_code']?.toString() ?? '',
        serviceName: json['service_name']?.toString() ?? '',
        serviceType: json['service_type']?.toString() ?? '',
        billingModel: json['billing_model']?.toString() ?? '',
        priceXaf: readDouble(json['price_xaf']) ?? 0,
        description: json['description']?.toString() ?? '',
      );
}

class ConsumerCatalogSnapshot {
  const ConsumerCatalogSnapshot({
    required this.featuredProperties,
    required this.allProperties,
    required this.mapPoints,
    this.usingFallbackData = false,
    this.warningMessage,
  });

  final List<ConsumerPropertySummary> featuredProperties;
  final List<ConsumerPropertySummary> allProperties;
  final List<ConsumerPropertyMapPoint> mapPoints;
  final bool usingFallbackData;
  final String? warningMessage;
}

DateTime? readDateTime(Object? value) {
  if (value case final String raw when raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}

double? readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value case final String raw when raw.trim().isNotEmpty) {
    return double.tryParse(raw.trim());
  }
  return null;
}

int? readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value case final String raw when raw.trim().isNotEmpty) {
    return int.tryParse(raw.trim());
  }
  return null;
}

bool readBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value case final String raw when raw.trim().isNotEmpty) {
    switch (raw.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'y':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'n':
      case 'off':
        return false;
    }
  }
  return fallback;
}

const _restrictedConsumerRoles = {
  'admin',
  'super_admin',
  'moderator',
  'auditor',
};

const _legacyRoleMap = {
  'tenant': 'buyer',
  'landlord': 'seller',
  'agent': 'seller',
  'super_admin': 'admin',
};

const _buyerLikeRoles = {'buyer'};
const _sellerLikeRoles = {'seller'};
const _professionalRoles = {'lawyer', 'notary'};
const _rolePriority = ['buyer', 'seller', 'lawyer', 'notary'];

String normalizeConsumerRole(String raw) {
  final normalized = raw.trim().toLowerCase();
  return _legacyRoleMap[normalized] ?? normalized;
}

bool hasRestrictedConsumerRole(List<String> roles) =>
    roles.map(normalizeConsumerRole).any(_restrictedConsumerRoles.contains);

String resolvePrimaryConsumerRole(List<String> roles) {
  final normalizedRoles = roles
      .map(normalizeConsumerRole)
      .where(
        (role) => role.isNotEmpty && !_restrictedConsumerRoles.contains(role),
      )
      .toSet();
  for (final role in _rolePriority) {
    if (normalizedRoles.contains(role)) {
      return role;
    }
  }
  return 'guest';
}

bool isBuyerLikeRole(String role) =>
    _buyerLikeRoles.contains(normalizeConsumerRole(role));

bool isSellerLikeRole(String role) =>
    _sellerLikeRoles.contains(normalizeConsumerRole(role));

bool isProfessionalRole(String role) =>
    _professionalRoles.contains(normalizeConsumerRole(role));

String consumerRoleLabel(String role) {
  switch (normalizeConsumerRole(role)) {
    case 'buyer':
      return 'Buyer';
    case 'seller':
      return 'Seller';
    case 'lawyer':
      return 'Lawyer';
    case 'notary':
      return 'Notary';
    default:
      return 'Guest';
  }
}

String formatXaf(num amount) {
  final rounded = amount.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final reverseIndex = rounded.length - index;
    buffer.write(rounded[index]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return '${buffer.toString()} XAF';
}

String startCase(String raw) => raw
    .split(RegExp(r'[_\-\s]+'))
    .where((part) => part.trim().isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
    .join(' ');
