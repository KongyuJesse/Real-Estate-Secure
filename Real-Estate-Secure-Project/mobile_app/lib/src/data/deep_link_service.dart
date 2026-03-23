import 'dart:async';

import 'package:flutter/services.dart';

enum ConsumerDeepLinkKind { unknown }

class ConsumerDeepLink {
  const ConsumerDeepLink({required this.uri, required this.kind});

  final Uri uri;
  final ConsumerDeepLinkKind kind;
}

ConsumerDeepLink? parseConsumerDeepLink(String? rawLink) {
  final trimmed = rawLink?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return null;
  }

  return ConsumerDeepLink(uri: uri, kind: ConsumerDeepLinkKind.unknown);
}

abstract interface class ConsumerDeepLinkService {
  Future<ConsumerDeepLink?> getInitialLink();

  Stream<ConsumerDeepLink> get links;
}

class PlatformConsumerDeepLinkService implements ConsumerDeepLinkService {
  static const _methodChannel = MethodChannel('real_estate_secure/deep_links');
  static const _eventChannel = EventChannel(
    'real_estate_secure/deep_links/events',
  );

  late final Stream<ConsumerDeepLink> _links = _eventChannel
      .receiveBroadcastStream()
      .map((value) => parseConsumerDeepLink(value?.toString()))
      .where((link) => link != null)
      .cast<ConsumerDeepLink>();

  @override
  Future<ConsumerDeepLink?> getInitialLink() async {
    try {
      final rawLink = await _methodChannel.invokeMethod<String>(
        'getInitialLink',
      );
      return parseConsumerDeepLink(rawLink);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Stream<ConsumerDeepLink> get links => _links;
}
