import 'package:logging/logging.dart';

class AppConfig {
  AppConfig({
    required this.environment,
    required this.port,
    required this.databaseUrl,
    required this.jwtSecret,
    required this.logLevel,
  });

  final String environment;
  final int port;
  final String databaseUrl;
  final String jwtSecret;
  final Level logLevel;

  bool get isProduction => environment.toLowerCase() == 'production';

  static AppConfig fromEnv(String? Function(String key) readEnv) {
    final environment = readEnv('APP_ENV') ?? 'development';
    final port = int.tryParse(readEnv('PORT') ?? '') ?? 8080;
    final databaseUrl = readEnv('DATABASE_URL') ?? '';
    final jwtSecret = readEnv('JWT_SECRET') ?? 'change-me';
    final logLevel = _parseLogLevel(readEnv('LOG_LEVEL') ?? 'info');

    return AppConfig(
      environment: environment,
      port: port,
      databaseUrl: databaseUrl,
      jwtSecret: jwtSecret,
      logLevel: logLevel,
    );
  }

  static Level _parseLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return Level.FINE;
      case 'warning':
        return Level.WARNING;
      case 'error':
        return Level.SEVERE;
      case 'critical':
        return Level.SHOUT;
      case 'info':
      default:
        return Level.INFO;
    }
  }
}
