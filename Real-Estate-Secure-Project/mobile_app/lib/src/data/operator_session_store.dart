import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'assisted_lane_api.dart';

class PersistedOperatorSession {
  const PersistedOperatorSession({
    required this.baseUrl,
    required this.bearerToken,
    required this.transactionId,
    this.preferredDeskIndex = 0,
  });

  final String baseUrl;
  final String bearerToken;
  final String transactionId;
  final int preferredDeskIndex;

  bool get isComplete =>
      baseUrl.trim().isNotEmpty &&
      bearerToken.trim().isNotEmpty &&
      transactionId.trim().isNotEmpty;

  bool get hasValues =>
      baseUrl.trim().isNotEmpty ||
      bearerToken.trim().isNotEmpty ||
      transactionId.trim().isNotEmpty;

  ApiSession toApiSession() => ApiSession(
    baseUrl: baseUrl,
    bearerToken: bearerToken,
    transactionId: transactionId,
  );

  PersistedOperatorSession copyWith({
    String? baseUrl,
    String? bearerToken,
    String? transactionId,
    int? preferredDeskIndex,
  }) => PersistedOperatorSession(
    baseUrl: baseUrl ?? this.baseUrl,
    bearerToken: bearerToken ?? this.bearerToken,
    transactionId: transactionId ?? this.transactionId,
    preferredDeskIndex: preferredDeskIndex ?? this.preferredDeskIndex,
  );
}

abstract interface class OperatorSessionStore {
  Future<PersistedOperatorSession?> load();

  Future<void> save(PersistedOperatorSession session);

  Future<void> clear();
}

class SecureOperatorSessionStore implements OperatorSessionStore {
  SecureOperatorSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _baseUrlKey = 'operator_session_base_url';
  static const _tokenKey = 'operator_session_bearer_token';
  static const _transactionIdKey = 'operator_session_transaction_id';
  static const _preferredDeskKey = 'operator_session_preferred_desk_index';

  @override
  Future<PersistedOperatorSession?> load() async {
    final values = await _storage.readAll();
    final baseUrl = values[_baseUrlKey]?.trim() ?? '';
    final bearerToken = values[_tokenKey]?.trim() ?? '';
    final transactionId = values[_transactionIdKey]?.trim() ?? '';
    final preferredDeskIndex =
        int.tryParse(values[_preferredDeskKey] ?? '') ?? 0;

    final session = PersistedOperatorSession(
      baseUrl: baseUrl,
      bearerToken: bearerToken,
      transactionId: transactionId,
      preferredDeskIndex: preferredDeskIndex.clamp(0, 4),
    );

    return session.hasValues ? session : null;
  }

  @override
  Future<void> save(PersistedOperatorSession session) async {
    await Future.wait([
      _storage.write(key: _baseUrlKey, value: session.baseUrl.trim()),
      _storage.write(key: _tokenKey, value: session.bearerToken.trim()),
      _storage.write(
        key: _transactionIdKey,
        value: session.transactionId.trim(),
      ),
      _storage.write(
        key: _preferredDeskKey,
        value: session.preferredDeskIndex.toString(),
      ),
    ]);
  }

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _baseUrlKey),
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _transactionIdKey),
      _storage.delete(key: _preferredDeskKey),
    ]);
  }
}

class MemoryOperatorSessionStore implements OperatorSessionStore {
  MemoryOperatorSessionStore({this.initialValue}) : _memoryValue = initialValue;

  final PersistedOperatorSession? initialValue;
  PersistedOperatorSession? _memoryValue;

  @override
  Future<PersistedOperatorSession?> load() async =>
      _memoryValue ?? initialValue;

  @override
  Future<void> save(PersistedOperatorSession session) async {
    _memoryValue = session;
  }

  @override
  Future<void> clear() async {
    _memoryValue = null;
  }
}
