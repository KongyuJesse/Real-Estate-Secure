import 'package:flutter/material.dart';

import '../../../ui/app_icons.dart';
import '../../../ui/brand.dart';
import '../../../ui/components/buttons.dart';
import '../../../ui/components/cards.dart';
import '../consumer_controller.dart';

Future<bool> ensureConsumerAuthenticatedAccess(
  BuildContext context, {
  required ConsumerController controller,
  required String title,
  required String message,
  String primaryActionLabel = 'Login',
}) async {
  if (controller.isAuthenticated) {
    return true;
  }

  final decision = await showModalBottomSheet<_GuestAccessDecision>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _GuestAccessSheet(
      title: title,
      message: message,
      primaryActionLabel: primaryActionLabel,
    ),
  );

  if (!context.mounted) {
    return false;
  }

  switch (decision) {
    case _GuestAccessDecision.login:
      controller.openLogin();
      return false;
    case _GuestAccessDecision.register:
      controller.openRegister();
      return false;
    case _GuestAccessDecision.continueGuest:
    case null:
      return false;
  }
}

enum _GuestAccessDecision { login, register, continueGuest }

class _GuestAccessSheet extends StatelessWidget {
  const _GuestAccessSheet({
    required this.title,
    required this.message,
    required this.primaryActionLabel,
  });

  final String title;
  final String message;
  final String primaryActionLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResSurfaceCard(
              radius: 28,
              color: ResColors.surfaceContainerLow,
              shadow: const [],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      ResInfoChip(
                        label: 'Guest mode',
                        color: ResColors.primary,
                        icon: ResIcons.profile,
                      ),
                      ResInfoChip(
                        label: 'Protected action',
                        color: ResColors.tertiary,
                        icon: ResIcons.secure,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ResColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ResPrimaryButton(
              label: primaryActionLabel,
              icon: ResIcons.arrowRight,
              isPill: true,
              onPressed: () =>
                  Navigator.of(context).pop(_GuestAccessDecision.login),
            ),
            const SizedBox(height: 10),
            ResOutlineButton(
              label: 'Register',
              isPill: true,
              onPressed: () =>
                  Navigator.of(context).pop(_GuestAccessDecision.register),
            ),
            const SizedBox(height: 8),
            Center(
              child: ResGhostButton(
                label: 'Remain as guest',
                onPressed: () => Navigator.of(
                  context,
                ).pop(_GuestAccessDecision.continueGuest),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
