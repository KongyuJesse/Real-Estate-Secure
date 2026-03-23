import 'package:flutter/material.dart';

import '../app_icons.dart';
import '../brand.dart';
import 'cards.dart';

class ResUploadTile extends StatelessWidget {
  const ResUploadTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.stateLabel,
    this.fileName,
    this.isUploaded = false,
    this.isBusy = false,
    this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final String? stateLabel;
  final String? fileName;
  final bool isUploaded;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = isUploaded ? ResColors.secondary : ResColors.primary;
    final resolvedActionLabel =
        actionLabel ?? (isUploaded ? 'Replace file' : 'Choose file');
    final resolvedStateLabel =
        stateLabel ?? (isUploaded ? 'Ready' : 'Required');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onPressed,
        borderRadius: BorderRadius.circular(24),
        child: ResSurfaceCard(
          padding: const EdgeInsets.all(16),
          radius: 24,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isUploaded
                      ? ResColors.secondaryContainer.withValues(alpha: 0.35)
                      : ResColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isUploaded ? ResIcons.check : icon,
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      fileName?.trim().isNotEmpty == true
                          ? fileName!
                          : subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fileName?.trim().isNotEmpty == true
                            ? ResColors.foreground
                            : ResColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            resolvedStateLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            resolvedActionLabel,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ResColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: isBusy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        )
                      : Icon(
                          isUploaded
                              ? Icons.sync_rounded
                              : Icons.chevron_right_rounded,
                          color: accent,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
