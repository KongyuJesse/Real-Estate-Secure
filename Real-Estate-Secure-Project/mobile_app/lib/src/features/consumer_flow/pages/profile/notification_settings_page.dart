import 'package:flutter/material.dart';

import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';

class ConsumerNotificationSettingsPage extends StatefulWidget {
  const ConsumerNotificationSettingsPage({super.key, required this.controller});

  final ConsumerController controller;

  @override
  State<ConsumerNotificationSettingsPage> createState() =>
      _ConsumerNotificationSettingsPageState();
}

class _ConsumerNotificationSettingsPageState
    extends State<ConsumerNotificationSettingsPage> {
  ConsumerUserPreferences? _preferences;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
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
                                    'Notification settings',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Choose how the system reaches you for trust events, transactions, and product updates.',
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
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ResInfoChip(
                              label: _preferences!.pushNotificationsEnabled
                                  ? 'Push active'
                                  : 'Push quiet',
                              color: ResColors.primary,
                              icon: ResIcons.bell,
                            ),
                            ResInfoChip(
                              label: _preferences!.smsNotificationsEnabled
                                  ? 'SMS active'
                                  : 'SMS muted',
                              color: ResColors.accent,
                              icon: ResIcons.phone,
                            ),
                            ResInfoChip(
                              label: _preferences!.emailNotificationsEnabled
                                  ? 'Email active'
                                  : 'Email quiet',
                              color: Colors.white,
                              icon: Icons.alternate_email_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Set the communication mix that fits your security posture. Urgent milestones should stay reachable even when marketing is quiet.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: ResColors.mutedForeground),
                        ),
                        const SizedBox(height: 18),
                        _SettingsSection(
                          title: 'Channel routing',
                          subtitle:
                              'These toggles control the channels used for messages, listing activity, and secure transaction milestones.',
                          child: Column(
                            children: [
                              _switchTile(
                                context,
                                title: 'Email notifications',
                                subtitle:
                                    'Receive transaction, message, and account updates by email.',
                                value: _preferences!.emailNotificationsEnabled,
                                onChanged: (value) => _setPreferences(
                                  _preferences!.copyWith(
                                    emailNotificationsEnabled: value,
                                  ),
                                ),
                              ),
                              _switchTile(
                                context,
                                title: 'SMS alerts',
                                subtitle:
                                    'Use SMS for urgent reminders and transaction follow-ups.',
                                value: _preferences!.smsNotificationsEnabled,
                                onChanged: (value) => _setPreferences(
                                  _preferences!.copyWith(
                                    smsNotificationsEnabled: value,
                                  ),
                                ),
                              ),
                              _switchTile(
                                context,
                                title: 'Push notifications',
                                subtitle:
                                    'Stay updated from the mobile workspace in real time.',
                                value: _preferences!.pushNotificationsEnabled,
                                onChanged: (value) => _setPreferences(
                                  _preferences!.copyWith(
                                    pushNotificationsEnabled: value,
                                  ),
                                ),
                              ),
                              _switchTile(
                                context,
                                title: 'Marketing updates',
                                subtitle:
                                    'Receive product launches, boosts, and service offers.',
                                value:
                                    _preferences!.marketingNotificationsEnabled,
                                onChanged: (value) => _setPreferences(
                                  _preferences!.copyWith(
                                    marketingNotificationsEnabled: value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SettingsSection(
                          title: 'Preferred language',
                          subtitle:
                              'This locale is reused for notification copy where translated content exists.',
                          child: Row(
                            children: [
                              Expanded(
                                child: _LocaleChip(
                                  label: 'English',
                                  selected: _preferences!.locale == 'en',
                                  onTap: () => _setPreferences(
                                    _preferences!.copyWith(locale: 'en'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _LocaleChip(
                                  label: 'French',
                                  selected: _preferences!.locale == 'fr',
                                  onTap: () => _setPreferences(
                                    _preferences!.copyWith(locale: 'fr'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 16),
                          _NotificationStatusBanner(message: _statusMessage!),
                        ],
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: ResColors.background.withValues(alpha: 0.96),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(25, 28, 32, 0.06),
                          blurRadius: 24,
                          offset: Offset(0, -8),
                        ),
                      ],
                    ),
                    child: ResPrimaryButton(
                      label: 'Save preferences',
                      icon: ResIcons.check,
                      isBusy: _isSaving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ResColors.muted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ResColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final preferences = await widget.controller.loadPreferences();
    if (!mounted) {
      return;
    }
    setState(() {
      _preferences = preferences;
      _isLoading = false;
    });
  }

  void _setPreferences(ConsumerUserPreferences preferences) {
    setState(() {
      _preferences = preferences;
    });
  }

  Future<void> _save() async {
    if (_preferences == null) {
      return;
    }
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });
    try {
      await widget.controller.savePreferences(
        locale: _preferences!.locale,
        emailNotificationsEnabled: _preferences!.emailNotificationsEnabled,
        smsNotificationsEnabled: _preferences!.smsNotificationsEnabled,
        pushNotificationsEnabled: _preferences!.pushNotificationsEnabled,
        marketingNotificationsEnabled:
            _preferences!.marketingNotificationsEnabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Notification preferences updated.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
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

class _LocaleChip extends StatelessWidget {
  const _LocaleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? ResColors.primary.withValues(alpha: 0.08)
                : ResColors.muted,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? ResColors.primary : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected ? ResColors.primary : ResColors.foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationStatusBanner extends StatelessWidget {
  const _NotificationStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      color: ResColors.secondary.withValues(alpha: 0.08),
      radius: 22,
      shadow: const [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ResColors.secondary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(ResIcons.check, color: ResColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ResColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on ConsumerUserPreferences {
  ConsumerUserPreferences copyWith({
    String? locale,
    bool? emailNotificationsEnabled,
    bool? smsNotificationsEnabled,
    bool? pushNotificationsEnabled,
    bool? marketingNotificationsEnabled,
  }) => ConsumerUserPreferences(
    locale: locale ?? this.locale,
    emailNotificationsEnabled:
        emailNotificationsEnabled ?? this.emailNotificationsEnabled,
    smsNotificationsEnabled:
        smsNotificationsEnabled ?? this.smsNotificationsEnabled,
    pushNotificationsEnabled:
        pushNotificationsEnabled ?? this.pushNotificationsEnabled,
    marketingNotificationsEnabled:
        marketingNotificationsEnabled ?? this.marketingNotificationsEnabled,
  );
}
