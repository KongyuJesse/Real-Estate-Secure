import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class ConsumerDraftStore {
  Future<Map<String, dynamic>?> read(String key);

  Future<void> write(String key, Map<String, dynamic> value);

  Future<void> clear(String key);
}

class SecureConsumerDraftStore implements ConsumerDraftStore {
  SecureConsumerDraftStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (draftKey, value) => MapEntry(draftKey.toString(), value),
      );
    }
    return null;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) {
    return _storage.write(key: key, value: jsonEncode(value));
  }

  @override
  Future<void> clear(String key) {
    return _storage.delete(key: key);
  }
}
