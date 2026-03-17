import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:real_estate_secure_backend/src/app.dart';
import 'package:real_estate_secure_backend/src/config.dart';

Future<void> main(List<String> args) async {
  final env = dotenv.DotEnv(includePlatformEnvironment: true)..load();
  final config = AppConfig.fromEnv((key) => env[key]);

  _configureLogging(config.logLevel);
  final logger = Logger('real_estate_secure_backend');

  final handler = buildHandler(config, logger);
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    config.port,
  );

  logger.info(
    'Server listening on http://${server.address.host}:${server.port} '
    'env=${config.environment}',
  );
}

void _configureLogging(Level level) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((record) {
    final message =
        '${record.time.toIso8601String()} ${record.level.name} ${record.message}';
    if (record.error != null) {
      stderr.writeln('$message error=${record.error}');
    } else {
      stdout.writeln(message);
    }
  });
}
