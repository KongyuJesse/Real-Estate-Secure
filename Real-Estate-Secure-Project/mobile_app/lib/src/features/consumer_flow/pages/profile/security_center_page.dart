import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../data/consumer_api.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import 'verification_status_page.dart';

class ConsumerSecurityCenterPage extends StatefulWidget {
  const ConsumerSecurityCenterPage({
    super.key,
    required this.controller,
    required this.profile,
  });

  final ConsumerController controller;
  final ConsumerUserProfile profile;

  @override
  State<ConsumerSecurityCenterPage> createState() =>
      _ConsumerSecurityCenterPageState();
}

class _ConsumerSecurityCenterPageState extends State<ConsumerSecurityCenterPage>
    with WidgetsBindingObserver {
  bool _isEnrollingTwoFactor = false;
  bool _isUpdatingBiometric = false;
  bool _isUpdatingCameraPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshSecurityStateOnResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final profile = widget.controller.profile ?? widget.profile;
        final biometricCapability = widget.controller.biometricCapability;
        final biometricEnabled = widget.controller.biometricQuickUnlockEnabled;
        final cameraPermission = widget.controller.cameraPermissionStatus;
        final trustReady =
            profile.kycVerified &&
            profile.emailVerified &&
            profile.phoneVerified;
        final trustStatusLabel = trustReady
            ? 'All critical checks are complete for protected workflows.'
            : 'Finish contact verification and KYC before handling sensitive activity.';

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
                            'Security center',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage device protection, authenticator access, and trust posture.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: ResColors.mutedForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  trustStatusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ResColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 18),
                ResMenuTile(
                  icon: ResIcons.trust,
                  title: 'Verification status',
                  subtitle: profile.kycVerified
                      ? 'Review your verified account state, contact channels, and latest KYC result.'
                      : 'Open the verification center to complete email, phone, and identity checks.',
                  tint: trustReady ? ResColors.secondary : ResColors.primary,
                  onTap: _openVerificationCenter,
                ),
                const SizedBox(height: 18),
                ResSurfaceCard(
                  color: biometricEnabled
                      ? ResColors.primary.withValues(alpha: 0.05)
                      : ResColors.muted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: ResColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              ResIcons.fingerprint,
                              color: ResColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Device quick unlock',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  biometricEnabled
                                      ? 'This device can reopen the saved session with your biometric or secure screen lock.'
                                      : biometricCapability.summary,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ResColors.mutedForeground,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (biometricEnabled) ...[
                        ResPrimaryButton(
                          label: 'Test quick unlock',
                          icon: ResIcons.fingerprint,
                          isBusy: _isUpdatingBiometric,
                          onPressed: _isUpdatingBiometric
                              ? null
                              : _testBiometricQuickUnlock,
                        ),
                        const SizedBox(height: 10),
                        ResOutlineButton(
                          label: 'Disable quick unlock',
                          icon: ResIcons.fingerprint,
                          onPressed: _isUpdatingBiometric
                              ? null
                              : _disableBiometricQuickUnlock,
                        ),
                      ] else
                        ResPrimaryButton(
                          label: 'Enable quick unlock',
                          icon: ResIcons.fingerprint,
                          isBusy: _isUpdatingBiometric,
                          onPressed: biometricCapability.canAuthenticate
                              ? _enableBiometricQuickUnlock
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ResSurfaceCard(
                  color: cameraPermission.isGranted
                      ? ResColors.secondary.withValues(alpha: 0.06)
                      : ResColors.surfaceContainerLow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  (cameraPermission.isGranted
                                          ? ResColors.secondary
                                          : ResColors.primary)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.photo_camera_back_rounded,
                              color: cameraPermission.isGranted
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
                                  'Live capture permissions',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cameraPermission.isGranted
                                      ? 'Camera access is ready for KYC, listing media, and evidence capture.'
                                      : cameraPermission.summary,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ResColors.mutedForeground,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (cameraPermission.isGranted)
                        ResOutlineButton(
                          label: 'Refresh camera status',
                          icon: Icons.refresh_rounded,
                          onPressed: _isUpdatingCameraPermission
                              ? null
                              : _refreshCameraPermission,
                        )
                      else if (cameraPermission.requiresSettings)
                        ResOutlineButton(
                          label: 'Open app settings',
                          icon: ResIcons.settings,
                          onPressed: _isUpdatingCameraPermission
                              ? null
                              : _openPermissionSettings,
                        )
                      else
                        ResPrimaryButton(
                          label: 'Allow camera access',
                          icon: Icons.photo_camera_back_rounded,
                          isBusy: _isUpdatingCameraPermission,
                          onPressed: _requestCameraAccess,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ResSurfaceCard(
                  color: profile.twoFactorEnabled
                      ? ResColors.secondary.withValues(alpha: 0.06)
                      : ResColors.muted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  (profile.twoFactorEnabled
                                          ? ResColors.secondary
                                          : ResColors.primary)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              profile.twoFactorEnabled
                                  ? Icons.verified_user_rounded
                                  : Icons.security_rounded,
                              color: profile.twoFactorEnabled
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
                                  'Authenticator protection',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profile.twoFactorEnabled
                                      ? 'Two-factor authentication is enabled.'
                                      : 'Set up a TOTP authenticator app to harden account access.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: ResColors.mutedForeground,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (profile.twoFactorEnabled)
                        const ResOutlineButton(
                          label: 'Authenticator active',
                          icon: Icons.check_circle_rounded,
                        )
                      else
                        ResPrimaryButton(
                          label: 'Enable two-factor authentication',
                          icon: Icons.lock_person_rounded,
                          isBusy: _isEnrollingTwoFactor,
                          onPressed: _startTwoFactorEnrollment,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startTwoFactorEnrollment() async {
    setState(() => _isEnrollingTwoFactor = true);
    try {
      final setup = await widget.controller.beginTwoFactorEnrollment();
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => _TwoFactorEnrollmentDialog(
          controller: widget.controller,
          setup: setup,
        ),
      );
    } on ConsumerApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _isEnrollingTwoFactor = false);
      }
    }
  }

  Future<void> _enableBiometricQuickUnlock() async {
    setState(() => _isUpdatingBiometric = true);
    try {
      final enabled = await widget.controller.enableBiometricQuickUnlock();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Device quick unlock is now enabled for this secure session.'
                : 'Quick unlock could not be enabled on this device.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingBiometric = false);
      }
    }
  }

  Future<void> _disableBiometricQuickUnlock() async {
    setState(() => _isUpdatingBiometric = true);
    try {
      await widget.controller.disableBiometricQuickUnlock();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device quick unlock has been disabled.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingBiometric = false);
      }
    }
  }

  Future<void> _testBiometricQuickUnlock() async {
    setState(() => _isUpdatingBiometric = true);
    try {
      final unlocked = await widget.controller.authenticateDeviceBiometric(
        reason: 'Confirm your quick unlock setup for this device.',
        subtitle: 'Use your biometric or secure screen lock',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unlocked
                ? 'Quick unlock is working on this device.'
                : 'Quick unlock was cancelled before completion.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingBiometric = false);
      }
    }
  }

  Future<void> _refreshCameraPermission() async {
    setState(() => _isUpdatingCameraPermission = true);
    try {
      await widget.controller.refreshCameraPermissionStatus();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.cameraPermissionStatus.summary),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingCameraPermission = false);
      }
    }
  }

  Future<void> _requestCameraAccess() async {
    setState(() => _isUpdatingCameraPermission = true);
    try {
      await widget.controller.ensureCameraPermission();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.cameraPermissionStatus.summary),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingCameraPermission = false);
      }
    }
  }

  Future<void> _openPermissionSettings() async {
    setState(() => _isUpdatingCameraPermission = true);
    try {
      final opened = await widget.controller.openSystemPermissionSettings();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'App settings opened. Update camera access there and return to refresh the secure capture flow.'
                : 'App settings could not be opened on this device.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingCameraPermission = false);
      }
    }
  }

  Future<void> _openVerificationCenter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ConsumerVerificationStatusPage(controller: widget.controller),
      ),
    );
  }

  Future<void> _refreshSecurityStateOnResume() async {
    await widget.controller.loadBiometricState();
    await widget.controller.refreshCameraPermissionStatus();
  }
}

class _TwoFactorEnrollmentDialog extends StatefulWidget {
  const _TwoFactorEnrollmentDialog({
    required this.controller,
    required this.setup,
  });

  final ConsumerController controller;
  final ConsumerTwoFactorSetup setup;

  @override
  State<_TwoFactorEnrollmentDialog> createState() =>
      _TwoFactorEnrollmentDialogState();
}

class _TwoFactorEnrollmentDialogState
    extends State<_TwoFactorEnrollmentDialog> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enable two-factor authentication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add the following secret to your authenticator app, then enter the current verification code to activate two-factor protection.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ResColors.muted,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SelectableText(
                widget.setup.secret,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontFamily: 'RobotoMono'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Issuer: ${widget.setup.issuer} • ${widget.setup.digits} digits • ${widget.setup.periodSec}s period',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Authenticator code',
                prefixIcon: Icon(Icons.security_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: ResColors.destructive),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _confirm,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Activate'),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() {
        _error = 'Enter the current code from your authenticator app.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await widget.controller.confirmTwoFactorEnrollment(code);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Two-factor authentication is now enabled.'),
        ),
      );
    } on ConsumerApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
