import 'package:flutter/material.dart';

import '../../data/assisted_lane_api.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({
    super.key,
    required this.session,
    required this.onOpenSession,
  });

  final ApiSession? session;
  final VoidCallback onOpenSession;

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  final AssistedLaneApiClient _client = AssistedLaneApiClient();

  List<NotificationRecord> _notifications = const [];
  bool _loading = false;
  bool _markingAll = false;
  int _unreadCount = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NotificationCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.baseUrl != widget.session?.baseUrl ||
        oldWidget.session?.bearerToken != widget.session?.bearerToken) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session == null || session.bearerToken.trim().isEmpty) {
      return _NotificationEmptyState(onOpenSession: widget.onOpenSession);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 12,
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Center',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF163328),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unread: $_unreadCount',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF5C635B),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                    FilledButton.icon(
                      onPressed: _markingAll || _notifications.isEmpty
                          ? null
                          : _markAllRead,
                      icon: const Icon(Icons.done_all_rounded),
                      label: Text(
                        _markingAll ? 'Updating...' : 'Mark All Read',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_message case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _NotificationBanner(message: message),
          ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_notifications.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No in-app notifications have been delivered to this operator session yet.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5C635B),
                  height: 1.5,
                ),
              ),
            ),
          )
        else
          ..._notifications.map(
            (notification) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NotificationCard(
                notification: notification,
                onMarkRead: notification.status == 'read'
                    ? null
                    : () => _markRead(notification.id),
                onDismiss: () => _dismissNotification(notification.id),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _load() async {
    final session = widget.session;
    if (session == null) {
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final notifications = await _client.listNotifications(session);
      final unreadCount = await _client.fetchUnreadNotificationCount(session);
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
      });
    } on ApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markRead(String notificationId) async {
    final session = widget.session;
    if (session == null) {
      return;
    }

    try {
      await _client.markNotificationRead(
        session,
        notificationId: notificationId,
      );
      await _load();
    } on ApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    }
  }

  Future<void> _markAllRead() async {
    final session = widget.session;
    if (session == null) {
      return;
    }

    setState(() {
      _markingAll = true;
      _message = null;
    });

    try {
      await _client.markAllNotificationsRead(session);
      await _load();
    } on ApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _markingAll = false;
        });
      }
    }
  }

  Future<void> _dismissNotification(String notificationId) async {
    final session = widget.session;
    if (session == null) {
      return;
    }

    try {
      await _client.dismissNotification(
        session,
        notificationId: notificationId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _notifications = _notifications
            .where((item) => item.id != notificationId)
            .toList(growable: false);
        _unreadCount = _notifications
            .where((item) => item.status == 'unread')
            .length;
      });
    } on ApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    }
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({required this.onOpenSession});

  final VoidCallback onOpenSession;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications Need a Session',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF163328),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Load a saved operator session first so the notification center can call the secure backend inbox endpoints.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5C635B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onOpenSession,
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Open Session'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
    required this.onDismiss,
  });

  final NotificationRecord notification;
  final VoidCallback? onMarkRead;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final severityColor = switch (notification.severity) {
      'critical' => const Color(0xFF8A2C2C),
      'warning' => const Color(0xFF9B6400),
      'success' => const Color(0xFF1E5A43),
      _ => const Color(0xFF255481),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  label: Text(notification.severity.toUpperCase()),
                  backgroundColor: severityColor.withValues(alpha: 0.12),
                  labelStyle: TextStyle(
                    color: severityColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Chip(
                  label: Text(notification.category),
                  backgroundColor: const Color(0xFFE7F0EA),
                ),
                if (notification.status == 'unread')
                  const Chip(
                    label: Text('Unread'),
                    backgroundColor: Color(0xFFF4E4BE),
                  ),
                ActionChip(
                  onPressed: onDismiss,
                  avatar: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Remove'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              notification.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF163328),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notification.body,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF415046),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  notification.createdAt == null
                      ? 'Just now'
                      : 'Created ${_formatDate(notification.createdAt!)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5C635B),
                  ),
                ),
                if (onMarkRead != null)
                  TextButton.icon(
                    onPressed: onMarkRead,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark Read'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFEFF4F7),
        border: Border.all(color: const Color(0xFFD2DFE9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = switch (local.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month $day, ${local.year} at $hour:$minute';
}
