import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_idensic_mobile_sdk_plugin/flutter_idensic_mobile_sdk_plugin.dart';

import '../features/consumer_flow/consumer_models.dart';

class ConsumerKycCaptureResult {
  const ConsumerKycCaptureResult({
    required this.success,
    required this.status,
    required this.message,
    this.errorType,
  });

  final bool success;
  final String status;
  final String message;
  final String? errorType;

  bool get shouldRefreshStatus =>
      success ||
      status == 'pending' ||
      status == 'approved' ||
      status == 'temporarily_declined';
}

abstract class ConsumerKycCaptureService {
  Future<ConsumerKycCaptureResult> launch({
    required ConsumerKycSession session,
    required Locale locale,
    String? email,
    String? phone,
    required Future<String?> Function() onTokenExpiration,
  });
}

class SumsubConsumerKycCaptureService implements ConsumerKycCaptureService {
  const SumsubConsumerKycCaptureService();

  @override
  Future<ConsumerKycCaptureResult> launch({
    required ConsumerKycSession session,
    required Locale locale,
    String? email,
    String? phone,
    required Future<String?> Function() onTokenExpiration,
  }) async {
    SNSMobileSDKStatus latestStatus = SNSMobileSDKStatus.Initial;

    final builder = SNSMobileSDK.init(session.accessToken, onTokenExpiration)
      ..withLocale(locale)
      ..withDebug(kDebugMode)
      ..withAnalyticsEnabled(false)
      ..withAutoCloseOnApprove(3)
      ..withStrings(_strings)
      ..withTheme(_theme)
      ..withHandlers(
        onStatusChanged: (newStatus, _) {
          latestStatus = newStatus;
        },
        onEvent: (_) {},
      );

    final applicantConf = <String, String>{};
    if ((email ?? '').trim().isNotEmpty) {
      applicantConf['email'] = email!.trim();
    }
    if ((phone ?? '').trim().isNotEmpty) {
      applicantConf['phone'] = phone!.trim();
    }
    if (applicantConf.isNotEmpty) {
      builder.withApplicantConf(applicantConf);
    }

    final sdk = builder.build();
    final result = await sdk.launch();
    final resolvedStatus = _statusLabel(result.status, fallback: latestStatus);
    final errorType = result.errorType?.name;

    return ConsumerKycCaptureResult(
      success: result.success,
      status: resolvedStatus,
      errorType: errorType,
      message: _messageFor(
        session: session,
        result: result,
        latestStatus: latestStatus,
      ),
    );
  }
}

String _messageFor({
  required ConsumerKycSession session,
  required SNSMobileSDKResult result,
  required SNSMobileSDKStatus latestStatus,
}) {
  if (result.success) {
    if (session.purpose == 'email_verification' &&
        result.status == SNSMobileSDKStatus.ActionCompleted) {
      return 'Email verification completed. We are updating your status now.';
    }
    if (session.purpose == 'phone_verification' &&
        result.status == SNSMobileSDKStatus.ActionCompleted) {
      return 'Phone verification completed. We are updating your status now.';
    }
    switch (result.status) {
      case SNSMobileSDKStatus.Approved:
        return 'Identity verification completed. We are updating your status now.';
      case SNSMobileSDKStatus.Pending:
        return 'Verification was submitted for review.';
      default:
        return 'Verification completed. We are updating the latest status.';
    }
  }

  if (result.status == SNSMobileSDKStatus.TemporarilyDeclined) {
    return 'Verification needs another pass. Reopen it and try again.';
  }

  if (result.status == SNSMobileSDKStatus.FinallyRejected) {
    return 'This verification attempt was declined. Review the latest status and try again if invited.';
  }

  return 'Verification was not completed. Please try again.';
}

String _statusLabel(
  SNSMobileSDKStatus status, {
  required SNSMobileSDKStatus fallback,
}) {
  final resolved = status == SNSMobileSDKStatus.Initial ? fallback : status;
  return switch (resolved) {
    SNSMobileSDKStatus.Ready => 'ready',
    SNSMobileSDKStatus.Initial => 'initial',
    SNSMobileSDKStatus.Incomplete => 'incomplete',
    SNSMobileSDKStatus.Pending => 'pending',
    SNSMobileSDKStatus.Approved => 'approved',
    SNSMobileSDKStatus.Failed => 'failed',
    SNSMobileSDKStatus.FinallyRejected => 'finally_rejected',
    SNSMobileSDKStatus.TemporarilyDeclined => 'temporarily_declined',
    SNSMobileSDKStatus.ActionCompleted => 'action_completed',
  };
}

const Map<String, String> _strings = <String, String>{
  'sns_general_poweredBy': 'Protected by Real Estate Secure',
  'sns_oops_network_title': 'Connection interrupted',
  'sns_oops_network_html':
      'Please restore your connection and reopen secure verification.',
  'sns_oops_action_retry': 'Retry verification',
};

const Map<String, dynamic> _theme = <String, dynamic>{
  'universal': <String, dynamic>{
    'colors': <String, dynamic>{
      'backgroundCommon': <String, String>{'light': '#F8F9FF'},
      'backgroundNeutral': <String, String>{'light': '#ECEEF3'},
      'contentStrong': <String, String>{'light': '#191C20'},
      'contentNeutral': <String, String>{'light': '#454652'},
      'contentWeak': <String, String>{'light': '#767683'},
      'primaryButtonBackground': <String, String>{'light': '#000666'},
      'primaryButtonBackgroundHighlighted': <String, String>{
        'light': '#1A237E',
      },
      'primaryButtonContent': <String, String>{'light': '#FFFFFF'},
      'secondaryButtonContent': <String, String>{'light': '#1A237E'},
      'backgroundSuccess': <String, String>{'light': '#E2F2ED'},
      'contentSuccess': <String, String>{'light': '#046B5E'},
      'backgroundWarning': <String, String>{'light': '#F4ECD1'},
      'contentWarning': <String, String>{'light': '#705D00'},
      'backgroundCritical': <String, String>{'light': '#F7E2DF'},
      'contentCritical': <String, String>{'light': '#9B3A32'},
      'fieldBackground': <String, String>{'light': '#FFFFFF'},
      'fieldTint': <String, String>{'light': '#1A237E'},
      'bottomSheetBackground': <String, String>{'light': '#F8F9FF'},
    },
    'metrics': <String, dynamic>{
      'buttonCornerRadius': 18,
      'fieldCornerRadius': 16,
      'bottomSheetCornerRadius': 24,
      'cardCornerRadius': 22,
    },
  },
};
