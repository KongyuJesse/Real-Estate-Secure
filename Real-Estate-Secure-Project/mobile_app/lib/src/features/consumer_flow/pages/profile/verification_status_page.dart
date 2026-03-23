import 'package:flutter/material.dart';

import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import 'kyc_submission_page.dart';
import 'verification_copy.dart';
import 'verification_dialogs.dart';

class ConsumerVerificationStatusPage extends StatefulWidget {
  const ConsumerVerificationStatusPage({super.key, required this.controller});

  final ConsumerController controller;

  @override
  State<ConsumerVerificationStatusPage> createState() =>
      _ConsumerVerificationStatusPageState();
}

class _ConsumerVerificationStatusPageState
    extends State<ConsumerVerificationStatusPage>
    with WidgetsBindingObserver {
  late Future<List<ConsumerKycRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recordsFuture = widget.controller.loadKycRecords();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.controller.isAuthenticated &&
        widget.controller.profile?.kycVerified != true) {
      setState(() {
        _recordsFuture = widget.controller.refreshKycStatus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final profile = widget.controller.profile;

        return Scaffold(
          body: FutureBuilder<List<ConsumerKycRecord>>(
            future: _recordsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final records = snapshot.data!;
              final latest = records.isNotEmpty ? records.first : null;
              final roleCopy = verificationCopyForRole(
                profile?.resolvedPrimaryRole ?? 'buyer',
              );
              final accountVerified =
                  profile?.emailVerified == true &&
                  profile?.phoneVerified == true;
              final kycStatusLabel = latest == null
                  ? startCase(profile?.kycStatus ?? 'pending')
                  : _statusLabel(latest.verificationStatus);

              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshStatusBoard,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                          children: [
                            Row(
                              children: [
                                ResCircleIconButton(
                                  icon: ResIcons.back,
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Identity check',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${roleCopy.roleLabel} profile, email, and phone.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: ResColors.mutedForeground,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ResInfoChip(
                                  label: accountVerified
                                      ? '${roleCopy.roleLabel} ready'
                                      : 'Checks pending',
                                  color: ResColors.primary,
                                  icon: accountVerified
                                      ? ResIcons.trust
                                      : ResIcons.security,
                                ),
                                ResInfoChip(
                                  label: latest == null
                                      ? 'KYC not started'
                                      : kycStatusLabel,
                                  color: latest == null
                                      ? ResColors.accent
                                      : _statusColor(latest.verificationStatus),
                                  icon: ResIcons.identity,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              latest == null
                                  ? roleCopy.startSummary
                                  : 'Latest case: ${_statusLabel(latest.verificationStatus).toLowerCase()}.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: ResColors.mutedForeground),
                            ),
                            const SizedBox(height: 18),
                            _ReviewStateCard(
                              latest: latest,
                              accountVerified: accountVerified,
                              roleCopy: roleCopy,
                              onRefresh: _refreshStatusBoard,
                              onStartVerification: profile == null
                                  ? null
                                  : () => _openSubmission(profile),
                            ),
                            const SizedBox(height: 18),
                            if (profile != null) ...[
                              _TrustSection(
                                title: 'Contact checks',
                                subtitle: 'Keep your sign-in details trusted.',
                                child: Column(
                                  children: [
                                    _VerificationChannelCard(
                                      title: 'Email address',
                                      value: profile.email,
                                      isVerified: profile.emailVerified,
                                      description: profile.emailVerified
                                          ? 'Verified and ready.'
                                          : roleCopy.emailPendingDescription,
                                      actionLabel: profile.emailVerified
                                          ? 'Verified'
                                          : 'Verify email',
                                      actionIcon:
                                          Icons.mark_email_read_outlined,
                                      onAction: profile.emailVerified
                                          ? null
                                          : () =>
                                                _openEmailVerification(profile),
                                    ),
                                    const SizedBox(height: 12),
                                    _VerificationChannelCard(
                                      title: 'Phone number',
                                      value: profile.phoneNumber.isEmpty
                                          ? 'No phone number on file'
                                          : profile.phoneNumber,
                                      isVerified: profile.phoneVerified,
                                      description: profile.phoneVerified
                                          ? 'Verified and ready.'
                                          : roleCopy.phonePendingDescription,
                                      actionLabel: profile.phoneVerified
                                          ? 'Verified'
                                          : 'Verify phone',
                                      actionIcon: Icons.sms_outlined,
                                      onAction:
                                          profile.phoneVerified ||
                                              profile.phoneNumber.isEmpty
                                          ? null
                                          : () =>
                                                _openPhoneVerification(profile),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            ResPrimaryButton(
                              label: records.isEmpty
                                  ? 'Start verification'
                                  : 'Continue verification',
                              icon: ResIcons.upload,
                              onPressed: profile == null
                                  ? null
                                  : () => _openSubmission(profile),
                            ),
                            const SizedBox(height: 24),
                            const ResSectionHeader(title: 'Submission history'),
                            const SizedBox(height: 12),
                            if (records.isEmpty)
                              ResSurfaceCard(
                                child: Text(
                                  'No submissions yet.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ResColors.mutedForeground,
                                      ),
                                ),
                              )
                            else
                              ...records.map(
                                (record) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _HistoryCard(record: record),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openSubmission(ConsumerUserProfile profile) async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ConsumerKycSubmissionPage(
          controller: widget.controller,
          profile: profile,
        ),
      ),
    );
    if (submitted == true && mounted) {
      setState(() {
        _recordsFuture = widget.controller.refreshKycStatus();
      });
    }
  }

  Future<void> _refreshStatusBoard() async {
    setState(() {
      _recordsFuture = widget.controller.refreshKycStatus();
    });
    await _recordsFuture;
  }

  Future<void> _openEmailVerification(ConsumerUserProfile profile) async {
    final updated = await showConsumerEmailVerificationDialog(
      context: context,
      controller: widget.controller,
      profile: profile,
    );
    if (updated == true && mounted) {
      await _refreshStatusBoard();
    }
  }

  Future<void> _openPhoneVerification(ConsumerUserProfile profile) async {
    final updated = await showConsumerPhoneVerificationDialog(
      context: context,
      controller: widget.controller,
      profile: profile,
    );
    if (updated == true && mounted) {
      await _refreshStatusBoard();
    }
  }
}

class _TrustSection extends StatelessWidget {
  const _TrustSection({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ReviewStateCard extends StatelessWidget {
  const _ReviewStateCard({
    required this.latest,
    required this.accountVerified,
    required this.roleCopy,
    required this.onRefresh,
    this.onStartVerification,
  });

  final ConsumerKycRecord? latest;
  final bool accountVerified;
  final ConsumerVerificationRoleCopy roleCopy;
  final Future<void> Function() onRefresh;
  final VoidCallback? onStartVerification;

  @override
  Widget build(BuildContext context) {
    final title = _reviewStateTitle(latest, accountVerified, roleCopy);
    final summary = _reviewStateSummary(latest, accountVerified, roleCopy);
    final actions = _reviewActionItems(latest, accountVerified, roleCopy);

    return ResSurfaceCard(
      color: ResColors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ResSectionHeader(title: title, subtitle: summary),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(
                    latest?.verificationStatus ?? 'pending',
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  latest?.verificationStatus == 'verified'
                      ? ResIcons.trust
                      : ResIcons.identity,
                  color: _statusColor(latest?.verificationStatus ?? 'pending'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ResInfoChip(
                label: latest == null ? 'Ready to start' : 'Active session',
                color: ResColors.primary,
                icon: ResIcons.secure,
              ),
              ResInfoChip(
                label: latest == null
                    ? 'No active case'
                    : _statusLabel(latest!.verificationStatus),
                color: _statusColor(latest?.verificationStatus ?? 'pending'),
                icon: ResIcons.analytics,
              ),
              if ((latest?.reviewStatus ?? '').trim().isNotEmpty)
                ResInfoChip(
                  label: 'Stage ${_statusLabel(latest!.reviewStatus)}',
                  color: ResColors.info,
                  icon: ResIcons.document,
                ),
              if ((latest?.reviewRejectType ?? '').trim().isNotEmpty)
                ResInfoChip(
                  label: startCase(
                    latest!.reviewRejectType.replaceAll('_', ' '),
                  ),
                  color: ResColors.destructive,
                  icon: Icons.rule_folder_outlined,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...actions.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChecklistLine(text: item),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ResOutlineButton(
                  label: 'Refresh status',
                  icon: Icons.refresh_rounded,
                  isPill: true,
                  onPressed: () => onRefresh(),
                ),
              ),
              if (onStartVerification != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ResPrimaryButton(
                    label: latest == null
                        ? 'Start verification'
                        : 'Continue verification',
                    icon: ResIcons.upload,
                    onPressed: onStartVerification,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.record});

  final ConsumerKycRecord record;

  @override
  Widget build(BuildContext context) {
    final displayReference = record.reference.trim().isNotEmpty
        ? record.reference.trim()
        : record.documentNumber.trim();

    return ResSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ResInfoChip(
                label: _statusLabel(record.verificationStatus),
                color: _statusColor(record.verificationStatus),
                icon: record.verificationStatus == 'verified'
                    ? ResIcons.check
                    : ResIcons.identity,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (displayReference.isNotEmpty) ...[
            Text(
              displayReference,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ResInfoChip(
                label: 'Identity check',
                color: record.isProviderFlow
                    ? ResColors.primary
                    : ResColors.info,
                icon: record.isProviderFlow ? ResIcons.secure : ResIcons.upload,
              ),
              if (record.createdAt != null)
                ResInfoChip(
                  label: 'Submitted ${_formatDate(record.createdAt!)}',
                  color: ResColors.primary,
                  icon: ResIcons.document,
                ),
              if (record.verifiedAt != null)
                ResInfoChip(
                  label: 'Reviewed ${_formatDate(record.verifiedAt!)}',
                  color: ResColors.secondary,
                  icon: ResIcons.trust,
                ),
              if (record.reviewAnswer.trim().isNotEmpty)
                ResInfoChip(
                  label: 'Review ${startCase(record.reviewAnswer)}',
                  color: _statusColor(record.verificationStatus),
                  icon: ResIcons.analytics,
                ),
              if (record.reviewStatus.trim().isNotEmpty)
                ResInfoChip(
                  label: 'Stage ${_statusLabel(record.reviewStatus)}',
                  color: ResColors.info,
                  icon: ResIcons.secure,
                ),
              if (record.reviewRejectType.trim().isNotEmpty)
                ResInfoChip(
                  label: startCase(
                    record.reviewRejectType.replaceAll('_', ' '),
                  ),
                  color: ResColors.destructive,
                  icon: Icons.rule_folder_outlined,
                ),
            ],
          ),
          if (record.latestNote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              record.latestNote.trim(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerificationChannelCard extends StatelessWidget {
  const _VerificationChannelCard({
    required this.title,
    required this.value,
    required this.description,
    required this.isVerified,
    required this.actionLabel,
    required this.actionIcon,
    this.onAction,
  });

  final String title;
  final String value;
  final String description;
  final bool isVerified;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ResInfoChip(
                label: isVerified ? 'Verified' : 'Pending',
                color: isVerified ? ResColors.secondary : ResColors.primary,
                icon: isVerified
                    ? Icons.verified_user_outlined
                    : Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
          const SizedBox(height: 14),
          ResPrimaryButton(
            label: actionLabel,
            icon: actionIcon,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _ChecklistLine extends StatelessWidget {
  const _ChecklistLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: ResColors.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }
}

String _reviewStateTitle(
  ConsumerKycRecord? latest,
  bool accountVerified,
  ConsumerVerificationRoleCopy roleCopy,
) {
  if (!accountVerified) {
    return 'Finish account checks';
  }
  if (latest == null) {
    return 'Start ${roleCopy.roleLabel.toLowerCase()} check';
  }
  if (latest.verificationStatus == 'verified') {
    return '${roleCopy.roleLabel} ready';
  }
  if (_isRejectedReview(latest)) {
    return 'Resubmission needed';
  }
  if (latest.reviewStatus.trim().toLowerCase() == 'completed') {
    return 'Review completed';
  }
  if (latest.reviewStatus.trim().toLowerCase() == 'queued') {
    return 'Queued for review';
  }
  return 'Verification in progress';
}

String _reviewStateSummary(
  ConsumerKycRecord? latest,
  bool accountVerified,
  ConsumerVerificationRoleCopy roleCopy,
) {
  if (!accountVerified) {
    return 'Verify email and phone first.';
  }
  if (latest == null) {
    return roleCopy.startSummary;
  }
  if (latest.verificationStatus == 'verified') {
    return roleCopy.approvedBody;
  }
  if (_isRejectedReview(latest)) {
    return latest.latestNote.trim().isNotEmpty
        ? latest.latestNote.trim()
        : 'The last case was rejected.';
  }
  if (latest.reviewStatus.trim().toLowerCase() == 'queued') {
    return 'Your submission is waiting for review.';
  }
  return 'Your submission is still being reviewed.';
}

List<String> _reviewActionItems(
  ConsumerKycRecord? latest,
  bool accountVerified,
  ConsumerVerificationRoleCopy roleCopy,
) {
  if (!accountVerified) {
    return const ['Verify your email address.', 'Verify your phone number.'];
  }
  if (latest == null) {
    return roleCopy.readyChecklist;
  }
  if (latest.verificationStatus == 'verified') {
    return roleCopy.verifiedChecklist;
  }

  final rejectType = latest.reviewRejectType.trim().toLowerCase();
  final note = latest.latestNote.trim().toLowerCase();
  if (_isRejectedReview(latest)) {
    return [
      if (rejectType.contains('document') || note.contains('document'))
        'Retake the document with sharp focus and full edges.'
      else
        'Retake the capture in stable light.',
      if (rejectType.contains('selfie') ||
          rejectType.contains('liveness') ||
          note.contains('selfie') ||
          note.contains('liveness'))
        'Repeat the selfie or liveness step with a clear face.'
      else
        'Check names, dates, and document details carefully.',
    ];
  }

  return const [
    'Keep your email and phone reachable.',
    'Refresh if the status does not update.',
  ];
}

bool _isRejectedReview(ConsumerKycRecord latest) {
  const rejectedStates = {
    'rejected',
    'failed',
    'finally_rejected',
    'red',
    'declined',
  };
  return rejectedStates.contains(
        latest.verificationStatus.trim().toLowerCase(),
      ) ||
      rejectedStates.contains(latest.reviewStatus.trim().toLowerCase()) ||
      latest.reviewAnswer.trim().toLowerCase() == 'red';
}

Color _statusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'verified':
    case 'approved':
    case 'green':
      return ResColors.secondary;
    case 'rejected':
    case 'failed':
    case 'finally_rejected':
    case 'red':
      return ResColors.destructive;
    case 'temporarily_declined':
      return ResColors.tertiary;
    default:
      return ResColors.primary;
  }
}

String _statusLabel(String status) {
  switch (status.trim().toLowerCase()) {
    case 'temporarily_declined':
      return 'Temporarily declined';
    case 'finally_rejected':
      return 'Rejected';
    case 'action_completed':
      return 'Action completed';
    default:
      return startCase(status);
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
  return '${value.day} $month ${value.year}';
}
