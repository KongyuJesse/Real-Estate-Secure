import 'package:flutter/material.dart';

import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';

class ConsumerTransactionDetailPage extends StatelessWidget {
  const ConsumerTransactionDetailPage({
    super.key,
    required this.controller,
    required this.transactionId,
  });

  final ConsumerController controller;
  final String transactionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Tracking')),
      body:
          FutureBuilder<
            (
              ConsumerTransactionDetail,
              ConsumerTransactionCompliance,
              List<ConsumerTimelineEvent>,
            )
          >(
            future: _loadBundle(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ResSurfaceCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 40,
                            color: ResColors.tertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This transaction file is temporarily unavailable.',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Refresh from the workspace and try again.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final detail = snapshot.data!.$1;
              final compliance = snapshot.data!.$2;
              final timeline = snapshot.data!.$3;
              final timelineItems = timeline.isEmpty
                  ? _fallbackTimeline(detail, compliance)
                  : timeline;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  ResPageHeader(
                    eyebrow: 'Secure file',
                    title: detail.transactionNumber,
                    subtitle:
                        'Track the progress, legal posture, and current settlement state of this protected transaction.',
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: ResColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border(
                        left: BorderSide(
                          color: compliance.offlineWorkflowRequired
                              ? ResColors.secondary
                              : ResColors.primary,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: compliance.offlineWorkflowRequired
                                ? ResColors.secondaryContainer.withValues(
                                    alpha: 0.40,
                                  )
                                : ResColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            compliance.offlineWorkflowRequired
                                ? ResIcons.legal
                                : ResIcons.document,
                            color: compliance.offlineWorkflowRequired
                                ? ResColors.secondary
                                : ResColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status update',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(color: ResColors.primary),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                compliance.automationFreezeReason
                                        .trim()
                                        .isNotEmpty
                                    ? compliance.automationFreezeReason
                                    : compliance.assistedLaneReason
                                          .trim()
                                          .isNotEmpty
                                    ? compliance.assistedLaneReason
                                    : 'Your documents are moving through the current verification and legal workflow lane.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ResSurfaceCard(
                    radius: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ResSectionHeader(
                          title: 'Compliance posture',
                          subtitle:
                              'Legal and operational requirements shaping this file.',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ResInfoChip(
                              label: startCase(detail.transactionStatus),
                              color: _statusColor(detail.transactionStatus),
                              icon: ResIcons.receipt,
                            ),
                            ResInfoChip(
                              label: startCase(detail.settlementMode),
                              color: ResColors.primary,
                              icon: ResIcons.wallet,
                            ),
                            ResInfoChip(
                              label: compliance.offlineWorkflowRequired
                                  ? 'Assisted lane'
                                  : 'Digital lane',
                              color: compliance.offlineWorkflowRequired
                                  ? ResColors.secondary
                                  : ResColors.tertiary,
                              icon: ResIcons.secure,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          label: 'Transaction type',
                          value: startCase(detail.transactionType),
                        ),
                        _InfoRow(
                          label: 'Lawyer requirement',
                          value: startCase(compliance.lawyerRequirementLevel),
                        ),
                        _InfoRow(
                          label: 'Notary requirement',
                          value: startCase(compliance.notaryRequirementLevel),
                        ),
                        _InfoRow(
                          label: 'Legal case type',
                          value: startCase(compliance.legalCaseType),
                        ),
                        _InfoRow(
                          label: 'Total amount',
                          value: formatXaf(detail.totalAmount),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const ResSectionHeader(
                    title: 'Progress',
                    subtitle:
                        'Chronological movement of the secure file and its legal milestones.',
                  ),
                  const SizedBox(height: 18),
                  _TimelineRail(events: timelineItems),
                  const SizedBox(height: 24),
                  ResPrimaryButton(
                    label: 'Review compliance details',
                    icon: ResIcons.legal,
                    isPill: true,
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The current legal and compliance posture is shown above.',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<
    (
      ConsumerTransactionDetail,
      ConsumerTransactionCompliance,
      List<ConsumerTimelineEvent>,
    )
  >
  _loadBundle() async {
    final results = await Future.wait<Object>([
      controller.loadTransactionDetail(transactionId),
      controller.loadTransactionCompliance(transactionId),
      controller.loadTransactionTimeline(transactionId),
    ]);
    return (
      results[0] as ConsumerTransactionDetail,
      results[1] as ConsumerTransactionCompliance,
      results[2] as List<ConsumerTimelineEvent>,
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({required this.events});

  final List<ConsumerTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 19,
          top: 12,
          bottom: 12,
          child: Container(width: 2, color: ResColors.surfaceContainerHigh),
        ),
        Column(
          children: List.generate(events.length, (index) {
            final event = events[index];
            final isCurrent = index == 0;
            final isDone = event.status == 'completed' || index < 1;
            final accent = isCurrent
                ? ResColors.primary
                : isDone
                ? ResColors.secondary
                : ResColors.softForeground;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == events.length - 1 ? 0 : 22,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? ResColors.primary
                          : isDone
                          ? ResColors.secondary
                          : ResColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      boxShadow: isCurrent ? ResShadows.glow : const [],
                    ),
                    child: Icon(
                      _timelineIcon(event.type),
                      color: isCurrent || isDone
                          ? Colors.white
                          : ResColors.softForeground,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.label?.trim().isNotEmpty == true
                                      ? startCase(event.label!)
                                      : startCase(event.type),
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: isCurrent
                                            ? ResColors.primary
                                            : ResColors.foreground,
                                      ),
                                ),
                              ),
                              if (isCurrent)
                                ResInfoChip(
                                  label: 'In progress',
                                  color: ResColors.primary,
                                  icon: ResIcons.document,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.createdAt == null
                                ? startCase(event.status)
                                : _formatDate(event.createdAt!),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ResColors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<ConsumerTimelineEvent> _fallbackTimeline(
  ConsumerTransactionDetail detail,
  ConsumerTransactionCompliance compliance,
) {
  return [
    ConsumerTimelineEvent(
      type: 'document_verification',
      status: detail.transactionStatus,
      label: 'Document verification',
      createdAt: detail.updatedAt ?? detail.createdAt,
    ),
    ConsumerTimelineEvent(
      type: 'legal_review',
      status: compliance.automationFrozen ? 'pending' : 'scheduled',
      label: 'Lawyer legal approval',
      createdAt: detail.updatedAt ?? detail.createdAt,
    ),
    ConsumerTimelineEvent(
      type: 'settlement',
      status: detail.transactionStatus,
      label: 'Ownership transfer',
      createdAt: detail.createdAt,
    ),
  ];
}

IconData _timelineIcon(String type) {
  switch (type) {
    case 'payment':
    case 'deposit':
      return ResIcons.wallet;
    case 'inspection':
      return ResIcons.eye;
    case 'legal_review':
      return ResIcons.legal;
    case 'settlement':
      return ResIcons.rent;
    default:
      return ResIcons.document;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'completed':
      return ResColors.secondary;
    case 'cancelled':
    case 'disputed':
      return ResColors.destructive;
    default:
      return ResColors.tertiary;
  }
}

String _formatDate(DateTime value) {
  final month = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][value.month - 1];
  return '$month ${value.day}, ${value.year}';
}
