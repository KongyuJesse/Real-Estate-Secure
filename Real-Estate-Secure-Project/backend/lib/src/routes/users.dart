import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/http.dart';
import '../core/pagination.dart';
import '../core/request.dart';
import '../middleware/request_context.dart';
import '../models/user_profile.dart';

const List<UserProfile> _sampleUsers = [
  UserProfile(
    id: 'user-001',
    uuid: 'b7b5cbea-2f1c-4d3c-8d1a-6cfa0f6f1c01',
    email: 'amina.essomba@example.com',
    firstName: 'Amina',
    lastName: 'Essomba',
    roles: [UserRole.buyer],
    isVerified: true,
  ),
  UserProfile(
    id: 'user-002',
    uuid: 'd1143d5c-6c16-4b24-9bcb-7f128f8d5e02',
    email: 'patrick.ndi@example.com',
    firstName: 'Patrick',
    lastName: 'Ndi',
    roles: [UserRole.seller, UserRole.agent],
    isVerified: true,
  ),
];

Router buildUsersRouter() {
  final router = Router();

  router.get('/profile', (Request request) {
    return okResponse(
      _sampleUsers.first.toJson(),
      requestId: request.requestId,
    );
  });

  router.put('/profile', (Request request) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) {
        final updated = _sampleUsers.first.copyWith(
          firstName: readString(payload, 'first_name'),
          lastName: readString(payload, 'last_name'),
        );
        return okResponse(updated.toJson(), requestId: request.requestId);
      },
      onFailure: (error) => errorResponse(
        error.message,
        statusCode: 400,
        requestId: request.requestId,
        code: 'INVALID_REQUEST',
      ),
    );
  });

  router.get('/<id>', (Request request, String id) {
    final match = _sampleUsers.where((user) => user.id == id);
    if (match.isEmpty) {
      return errorResponse(
        'User not found.',
        statusCode: 404,
        requestId: request.requestId,
        code: 'NOT_FOUND',
      );
    }
    return okResponse(match.first.toJson(), requestId: request.requestId);
  });

  router.get('/<id>/listings', (Request request, String id) {
    final listings = [
      {
        'id': 'prop-001',
        'title': 'Bonapriso Villa',
        'status': 'active',
      },
      {
        'id': 'prop-003',
        'title': 'Logpom Land Plot',
        'status': 'pending',
      },
    ];
    return okResponse(
      listings,
      requestId: request.requestId,
      meta: {'count': listings.length},
    );
  });

  router.get('/<id>/transactions', (Request request, String id) {
    final transactions = [
      {
        'id': 'trx-1001',
        'status': 'pending_deposit',
        'amount_xaf': 120000000,
      },
      {
        'id': 'trx-1002',
        'status': 'completed',
        'amount_xaf': 45000000,
      },
    ];
    return okResponse(
      transactions,
      requestId: request.requestId,
      meta: {'count': transactions.length},
    );
  });

  router.get('/<id>/reviews', (Request request, String id) {
    final reviews = [
      {
        'id': 'rev-01',
        'rating': 5,
        'comment': 'Smooth transaction and great communication.',
      },
    ];
    return okResponse(reviews, requestId: request.requestId);
  });

  router.post('/kyc/upload', (Request request) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (_) => messageResponse(
        'kyc submitted',
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

  router.get('/kyc/status', (Request request) {
    return okResponse(
      {'status': 'verified'},
      requestId: request.requestId,
    );
  });

  router.put('/preferences', (Request request) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'updated_preferences': payload.keys.toList(),
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

  router.delete('/account', (Request request) {
    return messageResponse('account deleted', requestId: request.requestId);
  });

  router.get('/', (Request request) {
    final pageRequest = PageRequest.fromQuery(request.url.queryParameters);
    final start = pageRequest.offset;
    var end = start + pageRequest.limit;
    if (end > _sampleUsers.length) {
      end = _sampleUsers.length;
    }
    final pageItems = start >= _sampleUsers.length
        ? <UserProfile>[]
        : _sampleUsers.sublist(start, end);

    return okResponse(
      pageItems.map((user) => user.toJson()).toList(),
      requestId: request.requestId,
      meta: {
        'count': pageItems.length,
        'page': pageRequest.page,
        'limit': pageRequest.limit,
        'total_items': _sampleUsers.length,
      },
    );
  });

  return router;
}
