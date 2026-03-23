import 'package:flutter/material.dart';

import '../../consumer_controller.dart';
import '../../consumer_models.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/dimensions.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/page_sections.dart';
import '../../widgets/free_tier_ad_slot.dart';

class ConsumerListingsTab extends StatelessWidget {
  const ConsumerListingsTab({
    super.key,
    required this.controller,
    required this.onOpenProperty,
    required this.onOpenListingStudio,
  });

  final ConsumerController controller;
  final ValueChanged<String> onOpenProperty;
  final VoidCallback onOpenListingStudio;

  @override
  Widget build(BuildContext context) {
    final listings = controller.visibleListings;
    final title = controller.isSellerLike
        ? 'Listings'
        : controller.isProfessionalUser
        ? 'Market watch'
        : 'Verified listings';
    final subtitle = controller.isSellerLike
        ? 'Manage your inventory and market view.'
        : controller.isProfessionalUser
        ? 'Track listings tied to active work.'
        : 'Browse secure listings across Cameroon.';
    return ListView(
      padding: ResPadding.page.copyWith(bottom: 140),
      children: [
        ResPageHeader(eyebrow: 'Listings', title: title, subtitle: subtitle),
        const SizedBox(height: ResSpacing.xxxl),
        Wrap(
          spacing: ResSpacing.sm,
          runSpacing: ResSpacing.sm,
          children: [
            ResInfoChip(
              label: '${listings.length} results',
              color: ResColors.primary,
              icon: ResIcons.listings,
            ),
            if (controller.propertyTypeFilter != null)
              ResInfoChip(
                label: startCase(controller.propertyTypeFilter!),
                color: ResColors.accent,
                icon: ResIcons.propertyType(controller.propertyTypeFilter!),
              ),
            if (controller.listingTypeFilter != null)
              ResInfoChip(
                label: startCase(controller.listingTypeFilter!),
                color: ResColors.secondary,
                icon: ResIcons.listingType(controller.listingTypeFilter!),
              ),
          ],
        ),
        if (controller.isSellerLike) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: ResOutlineButton(
              label: 'Create property',
              icon: ResIcons.personAdd,
              isPill: true,
              onPressed: onOpenListingStudio,
            ),
          ),
        ],
        const SizedBox(height: 18),
        ConsumerFreeTierAdSlot(
          controller: controller,
          placement: 'listings feed',
        ),
        const SizedBox(height: ResSpacing.xl),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _ListingsChip(
                label: 'All',
                selected:
                    controller.propertyTypeFilter == null &&
                    controller.listingTypeFilter == null,
                onTap: controller.clearFilters,
              ),
              const SizedBox(width: ResSpacing.sm),
              _ListingsChip(
                label: 'Land',
                selected: controller.propertyTypeFilter == 'land',
                onTap: () => controller.applyFilter(propertyType: 'land'),
              ),
              const SizedBox(width: ResSpacing.sm),
              _ListingsChip(
                label: 'Houses',
                selected: controller.propertyTypeFilter == 'house',
                onTap: () => controller.applyFilter(propertyType: 'house'),
              ),
              const SizedBox(width: ResSpacing.sm),
              _ListingsChip(
                label: 'Rent',
                selected: controller.listingTypeFilter == 'rent',
                onTap: () => controller.applyFilter(listingType: 'rent'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ResSectionHeader(
          title: 'Available properties',
          action: ResGhostButton(
            label: controller.isSellerLike ? 'Seller studio' : 'Clear filters',
            icon: controller.isSellerLike
                ? ResIcons.personAdd
                : Icons.filter_alt_off_rounded,
            onPressed: controller.isSellerLike
                ? onOpenListingStudio
                : controller.clearFilters,
          ),
        ),
        const SizedBox(height: 14),
        if (listings.isEmpty)
          ResSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No listings match this view',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Clear filters or widen the search.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ResColors.mutedForeground,
                  ),
                ),
              ],
            ),
          )
        else
          ...listings.map(
            (property) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ResPropertyCard(
                property: property,
                fullWidth: true,
                onTap: () => onOpenProperty(property.id),
              ),
            ),
          ),
        if (controller.hasMoreListings) ...[
          const SizedBox(height: 8),
          Center(
            child: ResOutlineButton(
              label: controller.isLoadingMoreListings
                  ? 'Loading more...'
                  : 'Load more listings',
              icon: ResIcons.arrowRight,
              onPressed: controller.isLoadingMoreListings
                  ? null
                  : controller.loadMoreListings,
            ),
          ),
        ],
      ],
    );
  }
}

class _ListingsChip extends StatelessWidget {
  const _ListingsChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: ResColors.primary,
      backgroundColor: ResColors.card,
      side: BorderSide(color: selected ? ResColors.primary : ResColors.border),
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: selected ? Colors.white : ResColors.foreground,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
