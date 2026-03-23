import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate_secure/src/app.dart';
import 'package:real_estate_secure/src/data/consumer_api.dart';
import 'package:real_estate_secure/src/data/consumer_device_identity.dart';
import 'package:real_estate_secure/src/data/consumer_session_store.dart';
import 'package:real_estate_secure/src/features/consumer_flow/consumer_models.dart';

void main() {
  testWidgets('consumer flow opens from splash into welcome actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      RealEstateSecureApp(
        consumerSessionStore: MemoryConsumerSessionStore(),
        consumerApiClient: _FakeConsumerApiClient(),
      ),
    );
    expect(find.text('Real Estate'), findsOneWidget);
    expect(find.text('AUTHENTICATING'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Secure Property'), findsOneWidget);
    expect(find.text('Register Account'), findsOneWidget);
    expect(find.text('Login to Dashboard'), findsOneWidget);
    expect(find.text('Explore Properties as Guest'), findsOneWidget);
  });
}

class _FakeConsumerApiClient extends ConsumerApiClient {
  _FakeConsumerApiClient()
    : super(deviceIdentityProvider: const _FakeDeviceIdentityProvider());

  @override
  Future<List<ConsumerPropertySummary>> listProperties({
    required String baseUrl,
    bool featuredOnly = false,
    int limit = 8,
    int page = 1,
    String? query,
  }) async {
    final source = featuredOnly ? _featuredProperties : _allProperties;
    return source.take(limit).toList(growable: false);
  }

  @override
  Future<List<ConsumerPropertyMapPoint>> listMapPoints({
    required String baseUrl,
    int limit = 24,
    int page = 1,
  }) async {
    return _mapPoints.take(limit).toList(growable: false);
  }
}

class _FakeDeviceIdentityProvider implements ConsumerDeviceIdentityProvider {
  const _FakeDeviceIdentityProvider();

  @override
  Future<ConsumerDeviceIdentity> load() async => const ConsumerDeviceIdentity(
    deviceId: 'test-device-id',
    deviceName: 'widget-test',
    platform: 'test',
    appVersion: '1.0.0-test',
  );
}

const _featuredProperties = <ConsumerPropertySummary>[
  ConsumerPropertySummary(
    id: 'test-featured-villa',
    title: 'Modern Luxury Villa with Infinity Pool',
    city: 'Douala',
    region: 'Littoral',
    priceXaf: 25000000,
    type: 'house',
    listingType: 'sale',
    isFeatured: true,
    verificationStatus: 'verified',
    riskLane: 'ordinary_marketplace',
    admissionStatus: 'accepted',
  ),
  ConsumerPropertySummary(
    id: 'test-featured-land',
    title: 'Verified Residential Land Near Bastos',
    city: 'Yaounde',
    region: 'Centre',
    priceXaf: 14000000,
    type: 'land',
    listingType: 'sale',
    isFeatured: true,
    verificationStatus: 'verified',
    riskLane: 'ordinary_marketplace',
    admissionStatus: 'accepted',
  ),
];

const _allProperties = <ConsumerPropertySummary>[
  ..._featuredProperties,
  ConsumerPropertySummary(
    id: 'test-rental-apartment',
    title: 'Oceanfront Executive Apartment',
    city: 'Kribi',
    region: 'South',
    priceXaf: 1850000,
    type: 'apartment',
    listingType: 'rent',
    isFeatured: false,
    verificationStatus: 'verified',
    riskLane: 'ordinary_marketplace',
    admissionStatus: 'accepted',
  ),
];

const _mapPoints = <ConsumerPropertyMapPoint>[
  ConsumerPropertyMapPoint(
    id: 'test-featured-villa',
    title: 'Modern Luxury Villa with Infinity Pool',
    price: 25000000,
    currency: 'XAF',
    latitude: 4.0483,
    longitude: 9.7043,
    city: 'Douala',
    region: 'Littoral',
  ),
  ConsumerPropertyMapPoint(
    id: 'test-featured-land',
    title: 'Verified Residential Land Near Bastos',
    price: 14000000,
    currency: 'XAF',
    latitude: 3.8710,
    longitude: 11.5174,
    city: 'Yaounde',
    region: 'Centre',
  ),
];
