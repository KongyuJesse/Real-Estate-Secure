import 'package:flutter/material.dart';

import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/avatar.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/navigation.dart';
import '../../../../ui/components/page_sections.dart';
import '../../widgets/free_tier_ad_slot.dart';

class ConsumerHomeTab extends StatelessWidget {
  const ConsumerHomeTab({
    super.key,
    required this.controller,
    required this.searchController,
    required this.onOpenNotifications,
    required this.onOpenProperty,
    required this.onOpenListingStudio,
    required this.onOpenSubscriptionCenter,
    required this.onOpenTask,
  });

  final ConsumerController controller;
  final TextEditingController searchController;
  final VoidCallback onOpenNotifications;
  final ValueChanged<String> onOpenProperty;
  final VoidCallback onOpenListingStudio;
  final VoidCallback onOpenSubscriptionCenter;
  final ValueChanged<ConsumerTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final actions = _actionsForRole(
      controller,
      onOpenListingStudio: onOpenListingStudio,
      onOpenSubscriptionCenter: onOpenSubscriptionCenter,
    );
    final tasks = controller.tasks.take(2).toList(growable: false);
    final displayName = profile?.firstName.trim().isNotEmpty == true
        ? profile!.firstName.trim()
        : controller.isAuthenticated
        ? 'Secure user'
        : 'Guest';
    final quickActions = [
      ...actions.primary,
      if (actions.secondary.isNotEmpty) actions.secondary.first,
    ];
    final contextLine = !controller.isAuthenticated
        ? 'Search secure listings across Cameroon.'
        : profile?.kycVerified == true
        ? 'Your trusted property workspace is ready.'
        : 'Complete verification to unlock every protected action.';

    return RefreshIndicator(
      onRefresh: controller.refreshMarketplace,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: ResSearchBar(
                  controller: searchController,
                  hintText: 'Search for land, houses...',
                  onChanged: controller.updateSearch,
                ),
              ),
              const SizedBox(width: 10),
              ResNotificationButton(
                count: controller.unreadNotificationCount,
                onPressed: onOpenNotifications,
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => controller.setTab(ConsumerTab.profile),
                child: ResAvatar(
                  name: profile?.displayName ?? 'Guest',
                  imageUrl: profile?.resolvedAvatarUrl ?? '',
                  size: 48,
                  borderColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome, $displayName',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            contextLine,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ResColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          const ResSectionHeader(title: 'Quick access'),
          const SizedBox(height: 14),
          Row(
            children: List.generate(quickActions.length, (index) {
              final action = quickActions[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == quickActions.length - 1 ? 0 : 10,
                  ),
                  child: ResActionTile(
                    label: action.label,
                    icon: action.icon,
                    tint: action.tint,
                    compact: true,
                    onTap: action.onTap,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          ConsumerFreeTierAdSlot(
            controller: controller,
            placement: 'home feed',
          ),
          const SizedBox(height: 28),
          ResSectionHeader(
            title: 'Featured properties',
            action: TextButton(
              onPressed: () => controller.setTab(ConsumerTab.listings),
              child: const Text('See all'),
            ),
          ),
          const SizedBox(height: 14),
          if (controller.isCatalogLoading &&
              controller.featuredProperties.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 338,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: controller.featuredProperties.length,
                separatorBuilder: (_, _) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final property = controller.featuredProperties[index];
                  return ResPropertyCard(
                    property: property,
                    onTap: () => onOpenProperty(property.id),
                  );
                },
              ),
            ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 28),
            const ResSectionHeader(title: 'Priority focus'),
            const SizedBox(height: 12),
            ResSurfaceCard(
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...tasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ResTaskTile(
                        task: task,
                        onTap: () => onOpenTask(task),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeLayout {
  const _HomeLayout({required this.primary, required this.secondary});

  final List<_HomeAction> primary;
  final List<_HomeAction> secondary;
}

class _HomeAction {
  const _HomeAction({
    required this.label,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
}

_HomeLayout _actionsForRole(
  ConsumerController controller, {
  required VoidCallback onOpenListingStudio,
  required VoidCallback onOpenSubscriptionCenter,
}) {
  if (controller.isProfessionalUser) {
    return _HomeLayout(
      primary: [
        _HomeAction(
          label: 'Case Desk',
          icon: ResIcons.task,
          tint: ResColors.primary,
          onTap: () => controller.setTab(ConsumerTab.finance),
        ),
        _HomeAction(
          label: 'Market Watch',
          icon: ResIcons.listings,
          tint: ResColors.secondary,
          onTap: () => controller.setTab(ConsumerTab.listings),
        ),
      ],
      secondary: [
        _HomeAction(
          label: 'Profile',
          icon: ResIcons.profile,
          tint: ResColors.primary,
          onTap: () => controller.setTab(ConsumerTab.profile),
        ),
      ],
    );
  }

  if (controller.isSellerLike) {
    return _HomeLayout(
      primary: [
        _HomeAction(
          label: 'Studio',
          icon: ResIcons.personAdd,
          tint: ResColors.primary,
          onTap: onOpenListingStudio,
        ),
        _HomeAction(
          label: 'Listings',
          icon: ResIcons.listings,
          tint: ResColors.secondary,
          onTap: () => controller.setTab(ConsumerTab.listings),
        ),
      ],
      secondary: [
        _HomeAction(
          label: 'Plans',
          icon: ResIcons.membership,
          tint: ResColors.info,
          onTap: onOpenSubscriptionCenter,
        ),
      ],
    );
  }

  return _HomeLayout(
    primary: [
      _HomeAction(
        label: 'Rent',
        icon: ResIcons.rent,
        tint: ResColors.primary,
        onTap: () => controller.applyFilter(listingType: 'rent'),
      ),
      _HomeAction(
        label: 'Map',
        icon: ResIcons.map,
        tint: ResColors.secondary,
        onTap: () => controller.setTab(ConsumerTab.map),
      ),
    ],
    secondary: [
      _HomeAction(
        label: 'Profile',
        icon: ResIcons.profile,
        tint: ResColors.info,
        onTap: () => controller.setTab(ConsumerTab.profile),
      ),
    ],
  );
}
