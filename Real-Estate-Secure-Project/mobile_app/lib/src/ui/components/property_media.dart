import 'package:flutter/material.dart';

import '../app_icons.dart';

class ResPropertyMedia extends StatelessWidget {
  const ResPropertyMedia({
    super.key,
    required this.propertyType,
    required this.title,
    this.imageUrl = '',
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.showLabel = true,
    this.overlay,
  });

  final String propertyType;
  final String title;
  final String imageUrl;
  final BorderRadiusGeometry borderRadius;
  final BoxFit fit;
  final bool showLabel;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl.trim();
    final overlayChildren = overlay == null
        ? const <Widget>[]
        : <Widget>[overlay!];

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PropertyPlaceholder(
            propertyType: propertyType,
            title: title,
            showLabel: showLabel,
          ),
          if (normalizedUrl.isNotEmpty)
            Image.network(
              normalizedUrl,
              fit: fit,
              filterQuality: FilterQuality.low,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return const SizedBox.expand();
              },
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ...overlayChildren,
        ],
      ),
    );
  }
}

class _PropertyPlaceholder extends StatelessWidget {
  const _PropertyPlaceholder({
    required this.propertyType,
    required this.title,
    required this.showLabel,
  });

  final String propertyType;
  final String title;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForType(propertyType);
    final icon = _iconForType(propertyType);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -14,
            child: Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -38,
            left: -24,
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              width: showLabel ? 52 : 64,
              height: showLabel ? 52 : 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: showLabel ? 0.14 : 0.10),
                borderRadius: BorderRadius.circular(showLabel ? 18 : 22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: showLabel ? 0.92 : 0.72),
                size: showLabel ? 28 : 30,
              ),
            ),
          ),
          if (!showLabel)
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 88,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: showLabel ? 52 : 0),
                const Spacer(),
                if (showLabel)
                  Text(
                    _displayType(propertyType),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      letterSpacing: 1.3,
                    ),
                  ),
                if (showLabel) const SizedBox(height: 6),
                if (showLabel)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Color> _paletteForType(String propertyType) {
  switch (propertyType.trim().toLowerCase()) {
    case 'land':
    case 'agricultural':
      return const [Color(0xFF153C2E), Color(0xFF1E5A43), Color(0xFF4E8B61)];
    case 'commercial':
    case 'industrial':
      return const [Color(0xFF132238), Color(0xFF25405C), Color(0xFF496A85)];
    case 'apartment':
      return const [Color(0xFF000666), Color(0xFF1A237E), Color(0xFF4C56AF)];
    default:
      return const [Color(0xFF000666), Color(0xFF1A237E), Color(0xFF046B5E)];
  }
}

IconData _iconForType(String propertyType) {
  switch (propertyType.trim().toLowerCase()) {
    case 'land':
    case 'agricultural':
      return ResIcons.land;
    case 'commercial':
    case 'industrial':
      return Icons.corporate_fare_rounded;
    case 'apartment':
      return Icons.apartment_rounded;
    default:
      return ResIcons.house;
  }
}

String _displayType(String propertyType) => propertyType
    .split(RegExp(r'[_\-\s]+'))
    .where((part) => part.trim().isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
    .join(' ');
