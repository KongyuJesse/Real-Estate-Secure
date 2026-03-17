import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/http.dart';
import '../core/pagination.dart';
import '../core/request.dart';
import '../middleware/request_context.dart';
import '../models/transaction_summary.dart';

final List<TransactionSummary> _sampleTransactions = [
  TransactionSummary(
    id: 'trx-1001',
    propertyId: 'prop-001',
    buyerId: 'user-001',
    sellerId: 'user-002',
    amountXaf: 120000000,
    status: TransactionStatus.pendingDeposit,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  TransactionSummary(
    id: 'trx-1002',
    propertyId: 'prop-002',
    buyerId: 'user-003',
    sellerId: 'user-004',
    amountXaf: 45000000,
    status: TransactionStatus.completed,
    createdAt: DateTime.now().subtract(const Duration(days: 40)),
  ),
];

Router buildTransactionsRouter() {
  final router = Router();

  router.get('/', (Request request) {
    final pageRequest = PageRequest.fromQuery(request.url.queryParameters);
    final start = pageRequest.offset;
    var end = start + pageRequest.limit;
    if (end > _sampleTransactions.length) {
      end = _sampleTransactions.length;
    }
    final pageItems = start >= _sampleTransactions.length
        ? <TransactionSummary>[]
        : _sampleTransactions.sublist(start, end);

    return okResponse(
      pageItems.map((transaction) => transaction.toJson()).toList(),
      requestId: request.requestId,
      meta: {
        'count': pageItems.length,
        'page': pageRequest.page,
        'limit': pageRequest.limit,
        'total_items': _sampleTransactions.length,
      },
    );
  });

  router.get('/<id>', (Request request, String id) {
    final match = _sampleTransactions.where((transaction) => transaction.id == id);
    if (match.isEmpty) {
      return errorResponse(
        'Transaction not found.',
        statusCode: 404,
        requestId: request.requestId,
        code: 'NOT_FOUND',
      );
    }
    return okResponse(match.first.toJson(), requestId: request.requestId);
  });

  router.post('/initiate', (Request request) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'transaction_id': 'trx-new',
          'property_id': readString(payload, 'property_id'),
          'status': TransactionStatus.initiated.apiValue,
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

  router.post('/<id>/deposit', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (_) => okResponse(
        {
          'transaction_id': id,
          'status': TransactionStatus.deposited.apiValue,
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

  router.post('/<id>/lawyer', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'transaction_id': id,
          'lawyer_id': readString(payload, 'lawyer_id'),
          'status': TransactionStatus.documentsPending.apiValue,
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

  router.post('/<id>/inspect', (Request request, String id) {
    return okResponse(
      {
        'transaction_id': id,
        'status': TransactionStatus.inspectionPeriod.apiValue,
      },
      requestId: request.requestId,
    );
  });

  router.post('/<id>/approve', (Request request, String id) {
    return okResponse(
      {
        'transaction_id': id,
        'status': TransactionStatus.lawyerApproval.apiValue,
      },
      requestId: request.requestId,
    );
  });

  router.post('/<id>/release', (Request request, String id) {
    return okResponse(
      {
        'transaction_id': id,
        'status': TransactionStatus.completed.apiValue,
      },
      requestId: request.requestId,
    );
  });

  router.post('/<id>/dispute', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'transaction_id': id,
          'status': TransactionStatus.disputed.apiValue,
          'reason': readString(payload, 'reason') ?? 'unspecified',
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

  router.post('/<id>/cancel', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'transaction_id': id,
          'status': TransactionStatus.cancelled.apiValue,
          'reason': readString(payload, 'reason') ?? 'user_request',
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

  router.get('/<id>/timeline', (Request request, String id) {
    return okResponse(
      [
        {'status': 'initiated', 'timestamp': DateTime.now().toIso8601String()},
        {'status': 'pending_deposit', 'timestamp': DateTime.now().toIso8601String()},
      ],
      requestId: request.requestId,
    );
  });

  return router;
}
