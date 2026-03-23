import 'dart:convert';
import 'dart:io';

typedef JsonMap = Map<String, dynamic>;

class ApiSession {
  const ApiSession({
    required this.baseUrl,
    required this.bearerToken,
    required this.transactionId,
  });

  final String baseUrl;
  final String bearerToken;
  final String transactionId;

  String get normalizedBaseUrl => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
}

class ApiFailure implements Exception {
  const ApiFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkspaceData {
  const WorkspaceData({
    required this.compliance,
    required this.offlineSteps,
    required this.legalCases,
  });

  final JsonMap compliance;
  final List<OfflineStepRecord> offlineSteps;
  final List<LegalCaseRecord> legalCases;
}

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.category,
    required this.status,
    required this.createdAt,
    this.notificationType,
    this.actionUrl,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String body;
  final String severity;
  final String category;
  final String status;
  final DateTime? createdAt;
  final String? notificationType;
  final String? actionUrl;
  final String? actionLabel;

  factory NotificationRecord.fromJson(JsonMap json) => NotificationRecord(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Notification',
    body: json['body']?.toString() ?? '',
    severity: json['severity']?.toString() ?? 'info',
    category: json['category']?.toString() ?? 'activity',
    status: json['status']?.toString() ?? 'unread',
    createdAt: _readDateTime(json['created_at']),
    notificationType: json['notification_type']?.toString(),
    actionUrl: json['action_url']?.toString(),
    actionLabel: json['action_label']?.toString(),
  );
}

class OfflineStepRecord {
  const OfflineStepRecord({
    required this.id,
    required this.stepType,
    required this.physicalStatus,
    required this.expectedOffice,
    required this.assignedRole,
    required this.notes,
    required this.delayReason,
    required this.originalRequired,
    required this.oversightRequired,
    required this.filingDate,
    required this.scheduledAt,
    required this.nextFollowUpDate,
    required this.completedAt,
  });

  final String id;
  final String stepType;
  final String physicalStatus;
  final String? expectedOffice;
  final String? assignedRole;
  final String? notes;
  final String? delayReason;
  final bool originalRequired;
  final bool oversightRequired;
  final DateTime? filingDate;
  final DateTime? scheduledAt;
  final DateTime? nextFollowUpDate;
  final DateTime? completedAt;

  factory OfflineStepRecord.fromJson(JsonMap json) => OfflineStepRecord(
    id: json['id']?.toString() ?? '',
    stepType: json['step_type']?.toString() ?? 'unknown',
    physicalStatus: json['physical_status']?.toString() ?? 'in_review',
    expectedOffice: json['expected_office']?.toString(),
    assignedRole: json['assigned_role']?.toString(),
    notes: json['notes']?.toString(),
    delayReason: json['delay_reason']?.toString(),
    originalRequired: json['original_required'] == true,
    oversightRequired: json['oversight_required'] == true,
    filingDate: _readDateTime(json['filing_date']),
    scheduledAt: _readDateTime(json['scheduled_at']),
    nextFollowUpDate: _readDateTime(json['next_follow_up_date']),
    completedAt: _readDateTime(json['completed_at']),
  );
}

class LegalCaseRecord {
  const LegalCaseRecord({
    required this.id,
    required this.caseType,
    required this.status,
    required this.freezesAutomation,
    required this.requiresAdminOversight,
    required this.expectedOffice,
    required this.referenceNumber,
    required this.courtName,
    required this.notes,
    required this.delayReason,
    required this.filingDate,
    required this.nextFollowUpDate,
    required this.finalDecisionDate,
  });

  final String id;
  final String caseType;
  final String status;
  final bool freezesAutomation;
  final bool requiresAdminOversight;
  final String? expectedOffice;
  final String? referenceNumber;
  final String? courtName;
  final String? notes;
  final String? delayReason;
  final DateTime? filingDate;
  final DateTime? nextFollowUpDate;
  final DateTime? finalDecisionDate;

  factory LegalCaseRecord.fromJson(JsonMap json) => LegalCaseRecord(
    id: json['id']?.toString() ?? '',
    caseType: json['case_type']?.toString() ?? 'unknown',
    status: json['status']?.toString() ?? 'pending_filing',
    freezesAutomation: json['freezes_automation'] == true,
    requiresAdminOversight: json['requires_admin_oversight'] == true,
    expectedOffice: json['expected_office']?.toString(),
    referenceNumber: json['reference_number']?.toString(),
    courtName: json['court_name']?.toString(),
    notes: json['notes']?.toString(),
    delayReason: json['delay_reason']?.toString(),
    filingDate: _readDateTime(json['filing_date']),
    nextFollowUpDate: _readDateTime(json['next_follow_up_date']),
    finalDecisionDate: _readDateTime(json['final_decision_date']),
  );
}

class AssistedLaneApiClient {
  AssistedLaneApiClient({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  Future<WorkspaceData> loadWorkspace(ApiSession session) async {
    final compliance = await fetchCompliance(session);
    final offlineSteps = await listOfflineSteps(session);
    final legalCases = await listLegalCases(session);
    return WorkspaceData(
      compliance: compliance,
      offlineSteps: offlineSteps,
      legalCases: legalCases,
    );
  }

  Future<JsonMap> fetchCompliance(ApiSession session) async {
    final payload = await _request(
      session,
      method: 'GET',
      path: '/transactions/${session.transactionId}/compliance',
    );
    return _asMap(payload);
  }

  Future<List<OfflineStepRecord>> listOfflineSteps(ApiSession session) async {
    final payload = await _request(
      session,
      method: 'GET',
      path: '/transactions/${session.transactionId}/offline-steps',
    );
    return _asList(payload)
        .map((item) => OfflineStepRecord.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<LegalCaseRecord>> listLegalCases(ApiSession session) async {
    final payload = await _request(
      session,
      method: 'GET',
      path: '/transactions/${session.transactionId}/legal-cases',
    );
    return _asList(payload)
        .map((item) => LegalCaseRecord.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<List<NotificationRecord>> listNotifications(
    ApiSession session, {
    bool unreadOnly = false,
  }) async {
    final query = unreadOnly ? '?status=unread' : '';
    final payload = await _request(
      session,
      method: 'GET',
      path: '/notifications/$query',
    );
    return _asList(payload)
        .map((item) => NotificationRecord.fromJson(_asMap(item)))
        .toList(growable: false);
  }

  Future<int> fetchUnreadNotificationCount(ApiSession session) async {
    final payload = await _request(
      session,
      method: 'GET',
      path: '/notifications/unread-count',
    );
    final map = _asMap(payload);
    final count = map['unread_count'];
    if (count is int) {
      return count;
    }
    return int.tryParse(count?.toString() ?? '') ?? 0;
  }

  Future<void> markNotificationRead(
    ApiSession session, {
    required String notificationId,
  }) async {
    await _request(
      session,
      method: 'POST',
      path: '/notifications/$notificationId/read',
    );
  }

  Future<void> dismissNotification(
    ApiSession session, {
    required String notificationId,
  }) async {
    await _request(
      session,
      method: 'DELETE',
      path: '/notifications/$notificationId',
    );
  }

  Future<void> markAllNotificationsRead(ApiSession session) async {
    await _request(session, method: 'POST', path: '/notifications/read-all');
  }

  Future<void> createOfflineStep(
    ApiSession session, {
    required String stepType,
    required String physicalStatus,
    String? expectedOffice,
    String? assignedRole,
    String? notes,
    DateTime? filingDate,
    DateTime? scheduledAt,
    DateTime? nextFollowUpDate,
    bool originalRequired = false,
    bool oversightRequired = false,
  }) async {
    await _request(
      session,
      method: 'POST',
      path: '/transactions/${session.transactionId}/offline-steps',
      body: {
        'step_type': stepType,
        'physical_status': physicalStatus,
        if (expectedOffice != null && expectedOffice.trim().isNotEmpty)
          'expected_office': expectedOffice.trim(),
        if (assignedRole != null && assignedRole.trim().isNotEmpty)
          'assigned_role': assignedRole.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (filingDate != null) 'filing_date': filingDate.toIso8601String(),
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
        if (nextFollowUpDate != null)
          'next_follow_up_date': nextFollowUpDate.toIso8601String(),
        'original_required': originalRequired,
        'oversight_required': oversightRequired,
      },
    );
  }

  Future<void> updateOfflineStepStatus(
    ApiSession session, {
    required String stepId,
    required String physicalStatus,
    String? delayReason,
    String? notes,
    DateTime? filingDate,
    DateTime? scheduledAt,
    DateTime? nextFollowUpDate,
  }) async {
    await _request(
      session,
      method: 'POST',
      path:
          '/transactions/${session.transactionId}/offline-steps/$stepId/status',
      body: {
        'physical_status': physicalStatus,
        if (delayReason != null && delayReason.trim().isNotEmpty)
          'delay_reason': delayReason.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (filingDate != null) 'filing_date': filingDate.toIso8601String(),
        if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
        if (nextFollowUpDate != null)
          'next_follow_up_date': nextFollowUpDate.toIso8601String(),
      },
    );
  }

  Future<void> createLegalCase(
    ApiSession session, {
    required String caseType,
    required String status,
    String? expectedOffice,
    String? referenceNumber,
    String? courtName,
    String? notes,
    String? delayReason,
    DateTime? filingDate,
    DateTime? nextFollowUpDate,
    DateTime? finalDecisionDate,
    bool freezesAutomation = true,
    bool requiresAdminOversight = false,
  }) async {
    await _request(
      session,
      method: 'POST',
      path: '/transactions/${session.transactionId}/legal-cases',
      body: {
        'case_type': caseType,
        'status': status,
        if (expectedOffice != null && expectedOffice.trim().isNotEmpty)
          'expected_office': expectedOffice.trim(),
        if (referenceNumber != null && referenceNumber.trim().isNotEmpty)
          'reference_number': referenceNumber.trim(),
        if (courtName != null && courtName.trim().isNotEmpty)
          'court_name': courtName.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (delayReason != null && delayReason.trim().isNotEmpty)
          'delay_reason': delayReason.trim(),
        if (filingDate != null) 'filing_date': filingDate.toIso8601String(),
        if (nextFollowUpDate != null)
          'next_follow_up_date': nextFollowUpDate.toIso8601String(),
        if (finalDecisionDate != null)
          'final_decision_date': finalDecisionDate.toIso8601String(),
        'freezes_automation': freezesAutomation,
        'requires_admin_oversight': requiresAdminOversight,
      },
    );
  }

  Future<void> updateLegalCaseStatus(
    ApiSession session, {
    required String caseId,
    required String status,
    String? delayReason,
    String? referenceNumber,
    String? courtName,
    String? notes,
    DateTime? filingDate,
    DateTime? nextFollowUpDate,
    DateTime? finalDecisionDate,
  }) async {
    await _request(
      session,
      method: 'POST',
      path: '/transactions/${session.transactionId}/legal-cases/$caseId/status',
      body: {
        'status': status,
        if (delayReason != null && delayReason.trim().isNotEmpty)
          'delay_reason': delayReason.trim(),
        if (referenceNumber != null && referenceNumber.trim().isNotEmpty)
          'reference_number': referenceNumber.trim(),
        if (courtName != null && courtName.trim().isNotEmpty)
          'court_name': courtName.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (filingDate != null) 'filing_date': filingDate.toIso8601String(),
        if (nextFollowUpDate != null)
          'next_follow_up_date': nextFollowUpDate.toIso8601String(),
        if (finalDecisionDate != null)
          'final_decision_date': finalDecisionDate.toIso8601String(),
      },
    );
  }

  Future<Object?> _request(
    ApiSession session, {
    required String method,
    required String path,
    JsonMap? body,
  }) async {
    final uri = Uri.parse('${session.normalizedBaseUrl}$path');
    final request = await _client.openUrl(method, uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    if (session.bearerToken.trim().isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${session.bearerToken.trim()}',
      );
    }
    if (body != null) {
      request.add(utf8.encode(jsonEncode(body)));
    }

    final response = await request.close();
    final raw = await response.transform(utf8.decoder).join();
    final decoded = raw.isEmpty ? null : jsonDecode(raw);

    if (response.statusCode >= 400) {
      throw ApiFailure(_extractError(decoded) ?? 'Request failed.');
    }

    if (decoded is JsonMap && decoded['status'] == 'error') {
      throw ApiFailure(_extractError(decoded) ?? 'Request failed.');
    }

    if (decoded is JsonMap && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }

  String? _extractError(Object? decoded) {
    if (decoded case {'error': final Object? error}) {
      final payload = _asMap(error);
      return payload['message']?.toString();
    }
    return null;
  }

  JsonMap _asMap(Object? value) {
    if (value is JsonMap) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  List<Object?> _asList(Object? value) {
    if (value is List) {
      return value.cast<Object?>();
    }
    return const <Object?>[];
  }
}

DateTime? _readDateTime(Object? value) {
  if (value case final String raw when raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}
