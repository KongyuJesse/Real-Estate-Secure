import 'package:flutter/material.dart';

import '../brand.dart';

class ResAvatar extends StatelessWidget {
  const ResAvatar({
    super.key,
    required this.name,
    required this.imageUrl,
    this.size = 52,
    this.borderColor = Colors.white,
    this.backgroundColor = ResColors.primary,
  });

  final String name;
  final String imageUrl;
  final double size;
  final Color borderColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsForName(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: ResShadows.card,
      ),
      child: ClipOval(
        child: imageUrl.trim().isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return _AvatarFallback(
                    initials: initials,
                    backgroundColor: backgroundColor,
                  );
                },
                errorBuilder: (_, _, _) => _AvatarFallback(
                  initials: initials,
                  backgroundColor: backgroundColor,
                ),
              )
            : _AvatarFallback(
                initials: initials,
                backgroundColor: backgroundColor,
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.initials,
    required this.backgroundColor,
  });

  final String initials;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor.withValues(alpha: 0.85),
            ResColors.secondary,
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _initialsForName(String raw) {
  final parts = raw
      .split(' ')
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'RE';
  }
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
