import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/consumer_flow/consumer_models.dart';
import 'consumer_local_cache_database.dart';

class ConsumerCatalogCacheSnapshot {
  const ConsumerCatalogCacheSnapshot({
    required this.featuredProperties,
    required this.listings,
    required this.mapPoints,
    this.savedAt,
  });

  final List<ConsumerPropertySummary> featuredProperties;
  final List<ConsumerPropertySummary> listings;
  final List<ConsumerPropertyMapPoint> mapPoints;
  final DateTime? savedAt;
}

abstract interface class ConsumerCatalogCacheStore {
  Future<ConsumerCatalogCacheSnapshot?> load();

  Future<void> save(ConsumerCatalogCacheSnapshot snapshot);

  Future<void> clear();
}

class LocalDatabaseConsumerCatalogCacheStore
    implements ConsumerCatalogCacheStore {
  LocalDatabaseConsumerCatalogCacheStore({
    ConsumerLocalCacheDatabase? database,
    FlutterSecureStorage? legacyStorage,
  }) : _database = database ?? ConsumerLocalCacheDatabase(),
       _legacyStorage = legacyStorage ?? const FlutterSecureStorage();

  final ConsumerLocalCacheDatabase _database;
  final FlutterSecureStorage _legacyStorage;

  static const _payloadKey = 'consumer_catalog_snapshot';

  @override
  Future<ConsumerCatalogCacheSnapshot?> load() async {
    final raw =
        await _database.readPayload(_payloadKey) ??
        await _migrateLegacyPayload();
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

      return ConsumerCatalogCacheSnapshot(
        featuredProperties: _readProperties(payload['featured']),
        listings: _readProperties(payload['listings']),
        mapPoints: _readMapPoints(payload['map_points']),
        savedAt: readDateTime(payload['saved_at']),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(ConsumerCatalogCacheSnapshot snapshot) async {
    final payload = jsonEncode({
      'saved_at': (snapshot.savedAt ?? DateTime.now()).toIso8601String(),
      'featured': snapshot.featuredProperties.map(_propertyToJson).toList(),
      'listings': snapshot.listings.map(_propertyToJson).toList(),
      'map_points': snapshot.mapPoints.map(_mapPointToJson).toList(),
    });
    await _database.writePayload(_payloadKey, payload);
    await _legacyStorage.delete(key: _payloadKey);
  }

  @override
  Future<void> clear() async {
    await _database.deletePayload(_payloadKey);
    await _legacyStorage.delete(key: _payloadKey);
  }

  Future<String?> _migrateLegacyPayload() async {
    final raw = await _legacyStorage.read(key: _payloadKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    await _database.writePayload(_payloadKey, raw);
    await _legacyStorage.delete(key: _payloadKey);
    return raw;
  }

  List<ConsumerPropertySummary> _readProperties(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => ConsumerPropertySummary.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  List<ConsumerPropertyMapPoint> _readMapPoints(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => ConsumerPropertyMapPoint.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
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

  Map<String, Object?> _mapPointToJson(ConsumerPropertyMapPoint point) {
    return {
      'id': point.id,
      'title': point.title,
      'price': point.price,
      'currency': point.currency,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'city': point.city,
      'region': point.region,
    };
  }
}

class SecureConsumerCatalogCacheStore
    extends LocalDatabaseConsumerCatalogCacheStore {
  SecureConsumerCatalogCacheStore({super.database, super.legacyStorage});
}
