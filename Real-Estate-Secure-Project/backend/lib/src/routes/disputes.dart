import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/http.dart';
import '../core/pagination.dart';
import '../core/request.dart';
import '../middleware/request_context.dart';
import '../models/dispute_summary.dart';

final List<DisputeSummary> _sampleDisputes = [
  DisputeSummary(
    id: 'disp-001',
    transactionId: 'trx-1001',
    raisedById: 'user-001',
    status: DisputeStatus.open,
    reason: 'Document verification mismatch',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

Router buildDisputesRouter() {
  final router = Router();

  router.get('/', (Request request) {
    final pageRequest = PageRequest.fromQuery(request.url.queryParameters);
    final start = pageRequest.offset;
    var end = start + pageRequest.limit;
    if (end > _sampleDisputes.length) {
      end = _sampleDisputes.length;
    }
    final pageItems = start >= _sampleDisputes.length
        ? <DisputeSummary>[]
        : _sampleDisputes.sublist(start, end);

    return okResponse(
      pageItems.map((dispute) => dispute.toJson()).toList(),
      requestId: request.requestId,
      meta: {
        'count': pageItems.length,
        'page': pageRequest.page,
        'limit': pageRequest.limit,
        'total_items': _sampleDisputes.length,
      },
    );
  });

  router.get('/<id>', (Request request, String id) {
    final match = _sampleDisputes.where((dispute) => dispute.id == id);
    if (match.isEmpty) {
      return errorResponse(
        'Dispute not found.',
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
      onSuccess: (payload) => okResponse(
        {
          'id': 'disp-new',
          'transaction_id': readString(payload, 'transaction_id'),
          'status': DisputeStatus.open.name,
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

  router.post('/<id>/messages', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'dispute_id': id,
          'message': readString(payload, 'message'),
          'status': 'posted',
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

  router.get('/<id>/messages', (Request request, String id) {
    return okResponse(
      [
        {
          'id': 'disp-msg-01',
          'dispute_id': id,
          'message': 'We need additional documentation.',
        },
      ],
      requestId: request.requestId,
    );
  });

  return router;
}
