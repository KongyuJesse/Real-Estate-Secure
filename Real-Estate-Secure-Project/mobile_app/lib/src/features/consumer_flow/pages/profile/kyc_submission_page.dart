import 'package:flutter/material.dart';

import '../../../../data/consumer_api.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import 'verification_copy.dart';

class ConsumerKycSubmissionPage extends StatefulWidget {
  const ConsumerKycSubmissionPage({
    super.key,
    required this.controller,
    required this.profile,
  });

  final ConsumerController controller;
  final ConsumerUserProfile profile;

  @override
  State<ConsumerKycSubmissionPage> createState() =>
      _ConsumerKycSubmissionPageState();
}

class _ConsumerKycSubmissionPageState extends State<ConsumerKycSubmissionPage> {
  bool _isLaunching = false;
  bool _isRefreshing = false;
  String? _statusMessage;

  ConsumerUserProfile get _profile =>
      widget.controller.profile ?? widget.profile;

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final roleCopy = verificationCopyForRole(profile.resolvedPrimaryRole);
    final contactReady = profile.emailVerified && profile.phoneVerified;
    final kycVerified = profile.kycVerified;
    final kycStatus = startCase(profile.kycStatus);
    final actionLabel = kycVerified
        ? 'Review verification'
        : profile.kycStatus.trim().toLowerCase() == 'pending'
        ? 'Continue verification'
        : 'Start verification';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          children: [
            Row(
              children: [
                ResCircleIconButton(
                  icon: ResIcons.back,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Identity check',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${roleCopy.roleLabel} profile, email, and phone.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ResColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ResHeroPanel(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kycVerified
                        ? '${roleCopy.roleLabel} profile ready'
                        : 'Verify your ${roleCopy.roleLabel.toLowerCase()} profile',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kycVerified ? roleCopy.approvedBody : roleCopy.pendingBody,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ResHeroMetricPill(
                        label: 'Role',
                        value: roleCopy.roleLabel,
                      ),
                      ResHeroMetricPill(label: 'Status', value: kycStatus),
                      ResHeroMetricPill(
                        label: 'Email',
                        value: profile.emailVerified ? 'Ready' : 'Pending',
                      ),
                      ResHeroMetricPill(
                        label: 'Phone',
                        value: profile.phoneVerified ? 'Ready' : 'Pending',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ResSurfaceCard(
              color: ResColors.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Before you continue',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _ReadinessLine(
                    icon: ResIcons.document,
                    text: roleCopy.readyChecklist.first,
                  ),
                  const _ReadinessLine(
                    icon: Icons.photo_camera_back_rounded,
                    text: 'Allow camera access.',
                  ),
                  _ReadinessLine(
                    icon: ResIcons.phone,
                    text: contactReady
                        ? 'Email and phone are already confirmed.'
                        : roleCopy.readyChecklist.last,
                  ),
                  const SizedBox(height: 18),
                  ResPrimaryButton(
                    label: actionLabel,
                    icon: ResIcons.secure,
                    isBusy: _isLaunching,
                    onPressed: _isRefreshing ? null : _launchProviderFlow,
                  ),
                  const SizedBox(height: 10),
                  ResOutlineButton(
                    label: 'Check status',
                    icon: Icons.refresh_rounded,
                    onPressed: _isLaunching ? null : _refreshStatus,
                  ),
                ],
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 18),
              ResSurfaceCard(
                color: ResColors.surfaceContainerLow,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ResColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        ResIcons.secure,
                        color: ResColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ResColors.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _launchProviderFlow() async {
    setState(() {
      _isLaunching = true;
      _statusMessage = null;
    });

    try {
      final result = await widget.controller.launchPrimaryKycFlow(
        locale: Localizations.localeOf(context),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = result.message;
      });

      if (result.shouldRefreshStatus) {
        Navigator.of(context).pop(true);
      }
    } on ConsumerApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = error.message;
      });
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'We could not open verification right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isRefreshing = true;
      _statusMessage = null;
    });

    try {
      await widget.controller.refreshKycStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Status refreshed.';
      });
    } on ConsumerApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
}

class _ReadinessLine extends StatelessWidget {
  const _ReadinessLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ResColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ResColors.mutedForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
