import 'package:flutter/material.dart';

import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import '../profile/account_information_page.dart';
import '../profile/notification_settings_page.dart';
import '../profile/saved_properties_page.dart';
import '../profile/security_center_page.dart';
import '../profile/verification_status_page.dart';
import '../workspace/listing_studio_page.dart';
import '../workspace/subscription_center_page.dart';
import '../workspace/transactions_page.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/avatar.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../widgets/free_tier_ad_slot.dart';

class ConsumerProfileTab extends StatefulWidget {
  const ConsumerProfileTab({super.key, required this.controller});

  final ConsumerController controller;

  @override
  State<ConsumerProfileTab> createState() => _ConsumerProfileTabState();
}

class _ConsumerProfileTabState extends State<ConsumerProfileTab>
    with WidgetsBindingObserver {
  late Future<ConsumerCurrentSubscription?> _subscriptionFuture;
  late String _subscriptionRefreshKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_handleControllerChanged);
    _subscriptionRefreshKey = _buildSubscriptionRefreshKey();
    _subscriptionFuture = widget.controller.loadCurrentSubscription();
  }

  @override
  void didUpdateWidget(covariant ConsumerProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _subscriptionRefreshKey = _buildSubscriptionRefreshKey();
    _subscriptionFuture = widget.controller.loadCurrentSubscription();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _subscriptionRefreshKey = _buildSubscriptionRefreshKey();
        _subscriptionFuture = widget.controller.loadCurrentSubscription();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.profile;

    return FutureBuilder<ConsumerCurrentSubscription?>(
      future: _subscriptionFuture,
      builder: (context, snapshot) {
        final subscription = snapshot.data;

        if (!widget.controller.isAuthenticated) {
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _subscriptionFuture = widget.controller
                    .loadCurrentSubscription();
              });
              await widget.controller.loadCatalog(reset: true);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                const _GuestProfileHero(),
                const SizedBox(height: 18),
                ResSurfaceCard(
                  radius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlock your secure account',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an account to save properties and unlock secure tools.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ResColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ResPrimaryButton(
                        label: 'Login',
                        icon: ResIcons.arrowRight,
                        isPill: true,
                        onPressed: widget.controller.openLogin,
                      ),
                      const SizedBox(height: 10),
                      ResOutlineButton(
                        label: 'Register',
                        isPill: true,
                        onPressed: widget.controller.openRegister,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ConsumerFreeTierAdSlot(
                  controller: widget.controller,
                  placement: 'guest profile',
                ),
                const SizedBox(height: 18),
                ResMenuTile(
                  icon: ResIcons.membership,
                  title: 'Plans & billing',
                  subtitle: 'Compare available tiers.',
                  tint: ResColors.secondary,
                  onTap: () => _openPage(
                    ConsumerSubscriptionCenterPage(
                      controller: widget.controller,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ResMenuTile(
                  icon: ResIcons.trust,
                  title: 'Verification flow',
                  subtitle: 'Email, phone, and identity checks.',
                  tint: ResColors.tertiary,
                ),
                const SizedBox(height: 12),
                ResMenuTile(
                  icon: ResIcons.security,
                  title: 'Security center',
                  subtitle: 'Quick unlock and two-factor protection.',
                  tint: ResColors.info,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _subscriptionFuture = widget.controller.loadCurrentSubscription();
            });
            await widget.controller.refreshMarketplace();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              _ProfileHero(controller: widget.controller, profile: profile),
              const SizedBox(height: 18),
              _AccountCard(profile: profile),
              const SizedBox(height: 18),
              _SubscriptionCard(
                subscription: subscription,
                onTap: () => _openPage(
                  ConsumerSubscriptionCenterPage(controller: widget.controller),
                ),
              ),
              const SizedBox(height: 18),
              const ResSectionHeader(title: 'Management'),
              const SizedBox(height: 12),
              ResMenuTile(
                icon: ResIcons.profile,
                title: 'Account Information',
                subtitle: 'Personal details and language.',
                tint: ResColors.primary,
                onTap: profile == null
                    ? null
                    : () => _openPage(
                        ConsumerAccountInformationPage(
                          controller: widget.controller,
                          profile: profile,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              ResMenuTile(
                icon: ResIcons.trust,
                title: 'Verification & KYC',
                subtitle: 'Status and identity checks.',
                tint: profile?.kycVerified == true
                    ? ResColors.secondary
                    : ResColors.tertiary,
                trailingLabel: profile?.kycVerified == true
                    ? 'Verified'
                    : startCase(profile?.kycStatus ?? 'pending'),
                onTap: () => _openPage(
                  ConsumerVerificationStatusPage(controller: widget.controller),
                ),
              ),
              const SizedBox(height: 12),
              ResMenuTile(
                icon: ResIcons.security,
                title: 'Security Center',
                subtitle: 'Quick unlock and MFA.',
                tint: profile?.twoFactorEnabled == true
                    ? ResColors.secondary
                    : ResColors.info,
                onTap: profile == null
                    ? null
                    : () => _openPage(
                        ConsumerSecurityCenterPage(
                          controller: widget.controller,
                          profile: profile,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              ResMenuTile(
                icon: ResIcons.bell,
                title: 'Notifications',
                subtitle: 'Email, SMS, push, and marketing.',
                tint: ResColors.info,
                onTap: () => _openPage(
                  ConsumerNotificationSettingsPage(
                    controller: widget.controller,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ResMenuTile(
                icon: ResIcons.favorite,
                title: 'Saved Properties',
                subtitle: 'Your shortlisted properties.',
                tint: ResColors.tertiary,
                trailingLabel: '${widget.controller.savedProperties.length}',
                onTap: () => _openPage(
                  ConsumerSavedPropertiesPage(controller: widget.controller),
                ),
              ),
              const SizedBox(height: 12),
              ResMenuTile(
                icon: ResIcons.receipt,
                title: 'Transaction History',
                subtitle: 'Timeline and transaction files.',
                tint: ResColors.primary,
                onTap: () => _openPage(
                  ConsumerTransactionsPage(controller: widget.controller),
                ),
              ),
              if (widget.controller.isSellerLike) ...[
                const SizedBox(height: 12),
                ResMenuTile(
                  icon: ResIcons.listings,
                  title: 'Listing Studio',
                  subtitle: 'Create and submit listings.',
                  tint: ResColors.tertiary,
                  trailingLabel: 'Open',
                  onTap: () => _openPage(
                    ConsumerListingStudioPage(controller: widget.controller),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ConsumerFreeTierAdSlot(
                controller: widget.controller,
                placement: 'profile summary',
              ),
              const SizedBox(height: 18),
              ResSurfaceCard(
                color: ResColors.surfaceContainerLow,
                radius: 24,
                shadow: const [],
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign out from this device when you finish.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ResOutlineButton(
                      label: 'Logout',
                      icon: ResIcons.logout,
                      isPill: true,
                      onPressed: widget.controller.logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  String _buildSubscriptionRefreshKey() {
    return [
      widget.controller.isAuthenticated,
      widget.controller.session.userUuid,
      widget.controller.primaryRole,
    ].join('|');
  }

  void _handleControllerChanged() {
    final nextKey = _buildSubscriptionRefreshKey();
    if (_subscriptionRefreshKey == nextKey || !mounted) {
      return;
    }
    setState(() {
      _subscriptionRefreshKey = nextKey;
      _subscriptionFuture = widget.controller.loadCurrentSubscription();
    });
  }
}

class _GuestProfileHero extends StatelessWidget {
  const _GuestProfileHero();

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      radius: 28,
      child: Column(
        children: [
          const ResAvatar(
            name: 'Guest',
            imageUrl: '',
            size: 108,
            borderColor: Colors.white,
            backgroundColor: ResColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Guest mode',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const ResInfoChip(
            label: 'Public discovery only',
            color: ResColors.tertiary,
            icon: ResIcons.trust,
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              ResInfoChip(
                label: 'Plans visible',
                color: ResColors.primary,
                icon: ResIcons.membership,
              ),
              ResInfoChip(
                label: 'Trust tools locked',
                color: ResColors.info,
                icon: ResIcons.security,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.controller, required this.profile});

  final ConsumerController controller;
  final ConsumerUserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final displayName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName
        : 'Secure workspace';
    final isVerified = profile?.kycVerified == true;
    final badgeColor = isVerified ? ResColors.secondary : ResColors.tertiary;
    final subtitle = isVerified
        ? 'KYC verified'
        : startCase(profile?.kycStatus ?? 'verification in progress');

    return ResSurfaceCard(
      radius: 28,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ResAvatar(
                name: displayName,
                imageUrl: profile?.resolvedAvatarUrl ?? '',
                size: 108,
                borderColor: Colors.white,
                backgroundColor: ResColors.primary,
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    isVerified ? ResIcons.check : Icons.schedule_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          ResInfoChip(
            label: subtitle,
            color: profile?.kycVerified == true
                ? ResColors.secondary
                : ResColors.tertiary,
            icon: ResIcons.trust,
          ),
          const SizedBox(height: 14),
          Text(
            controller.biometricQuickUnlockEnabled
                ? 'Quick unlock is enabled on this device.'
                : profile?.twoFactorEnabled == true
                ? 'Account protection is active.'
                : 'Enable quick unlock and two-factor authentication when you are ready.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.profile});

  final ConsumerUserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account details',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: ResColors.softForeground),
          ),
          const SizedBox(height: 14),
          _AccountRow(
            icon: ResIcons.identity,
            label: 'Primary role',
            value: consumerRoleLabel(profile?.resolvedPrimaryRole ?? 'buyer'),
          ),
          const SizedBox(height: 14),
          _AccountRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email address',
            value: profile?.email.trim().isNotEmpty == true
                ? profile!.email
                : 'Not available',
          ),
          const SizedBox(height: 14),
          _AccountRow(
            icon: ResIcons.phone,
            label: 'Phone number',
            value: profile?.phoneNumber.trim().isNotEmpty == true
                ? profile!.phoneNumber
                : 'Not available',
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: ResColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: ResColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ResColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription, required this.onTap});

  final ConsumerCurrentSubscription? subscription;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ResSurfaceCard(
      radius: 26,
      color: ResColors.surfaceContainerLowest,
      shadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT PLAN',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: ResColors.softForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subscription?.planName ?? 'Starter',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              Icon(
                ResIcons.membership,
                color: subscription == null
                    ? ResColors.softForeground
                    : ResColors.secondary,
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SubscriptionMetric(
                  label: 'Expires',
                  value: subscription?.endDate == null
                      ? 'Open'
                      : _formatDate(subscription!.endDate!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SubscriptionMetric(
                  label: 'Capacity',
                  value: '${subscription?.maxListings ?? 1} listings',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ResOutlineButton(
            label: 'Manage plan',
            icon: ResIcons.arrowRight,
            isPill: true,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _SubscriptionMetric extends StatelessWidget {
  const _SubscriptionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ResColors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
