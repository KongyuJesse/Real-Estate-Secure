import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../features/consumer_flow/consumer_models.dart';
import '../app_icons.dart';
import '../brand.dart';

class ResSearchBar extends StatelessWidget {
  const ResSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search for land, houses...',
    this.onChanged,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: ResColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        boxShadow: ResShadows.card,
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            SolarIconsOutline.mapPointSearch,
            size: 22,
            color: ResColors.softForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ResColors.foreground,
                fontWeight: FontWeight.w600,
              ),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ResColors.softForeground,
                ),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (trailing != null) ...[
            Container(
              width: 1,
              height: 20,
              color: ResColors.outlineVariant.withValues(alpha: 0.35),
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            trailing!,
            const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

class ResNotificationButton extends StatelessWidget {
  const ResNotificationButton({super.key, required this.count, this.onPressed});

  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: ResColors.surfaceContainerLowest,
          shape: const CircleBorder(),
          shadowColor: const Color.fromRGBO(25, 28, 32, 0.12),
          elevation: 2,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(
                SolarIconsOutline.bell,
                color: ResColors.foreground,
                size: 22,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 11,
              height: 11,
              decoration: const BoxDecoration(
                color: ResColors.destructive,
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: ResColors.surfaceContainerLowest, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ConsumerBottomNavigationBar extends StatelessWidget {
  const ConsumerBottomNavigationBar({
    super.key,
    required this.role,
    required this.currentTab,
    required this.onTabSelected,
  });

  final String role;
  final ConsumerTab currentTab;
  final ValueChanged<ConsumerTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final items = _itemsForRole(role);
    final selectedIndex = items.indexWhere((item) => item.$1 == currentTab);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        bottomInset > 0 ? bottomInset : 14,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: ResShadows.floating,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: ResColors.glass,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                child: SizedBox(
                  height: 72,
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      final isSelected =
                          index == (selectedIndex < 0 ? 0 : selectedIndex);
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => onTabSelected(item.$1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 2,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? ResGradients.premiumButton
                                          : null,
                                      color: isSelected
                                          ? null
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Icon(
                                      item.$2,
                                      color: isSelected
                                          ? Colors.white
                                          : ResColors.softForeground,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.$3.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: isSelected
                                              ? ResColors.primary
                                              : ResColors.softForeground,
                                          fontSize: 9,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<(ConsumerTab, IconData, String)> _itemsForRole(String role) {
  if (isProfessionalRole(role)) {
    return <(ConsumerTab, IconData, String)>[
      (ConsumerTab.home, ResIcons.home, 'Home'),
      (ConsumerTab.finance, ResIcons.task, 'Cases'),
      (ConsumerTab.listings, ResIcons.listings, 'Market'),
      (ConsumerTab.map, ResIcons.map, 'Map'),
      (ConsumerTab.profile, ResIcons.profile, 'Profile'),
    ];
  }

  if (isSellerLikeRole(role)) {
    return <(ConsumerTab, IconData, String)>[
      (ConsumerTab.home, ResIcons.home, 'Home'),
      (ConsumerTab.listings, ResIcons.listings, 'Listings'),
      (ConsumerTab.finance, ResIcons.finance, 'Money'),
      (ConsumerTab.map, ResIcons.map, 'Map'),
      (ConsumerTab.profile, ResIcons.profile, 'Profile'),
    ];
  }

  return <(ConsumerTab, IconData, String)>[
    (ConsumerTab.home, ResIcons.home, 'Home'),
    (ConsumerTab.map, ResIcons.map, 'Map'),
    (ConsumerTab.listings, ResIcons.listings, 'Listings'),
    (ConsumerTab.finance, ResIcons.finance, 'Money'),
    (ConsumerTab.profile, ResIcons.profile, 'Profile'),
  ];
}
