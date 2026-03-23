import 'package:flutter/material.dart';

import '../../consumer_controller.dart';
import '../property_details_page.dart';
import '../../../../ui/app_icons.dart';
import '../../../../ui/brand.dart';
import '../../../../ui/components/cards.dart';
import '../../../../ui/components/buttons.dart';
import '../../../../ui/components/page_sections.dart';
import '../../widgets/free_tier_ad_slot.dart';

class ConsumerSavedPropertiesPage extends StatelessWidget {
  const ConsumerSavedPropertiesPage({super.key, required this.controller});

  final ConsumerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: controller.loadSavedProperties,
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
                              'Saved properties',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Keep your shortlist close while you compare pricing, trust signals, and closing fit.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: ResColors.mutedForeground),
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
                        label: '${controller.savedProperties.length} saved',
                        color: ResColors.primary,
                        icon: ResIcons.favorite,
                      ),
                      const ResInfoChip(
                        label: 'Shortlist vault',
                        color: ResColors.accent,
                        icon: ResIcons.secure,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ConsumerFreeTierAdSlot(
                    controller: controller,
                    placement: 'saved properties',
                  ),
                  const SizedBox(height: 20),
                  if (controller.isLoadingSavedProperties &&
                      controller.savedProperties.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (controller.savedProperties.isEmpty)
                    ResSurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No saved properties yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Save promising listings from the map or property detail screens to keep them close.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: ResColors.mutedForeground),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const ResSectionHeader(
                      title: 'Shortlisted listings',
                      subtitle:
                          'Tap any card to reopen the property file and continue your review.',
                    ),
                    const SizedBox(height: 14),
                    ...controller.savedProperties.map(
                      (property) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: ResPropertyCard(
                          property: property,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ConsumerPropertyDetailsPage(
                                  controller: controller,
                                  propertyId: property.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
