import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/consumer_flow/consumer_models.dart';

abstract interface class ConsumerSessionStore {
  Future<ConsumerSession?> load();

  Future<void> save(ConsumerSession session);

  Future<void> clear();
}

class SecureConsumerSessionStore implements ConsumerSessionStore {
  SecureConsumerSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'consumer_session_bearer_token';
  static const _baseUrlKey = 'consumer_session_base_url';
  static const _refreshTokenKey = 'consumer_session_refresh_token';
  static const _userUuidKey = 'consumer_session_user_uuid';
  static const _emailKey = 'consumer_session_email';
  static const _fullNameKey = 'consumer_session_full_name';
  static const _preferredTabKey = 'consumer_session_preferred_tab';

  @override
  Future<ConsumerSession?> load() async {
    final values = await _storage.readAll();
    final session = ConsumerSession(
      baseUrl: values[_baseUrlKey]?.trim() ?? '',
      bearerToken: values[_tokenKey]?.trim() ?? '',
      refreshToken: values[_refreshTokenKey]?.trim() ?? '',
      userUuid: values[_userUuidKey]?.trim() ?? '',
      email: values[_emailKey]?.trim() ?? '',
      fullName: values[_fullNameKey]?.trim() ?? '',
      preferredTabIndex: int.tryParse(values[_preferredTabKey] ?? '') ?? 0,
    );
    return session.hasValues ? session : null;
  }

  @override
  Future<void> save(ConsumerSession session) async {
    await Future.wait([
      _storage.write(key: _baseUrlKey, value: session.baseUrl.trim()),
      _storage.write(key: _tokenKey, value: session.bearerToken.trim()),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken.trim()),
      _storage.write(key: _userUuidKey, value: session.userUuid.trim()),
      _storage.write(key: _emailKey, value: session.email.trim()),
      _storage.write(key: _fullNameKey, value: session.fullName.trim()),
      _storage.write(
        key: _preferredTabKey,
        value: session.preferredTabIndex.toString(),
      ),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _baseUrlKey),
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userUuidKey),
      _storage.delete(key: _emailKey),
      _storage.delete(key: _fullNameKey),
      _storage.delete(key: _preferredTabKey),
    ]);
  }
}

class MemoryConsumerSessionStore implements ConsumerSessionStore {
  MemoryConsumerSessionStore({this.initialValue}) : _value = initialValue;

  final ConsumerSession? initialValue;
  ConsumerSession? _value;

  @override
  Future<ConsumerSession?> load() async => _value ?? initialValue;

  @override
  Future<void> save(ConsumerSession session) async {
    _value = session;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}
