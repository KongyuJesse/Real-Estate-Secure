import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/http.dart';
import '../core/pagination.dart';
import '../core/request.dart';
import '../middleware/request_context.dart';
import '../models/conversation.dart';

final List<ConversationSummary> _sampleConversations = [
  ConversationSummary(
    id: 'conv-001',
    title: 'Bonapriso Villa inquiry',
    lastMessage: 'Can we schedule a visit tomorrow?',
    participants: 2,
    updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
];

final List<MessageSummary> _sampleMessages = [
  MessageSummary(
    id: 'msg-001',
    conversationId: 'conv-001',
    senderId: 'user-001',
    content: 'Can we schedule a visit tomorrow?',
    type: MessageType.text,
    sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  MessageSummary(
    id: 'msg-002',
    conversationId: 'conv-001',
    senderId: 'user-002',
    content: 'Yes, 10am works well.',
    type: MessageType.text,
    sentAt: DateTime.now().subtract(const Duration(minutes: 20)),
  ),
];

Router buildMessagingRouter() {
  final router = Router();

  router.get('/conversations', (Request request) {
    final pageRequest = PageRequest.fromQuery(request.url.queryParameters);
    final start = pageRequest.offset;
    var end = start + pageRequest.limit;
    if (end > _sampleConversations.length) {
      end = _sampleConversations.length;
    }
    final pageItems = start >= _sampleConversations.length
        ? <ConversationSummary>[]
        : _sampleConversations.sublist(start, end);

    return okResponse(
      pageItems.map((conversation) => conversation.toJson()).toList(),
      requestId: request.requestId,
      meta: {
        'count': pageItems.length,
        'page': pageRequest.page,
        'limit': pageRequest.limit,
        'total_items': _sampleConversations.length,
      },
    );
  });

  router.post('/conversations', (Request request) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'id': 'conv-new',
          'title': readString(payload, 'title') ?? 'New conversation',
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

  router.get('/conversations/<id>/messages', (Request request, String id) {
    final messages =
        _sampleMessages.where((message) => message.conversationId == id).toList();
    return okResponse(
      messages.map((message) => message.toJson()).toList(),
      requestId: request.requestId,
    );
  });

  router.post('/conversations/<id>/messages', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'id': 'msg-new',
          'conversation_id': id,
          'content': readString(payload, 'content'),
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

  router.put('/messages/<id>', (Request request, String id) async {
    final payloadResult = await readJsonMap(request);
    return payloadResult.fold(
      onSuccess: (payload) => okResponse(
        {
          'id': id,
          'content': readString(payload, 'content'),
          'edited': true,
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

  router.delete('/messages/<id>', (Request request, String id) {
    return messageResponse('message deleted', requestId: request.requestId);
  });

  router.post('/conversations/<id>/read', (Request request, String id) {
    return okResponse(
      {
        'conversation_id': id,
        'status': 'read',
      },
      requestId: request.requestId,
    );
  });

  router.post('/conversations/<id>/archive', (Request request, String id) {
    return okResponse(
      {
        'conversation_id': id,
        'status': 'archived',
      },
      requestId: request.requestId,
    );
  });

  return router;
}
