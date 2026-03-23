import 'package:flutter/material.dart';

import '../../../ui/app_icons.dart';
import '../../../ui/brand.dart';
import '../../../ui/components/avatar.dart';
import '../../../ui/components/buttons.dart';
import '../../../ui/components/cards.dart';
import '../../../ui/components/page_sections.dart';
import '../consumer_controller.dart';

class ConsumerBiometricUnlockPage extends StatefulWidget {
  const ConsumerBiometricUnlockPage({
    super.key,
    required this.controller,
    required this.onUseAnotherAccount,
  });

  final ConsumerController controller;
  final Future<void> Function() onUseAnotherAccount;

  @override
  State<ConsumerBiometricUnlockPage> createState() =>
      _ConsumerBiometricUnlockPageState();
}

class _ConsumerBiometricUnlockPageState
    extends State<ConsumerBiometricUnlockPage> {
  bool _isSwitchingAccount = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final session = widget.controller.session;
        final capability = widget.controller.biometricCapability;
        final displayName = session.fullName.trim().isNotEmpty
            ? session.fullName.trim()
            : 'Secure workspace';
        final destination = session.email.trim().isNotEmpty
            ? session.email.trim()
            : 'Saved session';

        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: ResGradients.heroPanel),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            ResHeroPanel(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                24,
                                22,
                                24,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 132,
                                    height: 132,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.10,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    child: Center(
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 86,
                                            height: 86,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: ResShadows.card,
                                            ),
                                            child: const Icon(
                                              ResIcons.fingerprint,
                                              size: 38,
                                              color: ResColors.primary,
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 8,
                                            child: ResAvatar(
                                              name: displayName,
                                              imageUrl:
                                                  widget
                                                      .controller
                                                      .profile
                                                      ?.resolvedAvatarUrl ??
                                                  '',
                                              size: 40,
                                              borderColor: Colors.white,
                                              backgroundColor:
                                                  ResColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Unlock workspace',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Use your biometric or device screen lock to continue.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.86,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            ResSurfaceCard(
                              radius: 28,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      ResAvatar(
                                        name: displayName,
                                        imageUrl:
                                            widget
                                                .controller
                                                .profile
                                                ?.resolvedAvatarUrl ??
                                            '',
                                        size: 48,
                                        backgroundColor: ResColors.primary,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              destination,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        ResColors
                                                            .mutedForeground,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ResColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: ResColors.primary.withValues(
                                              alpha: 0.10,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            ResIcons.secure,
                                            color: ResColors.primary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            capability.summary,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      ResColors
                                                          .mutedForeground,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ResPrimaryButton(
                      label: 'Unlock securely',
                      icon: ResIcons.fingerprint,
                      isBusy: widget.controller.isProcessingBiometric,
                      isPill: true,
                      onPressed: _unlock,
                    ),
                    const SizedBox(height: 12),
                    ResOutlineButton(
                      label: 'Use another account',
                      icon: ResIcons.logout,
                      isPill: true,
                      onPressed: _isSwitchingAccount ? null : _useAnotherAccount,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _unlock() async {
    final unlocked = await widget.controller.unlockWithBiometric();
    if (!mounted || unlocked) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Authentication was not completed. Please try again.'),
      ),
    );
  }

  Future<void> _useAnotherAccount() async {
    setState(() => _isSwitchingAccount = true);
    try {
      await widget.onUseAnotherAccount();
    } finally {
      if (mounted) {
        setState(() => _isSwitchingAccount = false);
      }
    }
  }
}
