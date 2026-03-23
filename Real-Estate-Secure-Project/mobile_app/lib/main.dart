import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'src/app.dart';
import 'src/data/consumer_runtime_config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  const runtimeConfigService = PlatformConsumerRuntimeConfigService();
  final defaultConsumerApiBaseUrl = await runtimeConfigService
      .getDefaultApiBaseUrl();
  runApp(
    RealEstateSecureApp(defaultConsumerApiBaseUrl: defaultConsumerApiBaseUrl),
  );
}
