import 'package:flutter/material.dart';

import '../../features/consumer_flow/consumer_models.dart';
import '../app_icons.dart';
import '../brand.dart';
import '../dimensions.dart';
import 'property_media.dart';

class ResSurfaceCard extends StatelessWidget {
  const ResSurfaceCard({
    super.key,
    required this.child,
    this.padding = ResPadding.card,
    this.color,
    this.radius = 28,
    this.shadow = ResShadows.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? ResColors.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

class ResInfoChip extends StatelessWidget {
  const ResInfoChip({
    super.key,
    required this.label,
    this.color = ResColors.secondary,
    this.icon = ResIcons.check,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isLightChip = color.computeLuminance() > 0.85;
    final fillColor = isLightChip
        ? color.withValues(alpha: 0.18)
        : color.withValues(alpha: 0.12);
    final strokeColor = isLightChip
        ? color.withValues(alpha: 0.20)
        : color.withValues(alpha: 0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: strokeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class ResActionTile extends StatelessWidget {
  const ResActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.tint,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        child: ResSurfaceCard(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 16,
            vertical: compact ? 18 : 22,
          ),
          radius: compact ? 22 : 28,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: compact ? 46 : 58,
                height: compact ? 46 : 58,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: tint, size: compact ? 22 : 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ResColors.foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResMetricCard extends StatelessWidget {
  const ResMetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ResSurfaceCard(
        color: ResColors.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        radius: 24,
        shadow: const [],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: ResColors.primary, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class ResPropertyCard extends StatelessWidget {
  const ResPropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.fullWidth = false,
  });

  final ConsumerPropertySummary property;
  final VoidCallback? onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            color: ResColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(25, 28, 32, 0.08),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1.32,
                      child: ResPropertyMedia(
                        propertyType: property.type,
                        title: property.title,
                        imageUrl: property.coverImageUrl ?? '',
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                        showLabel: false,
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x22000666),
                              Colors.transparent,
                              Color(0xAA191C20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: ResInfoChip(
                        label: startCase(property.verificationStatus ?? 'verified'),
                        color: property.isFeatured
                            ? ResColors.tertiary
                            : ResColors.secondary,
                        icon: property.isFeatured
                            ? ResIcons.crown
                            : ResIcons.secure,
                      ),
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          property.isFeatured
                              ? ResIcons.star
                              : ResIcons.favorite,
                          color: property.isFeatured
                              ? ResColors.tertiary
                              : ResColors.softForeground,
                          size: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: ResGradients.premiumButton,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          formatXaf(property.priceXaf),
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          ResIcons.location,
                          size: 17,
                          color: ResColors.softForeground,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            property.locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _tinyStat(
                          context,
                          ResIcons.propertyType(property.type),
                          startCase(property.type),
                        ),
                        const SizedBox(width: 10),
                        _tinyStat(
                          context,
                          ResIcons.listingType(property.listingType),
                          startCase(property.listingType),
                        ),
                        const SizedBox(width: 10),
                        _tinyStat(context, ResIcons.map, property.region),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (fullWidth) {
      return card;
    }

    return SizedBox(width: 316, child: card);
  }

  Widget _tinyStat(BuildContext context, IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: ResColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: ResColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ResColors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResTaskTile extends StatelessWidget {
  const ResTaskTile({super.key, required this.task, this.onTap});

  final ConsumerTask task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (task.priority) {
      'urgent' => ResColors.destructive,
      'high' => ResColors.primary,
      'medium' => ResColors.secondary,
      _ => ResColors.softForeground,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ResColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(ResIcons.taskPriority(task.priority), color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ResColors.foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ResColors.softForeground,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ResMenuTile extends StatelessWidget {
  const ResMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingLabel,
    this.tint = ResColors.primary,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ResSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          radius: 24,
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: tint, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingLabel != null || onTap != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (trailingLabel != null)
                      Container(
                        margin: EdgeInsets.only(bottom: onTap != null ? 8 : 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          trailingLabel!,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: tint),
                        ),
                      ),
                    if (onTap != null)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: ResColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: ResColors.softForeground,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
