import 'package:postgres/postgres.dart';

class Database {
  Database(this._connection);

  final Connection _connection;

  static Future<Database> connect(String databaseUrl) async {
    final endpoint = _parseEndpoint(databaseUrl);
    final connection = await Connection.open(
      endpoint,
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    return Database(connection);
  }

  Future<T> withConnection<T>(Future<T> Function(Connection connection) run) =>
      run(_connection);

  Future<void> close() => _connection.close();
}

Endpoint _parseEndpoint(String databaseUrl) {
  final uri = Uri.parse(databaseUrl);
  final userInfo = uri.userInfo.split(':');
  final username = userInfo.isNotEmpty ? userInfo.first : null;
  final password = userInfo.length > 1 ? userInfo[1] : null;
  final database =
      uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'postgres';

  return Endpoint(
    host: uri.host.isEmpty ? 'localhost' : uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: database,
    username: username?.isEmpty == true ? null : username,
    password: password?.isEmpty == true ? null : password,
  );
}
