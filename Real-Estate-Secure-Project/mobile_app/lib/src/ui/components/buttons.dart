import 'package:flutter/material.dart';

import '../brand.dart';
import '../dimensions.dart';

class ResPrimaryButton extends StatelessWidget {
  const ResPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isBusy = false,
    this.isPill = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool isPill;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isBusy;
    final foreground = enabled ? Colors.white : ResColors.softForeground;
    return _ResButtonFrame(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(
        isPill ? ResRadius.pill : ResRadius.md,
      ),
      gradient: enabled ? ResGradients.premiumButton : null,
      color: enabled ? null : ResColors.surfaceContainerHigh,
      foregroundColor: foreground,
      height: 58,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 20),
              if (isBusy || icon != null) const SizedBox(width: 10),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResOutlineButton extends StatelessWidget {
  const ResOutlineButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPill = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPill;

  @override
  Widget build(BuildContext context) {
    return _ResButtonFrame(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(
        isPill ? ResRadius.pill : ResRadius.md,
      ),
      color: ResColors.surfaceContainerHigh,
      border: Border.all(
        color: ResColors.outlineVariant.withValues(alpha: 0.18),
      ),
      foregroundColor: ResColors.primary,
      height: 58,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: ResColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResGhostButton extends StatelessWidget {
  const ResGhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isPill = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPill;

  @override
  Widget build(BuildContext context) {
    final foreground = onPressed == null
        ? ResColors.softForeground
        : ResColors.primary;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
    );
    final style = TextButton.styleFrom(
      minimumSize: const Size(0, 46),
      foregroundColor: foreground,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          isPill ? ResRadius.pill : ResRadius.sm,
        ),
      ),
    );
    if (icon == null) {
      return TextButton(
        onPressed: onPressed,
        style: style,
        child: Text(label, style: textStyle),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label, style: textStyle),
    );
  }
}

class ResCircleIconButton extends StatelessWidget {
  const ResCircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor = const Color(0xCCFFFFFF),
    this.foregroundColor = ResColors.foreground,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return _ResButtonFrame(
      onTap: onPressed,
      height: 46,
      width: 46,
      borderRadius: BorderRadius.circular(999),
      color: backgroundColor,
      foregroundColor: foregroundColor,
      child: Icon(icon, size: 20),
    );
  }
}

class _ResButtonFrame extends StatelessWidget {
  const _ResButtonFrame({
    required this.child,
    required this.borderRadius,
    required this.foregroundColor,
    this.onTap,
    this.gradient,
    this.color,
    this.border,
    this.height = 56,
    this.width,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color foregroundColor;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final Border? border;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final resolvedBorder =
        border ??
        (gradient != null
            ? Border.all(color: Colors.white.withValues(alpha: 0.08))
            : null);
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Ink(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: gradient == null ? color : null,
              gradient: gradient,
              borderRadius: borderRadius,
              border: resolvedBorder,
              boxShadow: gradient != null ? ResShadows.glow : const [],
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foregroundColor),
              child: IconTheme.merge(
                data: IconThemeData(color: foregroundColor),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
