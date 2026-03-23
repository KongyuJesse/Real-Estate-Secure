import 'package:flutter/material.dart';

class ResColors {
  static const background = Color(0xFFF8F9FF);
  static const surface = Color(0xFFF8F9FF);
  static const surfaceContainer = Color(0xFFECEEF3);
  static const surfaceContainerLow = Color(0xFFF2F3F9);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerHigh = Color(0xFFE7E8EE);
  static const surfaceContainerHighest = Color(0xFFE1E2E8);
  static const glass = Color(0xCCF8F9FF);

  static const foreground = Color(0xFF191C20);
  static const mutedForeground = Color(0xFF454652);
  static const softForeground = Color(0xFF767683);
  static const outline = Color(0xFF767683);
  static const outlineVariant = Color(0xFFC6C5D4);
  static const surfaceTint = Color(0xFF4C56AF);

  static const primary = Color(0xFF000666);
  static const primaryContainer = Color(0xFF1A237E);
  static const primaryFixed = Color(0xFFE0E0FF);
  static const primaryFixedDim = Color(0xFFBDC2FF);
  static const onPrimaryContainer = Color(0xFF8690EE);
  static const secondary = Color(0xFF046B5E);
  static const secondaryContainer = Color(0xFF9DEFDE);
  static const onSecondaryContainer = Color(0xFF0F6F62);
  static const tertiary = Color(0xFF705D00);
  static const tertiaryContainer = Color(0xFFC8A900);
  static const tertiaryFixed = Color(0xFFFFE16D);
  static const tertiaryFixedDim = Color(0xFFE9C400);
  static const onTertiaryContainer = Color(0xFF4B3E00);
  static const accent = tertiaryFixed;

  static const success = secondary;
  static const warning = tertiary;
  static const info = Color(0xFF34506E);
  static const destructive = Color(0xFFBA1A1A);

  static const card = surfaceContainerLowest;
  static const muted = surfaceContainerLow;
  static const border = outlineVariant;
}

const _bodyFamily = 'Manrope';
const _headingFamily = 'Manrope';
const _labelFamily = 'Roboto';

TextStyle _resTextStyle({
  required String family,
  required double size,
  required FontWeight weight,
  required Color color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class ResTheme {
  static ThemeData build() {
    final scheme = const ColorScheme.light().copyWith(
      primary: ResColors.primary,
      onPrimary: Colors.white,
      primaryContainer: ResColors.primaryContainer,
      secondary: ResColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: ResColors.secondaryContainer,
      onSecondaryContainer: ResColors.onSecondaryContainer,
      tertiary: ResColors.tertiary,
      tertiaryContainer: ResColors.tertiaryContainer,
      surface: ResColors.surface,
      error: ResColors.destructive,
      outline: ResColors.outline,
      outlineVariant: ResColors.outlineVariant,
      surfaceTint: ResColors.surfaceTint,
    );

    final baseTextTheme = const TextTheme().copyWith(
      headlineLarge: _resTextStyle(
        family: _headingFamily,
        size: 40,
        weight: FontWeight.w800,
        color: ResColors.foreground,
        height: 1.05,
        letterSpacing: -0.8,
      ),
      headlineMedium: _resTextStyle(
        family: _headingFamily,
        size: 32,
        weight: FontWeight.w800,
        color: ResColors.foreground,
        height: 1.08,
        letterSpacing: -0.6,
      ),
      headlineSmall: _resTextStyle(
        family: _headingFamily,
        size: 26,
        weight: FontWeight.w800,
        color: ResColors.foreground,
        height: 1.1,
        letterSpacing: -0.4,
      ),
      titleLarge: _resTextStyle(
        family: _headingFamily,
        size: 22,
        weight: FontWeight.w800,
        color: ResColors.foreground,
        height: 1.15,
        letterSpacing: -0.2,
      ),
      titleMedium: _resTextStyle(
        family: _headingFamily,
        size: 18,
        weight: FontWeight.w700,
        color: ResColors.foreground,
        height: 1.2,
      ),
      titleSmall: _resTextStyle(
        family: _headingFamily,
        size: 16,
        weight: FontWeight.w700,
        color: ResColors.foreground,
        height: 1.2,
      ),
      bodyLarge: _resTextStyle(
        family: _bodyFamily,
        size: 16,
        weight: FontWeight.w500,
        color: ResColors.foreground,
        height: 1.5,
      ),
      bodyMedium: _resTextStyle(
        family: _bodyFamily,
        size: 14,
        weight: FontWeight.w500,
        color: ResColors.foreground,
        height: 1.45,
      ),
      bodySmall: _resTextStyle(
        family: _bodyFamily,
        size: 12,
        weight: FontWeight.w500,
        color: ResColors.mutedForeground,
        height: 1.4,
      ),
      labelLarge: _resTextStyle(
        family: _headingFamily,
        size: 15,
        weight: FontWeight.w800,
        color: ResColors.foreground,
        height: 1,
      ),
      labelMedium: _resTextStyle(
        family: _labelFamily,
        size: 11,
        weight: FontWeight.w700,
        color: ResColors.softForeground,
        height: 1,
        letterSpacing: 1.2,
      ),
      labelSmall: _resTextStyle(
        family: _labelFamily,
        size: 10,
        weight: FontWeight.w700,
        color: ResColors.softForeground,
        height: 1,
        letterSpacing: 1.1,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ResColors.background,
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: ResColors.background.withValues(alpha: 0.84),
        foregroundColor: ResColors.foreground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleMedium?.copyWith(
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: ResColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ResColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ResColors.foreground,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: ResColors.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: baseTextTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ResColors.primary,
          backgroundColor: ResColors.surfaceContainerHigh,
          side: BorderSide(
            color: ResColors.outlineVariant.withValues(alpha: 0.18),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: baseTextTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ResColors.primary,
          textStyle: baseTextTheme.labelLarge?.copyWith(fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ResColors.surfaceContainerHigh,
        selectedColor: ResColors.primaryFixed,
        disabledColor: ResColors.surfaceContainerHigh,
        secondarySelectedColor: ResColors.primaryFixed,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
        labelStyle: baseTextTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: ResColors.foreground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ResColors.surfaceContainerLow,
        hintStyle: baseTextTheme.bodyMedium?.copyWith(
          color: ResColors.softForeground,
        ),
        labelStyle: baseTextTheme.labelMedium?.copyWith(
          color: ResColors.softForeground,
        ),
        helperStyle: baseTextTheme.bodySmall?.copyWith(
          color: ResColors.mutedForeground,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: ResColors.primary.withValues(alpha: 0.38),
            width: 1.25,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: ResColors.destructive.withValues(alpha: 0.35),
            width: 1.25,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: ResColors.destructive,
            width: 1.25,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: ResColors.outlineVariant.withValues(alpha: 0.18),
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return ResColors.surfaceContainerLowest;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ResColors.primary;
          }
          return ResColors.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ResColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ResColors.primary,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.all(BorderSide.none),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return ResColors.primary;
            }
            return ResColors.surfaceContainerLow;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return ResColors.foreground;
          }),
          textStyle: WidgetStateProperty.all(
            baseTextTheme.labelLarge?.copyWith(fontSize: 13),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    );
  }
}

class ResShadows {
  static const card = [
    BoxShadow(
      color: Color.fromRGBO(25, 28, 32, 0.05),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const floating = [
    BoxShadow(
      color: Color.fromRGBO(25, 28, 32, 0.08),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  static const glow = [
    BoxShadow(
      color: Color.fromRGBO(0, 6, 102, 0.14),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const pill = glow;
}

class ResGradients {
  static const heroPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF050A3F),
      ResColors.primaryContainer,
      ResColors.secondary,
    ],
  );

  static const premiumButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ResColors.primary, ResColors.primaryContainer],
  );

  static const darkHeroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x24000666), Color(0xEE191C20)],
  );
}
