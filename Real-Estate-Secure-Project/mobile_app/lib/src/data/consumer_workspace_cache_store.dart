import 'dart:convert';

import '../features/consumer_flow/consumer_models.dart';
import 'consumer_local_cache_database.dart';

class ConsumerWorkspaceCacheSnapshot {
  const ConsumerWorkspaceCacheSnapshot({
    required this.profile,
    required this.tasks,
    required this.savedProperties,
    required this.unreadNotificationCount,
    this.savedAt,
  });

  final ConsumerUserProfile? profile;
  final List<ConsumerTask> tasks;
  final List<ConsumerPropertySummary> savedProperties;
  final int unreadNotificationCount;
  final DateTime? savedAt;
}

abstract interface class ConsumerWorkspaceCacheStore {
  Future<ConsumerWorkspaceCacheSnapshot?> load();

  Future<void> save(ConsumerWorkspaceCacheSnapshot snapshot);

  Future<void> clear();
}

class LocalDatabaseConsumerWorkspaceCacheStore
    implements ConsumerWorkspaceCacheStore {
  LocalDatabaseConsumerWorkspaceCacheStore({
    ConsumerLocalCacheDatabase? database,
  }) : _database = database ?? ConsumerLocalCacheDatabase();

  final ConsumerLocalCacheDatabase _database;

  static const _payloadKey = 'consumer_workspace_snapshot';

  @override
  Future<ConsumerWorkspaceCacheSnapshot?> load() async {
    final raw = await _database.readPayload(_payloadKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      return ConsumerWorkspaceCacheSnapshot(
        profile: _readProfile(payload['profile']),
        tasks: _readTasks(payload['tasks']),
        savedProperties: _readProperties(payload['saved_properties']),
        unreadNotificationCount:
            readInt(payload['unread_notification_count']) ?? 0,
        savedAt: readDateTime(payload['saved_at']),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(ConsumerWorkspaceCacheSnapshot snapshot) {
    final payload = jsonEncode({
      'saved_at': (snapshot.savedAt ?? DateTime.now()).toIso8601String(),
      'profile': snapshot.profile == null
          ? null
          : _profileToJson(snapshot.profile!),
      'tasks': snapshot.tasks.map(_taskToJson).toList(),
      'saved_properties': snapshot.savedProperties
          .map(_propertyToJson)
          .toList(),
      'unread_notification_count': snapshot.unreadNotificationCount,
    });
    return _database.writePayload(_payloadKey, payload);
  }

  @override
  Future<void> clear() => _database.deletePayload(_payloadKey);

  ConsumerUserProfile? _readProfile(Object? value) {
    if (value is! Map) {
      return null;
    }
    return ConsumerUserProfile.fromJson(
      value.map((key, entry) => MapEntry(key.toString(), entry)),
    );
  }

  List<ConsumerTask> _readTasks(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => ConsumerTask.fromJson(
            item.map((key, entry) => MapEntry(key.toString(), entry)),
          ),
        )
        .toList(growable: false);
  }

  List<ConsumerPropertySummary> _readProperties(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => ConsumerPropertySummary.fromJson(
            item.map((key, entry) => MapEntry(key.toString(), entry)),
          ),
        )
        .toList(growable: false);
  }

  Map<String, Object?> _profileToJson(ConsumerUserProfile profile) {
    return {
      'uuid': profile.uuid,
      'email': profile.email,
      'phone_number': profile.phoneNumber,
      'first_name': profile.firstName,
      'last_name': profile.lastName,
      'profile_image_url': profile.profileImageUrl,
      'preferred_language': profile.preferredLanguage,
      'bio': profile.bio,
      'roles': profile.roles,
      'primary_role': profile.primaryRole,
      'is_active': profile.isActive,
      'email_verified': profile.emailVerified,
      'phone_verified': profile.phoneVerified,
      'is_verified': profile.isVerified,
      'kyc_verified': profile.kycVerified,
      'kyc_status': profile.kycStatus,
      'two_factor_enabled': profile.twoFactorEnabled,
    };
  }

  Map<String, Object?> _taskToJson(ConsumerTask task) {
    return {
      'code': task.code,
      'role': task.role,
      'priority': task.priority,
      'title': task.title,
      'description': task.description,
      'resource_type': task.resourceType,
      'resource_id': task.resourceId,
      'action_path': task.actionPath,
      'created_at': task.createdAt?.toIso8601String(),
    };
  }

  Map<String, Object?> _propertyToJson(ConsumerPropertySummary property) {
    return {
      'id': property.id,
      'title': property.title,
      'city': property.city,
      'region': property.region,
      'price_xaf': property.priceXaf,
      'type': property.type,
      'listing_type': property.listingType,
      'is_featured': property.isFeatured,
      'status': property.status,
      'verification_status': property.verificationStatus,
      'risk_lane': property.riskLane,
      'admission_status': property.admissionStatus,
      'cover_image_url': property.coverImageUrl,
    };
  }
}
