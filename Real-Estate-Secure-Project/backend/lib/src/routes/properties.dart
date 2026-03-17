import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/http.dart';
import '../core/pagination.dart';
import '../core/request.dart';
import '../models/property_summary.dart';
import '../models/property_location.dart';
import '../middleware/request_context.dart';

const List<PropertySummary> _sampleProperties = [
  PropertySummary(
    id: 'prop-001',
    title: 'Bonapriso Villa',
    city: 'Douala',
    region: 'Littoral',
    priceXaf: 120000000,
    type: PropertyType.house,
    listingType: ListingType.sale,
    isFeatured: true,
  ),
  PropertySummary(
    id: 'prop-002',
    title: 'Bastos Apartment',
    city: 'Yaounde',
    region: 'Centre',
    priceXaf: 45000000,
    type: PropertyType.apartment,
    listingType: ListingType.rent,
  ),
  PropertySummary(
    id: 'prop-003',
    title: 'Logpom Land Plot',
    city: 'Douala',
    region: 'Littoral',
    priceXaf: 25000000,
    type: PropertyType.land,
    listingType: ListingType.sale,
  ),
];

const List<PropertyLocation> _sampleLocations = [
  PropertyLocation(
    id: 'loc-001',
    propertyId: 'prop-001',
    city: 'Douala',
    region: 'Littoral',
    latitude: 4.0511,
    longitude: 9.7679,
    isPublic: true,
  ),
  PropertyLocation(
    id: 'loc-002',
    propertyId: 'prop-002',
    city: 'Yaounde',
    region: 'Centre',
    latitude: 3.848,
    longitude: 11.5021,
    isPublic: true,
  ),
  PropertyLocation(
    id: 'loc-003',
    propertyId: 'prop-003',
    city: 'Douala',
    region: 'Littoral',
    latitude: 4.0876,
    longitude: 9.7064,
    isPublic: false,
  ),
];

Router buildPropertiesRouter() {
  final router = Router();

  router.get('/', (Request request) {
    final query = request.url.queryParameters;
    final featuredOnly = query['featured'] == 'true';
    final region = query['region'];
    final city = query['city'];

    final filtered = _sampleProperties
        .where((property) => !featuredOnly || property.isFeatured)
        .where((property) => region == null || property.region == region)
        .where((property) => city == null || property.city == city)
        .toList();

    final pageRequest = PageRequest.fromQuery(query);
    final start = pageRequest.offset;
    var end = start + pageRequest.limit;
    if (end > filtered.length) {
      end = filtered.length;
    }
    final pageItems = start >= filtered.length
        ? <PropertySummary>[]
        : filtered.sublist(start, end);

    final total = pageItems.fold<double>(0, (acc, item) => acc + item.priceXaf);
    final averagePrice = pageItems.isEmpty ? 0 : total / pageItems.length;

    return okResponse(
      pageItems.map((property) => property.toJson()).toList(),
      requestId: request.requestId,
      meta: {
        'count': pageItems.length,
        'average_price_xaf': averagePrice,
        'page': pageRequest.page,
        'limit': pageRequest.limit,
        'total_items': filtered.length,
      },
    );
  });

  router.get('/search', (Request request) {
    final term = request.url.queryParameters['q']?.toLowerCase().trim() ?? '';
    final results = _sampleProperties
        .where((property) => term.isEmpty || property.title.toLowerCase().contains(term))
        .toList();

    return okResponse(
      results.map((property) => property.toJson()).toList(),
      requestId: request.requestId,
      meta: {'count': results.length},
    );
  });

  router.get('/map', (Request request) {
    final publicLocations =
        _sampleLocations.where((location) => location.isPublic).toList();
    return okResponse(
      publicLocations.map((location) => location.toJson()).toList(),
      requestId: request.requestId,
    );
  });

  router.get('/<id>', (Request request, String id) {
    final match = _sampleProperties.where((property) => property.id == id);
    if (match.isEmpty) {
      return errorResponse(
        'Property not found.',
        statusCode: 404,
        requestId: request.requestId,
        code: 'NOT_FOUND',
      );
    }
    return okResponse(match.first.toJson(), requestId: request.requestId);
  });

  router.post('/', (Request request) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) {
        final title = readString(payload, 'title') ?? 'New listing';
        final city = readString(payload, 'city') ?? 'Douala';
        final region = readString(payload, 'region') ?? 'Littoral';
        final price = readDouble(payload, 'price_xaf') ?? 0;

        return okResponse(
          {
            'id': 'prop-new',
            'title': title,
            'city': city,
            'region': region,
            'price_xaf': price,
            'status': 'draft',
          },
          statusCode: 201,
          requestId: request.requestId,
        );
      },
      onFailure: (error) => errorResponse(
        error.message,
        statusCode: 400,
        requestId: request.requestId,
        code: 'INVALID_REQUEST',
      ),
    );
  });

  router.put('/<id>', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) {
        return okResponse(
          {
            'id': id,
            'updated_fields': payload.keys.toList(),
          },
          requestId: request.requestId,
        );
      },
      onFailure: (error) => errorResponse(
        error.message,
        statusCode: 400,
        requestId: request.requestId,
        code: 'INVALID_REQUEST',
      ),
    );
  });

  router.delete('/<id>', (Request request, String id) {
    return messageResponse('property deleted', requestId: request.requestId);
  });

  router.post('/<id>/images', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (_) => okResponse(
        {
          'property_id': id,
          'upload_status': 'queued',
        },
        statusCode: 202,
        requestId: request.requestId,
      ),
      onFailure: (error) => errorResponse(
        error.message,
        statusCode: 400,
        requestId: request.requestId,
        code: 'INVALID_REQUEST',
      ),
    );
  });

  router.delete('/<id>/images/<imageId>', (Request request, String id, String imageId) {
    return messageResponse(
      'image removed',
      requestId: request.requestId,
      meta: {'property_id': id, 'image_id': imageId},
    );
  });

  router.post('/<id>/documents', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (_) => okResponse(
        {
          'property_id': id,
          'document_status': 'received',
        },
        statusCode: 201,
        requestId: request.requestId,
      ),
      onFailure: (error) => errorResponse(
        error.message,
        statusCode: 400,
        requestId: request.requestId,
        code: 'INVALID_REQUEST',
      ),
    );
  });

  router.get('/<id>/documents', (Request request, String id) {
    return okResponse(
      [
        {
          'id': 'doc-001',
          'property_id': id,
          'type': 'land_title',
          'status': 'verified',
        },
        {
          'id': 'doc-002',
          'property_id': id,
          'type': 'survey_plan',
          'status': 'pending',
        },
      ],
      requestId: request.requestId,
    );
  });

  router.post('/<id>/verify', (Request request, String id) {
    return okResponse(
      {
        'property_id': id,
        'verification_status': 'pending',
      },
      requestId: request.requestId,
    );
  });

  router.get('/<id>/status', (Request request, String id) {
    return okResponse(
      {
        'property_id': id,
        'status': 'active',
        'verification_status': 'verified',
      },
      requestId: request.requestId,
    );
  });

  router.post('/<id>/favorite', (Request request, String id) {
    return messageResponse(
      'added to favorites',
      requestId: request.requestId,
      meta: {'property_id': id},
    );
  });

  router.delete('/<id>/favorite', (Request request, String id) {
    return messageResponse(
      'removed from favorites',
      requestId: request.requestId,
      meta: {'property_id': id},
    );
  });

  router.post('/<id>/report', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) {
        return okResponse(
          {
            'property_id': id,
            'reason': readString(payload, 'reason') ?? 'unspecified',
            'status': 'received',
          },
          statusCode: 202,
          requestId: request.requestId,
        );
      },
      onFailure: (error) => errorResponse(
        error.message,
        statusCode: 400,
        requestId: request.requestId,
        code: 'INVALID_REQUEST',
      ),
    );
  });

  return router;
}
