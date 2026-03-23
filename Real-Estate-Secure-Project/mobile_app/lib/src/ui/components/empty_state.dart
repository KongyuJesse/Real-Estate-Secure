import 'package:flutter/material.dart';

import '../brand.dart';
import 'cards.dart';
import '../dimensions.dart';

class ResEmptyState extends StatelessWidget {
  const ResEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: ResPadding.page,
        child: ResSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 64,
                color: ResColors.mutedForeground,
              ),
              const SizedBox(height: ResSpacing.lg),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ResSpacing.sm),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ResColors.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: ResSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}