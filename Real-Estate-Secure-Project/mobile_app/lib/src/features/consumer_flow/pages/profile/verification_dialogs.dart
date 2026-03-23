import 'package:flutter/material.dart';

import '../../../../data/consumer_api.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../consumer_controller.dart';
import '../../consumer_models.dart';

Future<bool?> showConsumerEmailVerificationDialog({
  required BuildContext context,
  required ConsumerController controller,
  ConsumerUserProfile? profile,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _SumsubVerificationDialog(
      controller: controller,
      profile: profile,
      channel: 'email',
    ),
  );
}

Future<bool?> showConsumerPhoneVerificationDialog({
  required BuildContext context,
  required ConsumerController controller,
  required ConsumerUserProfile profile,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _SumsubVerificationDialog(
      controller: controller,
      profile: profile,
      channel: 'phone',
    ),
  );
}

class _SumsubVerificationDialog extends StatefulWidget {
  const _SumsubVerificationDialog({
    required this.controller,
    required this.channel,
    this.profile,
  });

  final ConsumerController controller;
  final ConsumerUserProfile? profile;
  final String channel;

  @override
  State<_SumsubVerificationDialog> createState() =>
      _SumsubVerificationDialogState();
}

class _SumsubVerificationDialogState extends State<_SumsubVerificationDialog> {
  bool _isLaunching = false;
  String? _message;

  bool get _isEmail => widget.channel == 'email';

  ConsumerUserProfile? get _profile =>
      widget.controller.profile ?? widget.profile;

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final destination = _isEmail
        ? profile?.email.trim() ?? ''
        : profile?.phoneNumber.trim() ?? '';
    final alreadyVerified = _isEmail
        ? profile?.emailVerified == true
        : profile?.phoneVerified == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ResSurfaceCard(
        padding: const EdgeInsets.all(20),
        radius: 30,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ResColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _isEmail ? ResIcons.trust : ResIcons.phone,
                    color: ResColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEmail ? 'Verify email' : 'Verify phone',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alreadyVerified
                            ? 'This contact channel is already confirmed.'
                            : 'Confirm this contact detail to keep your profile trusted.',
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
            ResSurfaceCard(
              color: ResColors.surfaceContainerLow,
              radius: 22,
              shadow: const [],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEmail ? 'Email address' : 'Phone number',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: ResColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    destination.isEmpty ? 'Missing from profile' : destination,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              _DialogMessage(message: _message!),
            ],
            const SizedBox(height: 18),
            ResPrimaryButton(
              label: alreadyVerified
                  ? 'Done'
                  : (_isEmail ? 'Verify email' : 'Verify phone'),
              icon: _isEmail ? ResIcons.trust : ResIcons.phone,
              isBusy: _isLaunching,
              onPressed: alreadyVerified ? _closeVerified : _launch,
            ),
            const SizedBox(height: 10),
            ResOutlineButton(
              label: 'Close',
              icon: ResIcons.back,
              onPressed: _isLaunching
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launch() async {
    setState(() {
      _isLaunching = true;
      _message = null;
    });

    try {
      final result = await widget.controller.launchContactVerificationFlow(
        channel: widget.channel,
        locale: Localizations.localeOf(context),
      );
      if (!mounted) {
        return;
      }

      final refreshedProfile = _profile;
      final verified = _isEmail
          ? refreshedProfile?.emailVerified == true
          : refreshedProfile?.phoneVerified == true;

      if (verified || result.shouldRefreshStatus) {
        Navigator.of(context).pop(true);
        return;
      }

      setState(() {
        _message = result.message;
      });
    } on ConsumerApiFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }
  }

  void _closeVerified() {
    Navigator.of(context).pop(true);
  }
}

class _DialogMessage extends StatelessWidget {
  const _DialogMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(ResIcons.secure, size: 18, color: ResColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
