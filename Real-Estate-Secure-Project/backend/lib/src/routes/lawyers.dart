import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/http.dart';
import '../core/pagination.dart';
import '../core/request.dart';
import '../middleware/request_context.dart';
import '../models/user_profile.dart';

const List<LawyerProfile> _sampleLawyers = [
  LawyerProfile(
    id: 'law-001',
    uuid: '9f4a3e93-5c7f-4f6e-8c8d-1d13c0c1a201',
    email: 'ngoa.law@example.com',
    firstName: 'Ngoa',
    lastName: 'Kamdem',
    roles: [UserRole.lawyer],
    barNumber: 'BAR-CM-1023',
    specializations: ['land', 'property', 'commercial'],
    averageRating: 4.8,
  ),
  LawyerProfile(
    id: 'law-002',
    uuid: '37d1a5b2-8a18-4c1e-9f1c-22c4a8e9d202',
    email: 'biko.legal@example.com',
    firstName: 'Biko',
    lastName: 'Talla',
    roles: [UserRole.lawyer],
    barNumber: 'BAR-CM-1177',
    specializations: ['litigation', 'property'],
    averageRating: 4.5,
  ),
];

Router buildLawyersRouter() {
  final router = Router();

  router.get('/', (Request request) {
    final pageRequest = PageRequest.fromQuery(request.url.queryParameters);
    final start = pageRequest.offset;
    var end = start + pageRequest.limit;
    if (end > _sampleLawyers.length) {
      end = _sampleLawyers.length;
    }
    final pageItems = start >= _sampleLawyers.length
        ? <LawyerProfile>[]
        : _sampleLawyers.sublist(start, end);

    return okResponse(
      pageItems.map((lawyer) => lawyer.toJson()).toList(),
      requestId: request.requestId,
      meta: {
        'count': pageItems.length,
        'page': pageRequest.page,
        'limit': pageRequest.limit,
        'total_items': _sampleLawyers.length,
      },
    );
  });

  router.get('/<id>', (Request request, String id) {
    final match = _sampleLawyers.where((lawyer) => lawyer.id == id);
    if (match.isEmpty) {
      return errorResponse(
        'Lawyer not found.',
        statusCode: 404,
        requestId: request.requestId,
        code: 'NOT_FOUND',
      );
    }
    return okResponse(match.first.toJson(), requestId: request.requestId);
  });

  router.get('/<id>/reviews', (Request request, String id) {
    final reviews = [
      {
        'id': 'rev-201',
        'rating': 5,
        'comment': 'Clear legal guidance and fast turnaround.',
      },
    ];
    return okResponse(reviews, requestId: request.requestId);
  });

  router.post('/<id>/hire', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'lawyer_id': id,
          'transaction_id': readString(payload, 'transaction_id'),
          'status': 'assigned',
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

  router.get('/pending', (Request request) {
    return okResponse(
      [
        {
          'document_id': 'doc-201',
          'property_id': 'prop-003',
          'type': 'land_title',
        },
      ],
      requestId: request.requestId,
    );
  });

  router.post('/verify/<documentId>', (Request request, String documentId) {
    return okResponse(
      {
        'document_id': documentId,
        'status': 'verified',
      },
      requestId: request.requestId,
    );
  });

  router.post('/reject/<documentId>', (Request request, String documentId) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'document_id': documentId,
          'status': 'rejected',
          'reason': readString(payload, 'reason') ?? 'unspecified',
        },
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

  router.post('/review/<transactionId>', (Request request, String transactionId) {
    return okResponse(
      {
        'transaction_id': transactionId,
        'status': 'legal_review_submitted',
      },
      requestId: request.requestId,
    );
  });

  return router;
}
