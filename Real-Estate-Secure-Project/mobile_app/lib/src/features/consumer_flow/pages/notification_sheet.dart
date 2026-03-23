import 'package:flutter/material.dart';

import '../consumer_controller.dart';
import '../consumer_models.dart';
import '../../../ui/app_icons.dart';
import '../../../ui/brand.dart';
import '../../../ui/components/cards.dart';

class ConsumerNotificationSheet extends StatelessWidget {
  const ConsumerNotificationSheet({super.key, required this.controller});

  final ConsumerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final notifications = controller.notifications;
        final isLoading = controller.isLoadingNotifications;
        final unreadCount = notifications
            .where((item) => item.status == 'unread')
            .length;
        final grouped = _groupNotifications(notifications);

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: ResColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(30),
              boxShadow: ResShadows.floating,
            ),
            child: SizedBox(
              height: 580,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: ResGradients.premiumButton,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(ResIcons.bell, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Stay updated on your property journey.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (unreadCount > 0)
                        TextButton(
                          onPressed: () =>
                              controller.markAllNotificationsRead(),
                          child: Text('$unreadCount unread'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (notifications.isEmpty)
                    Expanded(
                      child: ResSurfaceCard(
                        radius: 24,
                        color: ResColors.surfaceContainerLow,
                        shadow: const [],
                        child: Center(
                          child: Text(
                            'No notifications yet. Updates about viewings, files, and your account will appear here.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          if (grouped.today.isNotEmpty) ...[
                            const _SectionLabel(label: 'Today'),
                            const SizedBox(height: 12),
                            ...grouped.today.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _NotificationCard(
                                  item: item,
                                  onMarkRead: item.status == 'unread'
                                      ? () => controller.markNotificationRead(
                                          item.id,
                                        )
                                      : null,
                                  onDismiss: () =>
                                      controller.dismissNotification(item.id),
                                ),
                              ),
                            ),
                          ],
                          if (grouped.earlier.isNotEmpty) ...[
                            if (grouped.today.isNotEmpty)
                              const SizedBox(height: 12),
                            const _SectionLabel(label: 'Earlier'),
                            const SizedBox(height: 12),
                            ...grouped.earlier.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _NotificationCard(
                                  item: item,
                                  onMarkRead: item.status == 'unread'
                                      ? () => controller.markNotificationRead(
                                          item.id,
                                        )
                                      : null,
                                  onDismiss: () =>
                                      controller.dismissNotification(item.id),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationGroup {
  const _NotificationGroup({required this.today, required this.earlier});

  final List<ConsumerNotificationRecord> today;
  final List<ConsumerNotificationRecord> earlier;
}

_NotificationGroup _groupNotifications(
  List<ConsumerNotificationRecord> notifications,
) {
  final now = DateTime.now();
  final today = <ConsumerNotificationRecord>[];
  final earlier = <ConsumerNotificationRecord>[];

  for (final item in notifications) {
    final createdAt = item.createdAt;
    final sameDay =
        createdAt != null &&
        createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
    if (sameDay) {
      today.add(item);
    } else {
      earlier.add(item);
    }
  }

  return _NotificationGroup(today: today, earlier: earlier);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: ResColors.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    this.onMarkRead,
    this.onDismiss,
  });

  final ConsumerNotificationRecord item;
  final Future<void> Function()? onMarkRead;
  final Future<void> Function()? onDismiss;

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor(item.severity);
    final icon = _severityIcon(item.severity);
    final isUnread = item.status == 'unread';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread
            ? ResColors.surfaceContainerLowest
            : ResColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border(left: BorderSide(color: severityColor, width: 4)),
        boxShadow: isUnread ? ResShadows.card : const [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: severityColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.category.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: severityColor),
                          ),
                        ),
                        if (onDismiss != null)
                          IconButton(
                            onPressed: () => onDismiss?.call(),
                            tooltip: 'Remove notification',
                            icon: const Icon(Icons.close_rounded),
                            visualDensity: VisualDensity.compact,
                            color: ResColors.mutedForeground,
                          ),
                        Text(
                          _formatTimestamp(item.createdAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.body, style: Theme.of(context).textTheme.bodySmall),
          if (item.actionLabel != null &&
              item.actionLabel!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.actionLabel!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ResColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (onMarkRead != null || onDismiss != null) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (onMarkRead != null)
                  TextButton(
                    onPressed: () => onMarkRead?.call(),
                    child: const Text('Mark as read'),
                  ),
                if (onDismiss != null)
                  TextButton(
                    onPressed: () => onDismiss?.call(),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Color _severityColor(String severity) {
  switch (severity) {
    case 'success':
      return ResColors.secondary;
    case 'warning':
      return ResColors.tertiary;
    case 'critical':
      return ResColors.destructive;
    default:
      return ResColors.primary;
  }
}

IconData _severityIcon(String severity) {
  switch (severity) {
    case 'success':
      return ResIcons.check;
    case 'warning':
      return Icons.warning_amber_rounded;
    case 'critical':
      return Icons.error_outline_rounded;
    default:
      return ResIcons.bell;
  }
}

String _formatTimestamp(DateTime? value) {
  if (value == null) {
    return '';
  }

  final now = DateTime.now();
  final difference = now.difference(value);
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes.clamp(1, 59)}m ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  return '${difference.inDays}d ago';
}
