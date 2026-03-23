import 'package:flutter/material.dart';

class ResSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const xxxxl = 40.0;
  static const titleGap = 18.0;
  static const sectionGap = 24.0;
  static const pagePadding = EdgeInsets.symmetric(horizontal: lg);
}

class ResRadius {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

class ResPadding {
  static const card = EdgeInsets.all(ResSpacing.xl);
  static const cardCompact = EdgeInsets.all(ResSpacing.lg);
  static const button = EdgeInsets.symmetric(horizontal: ResSpacing.xl);
  static const page = EdgeInsets.fromLTRB(
    ResSpacing.lg,
    ResSpacing.lg,
    ResSpacing.lg,
    ResSpacing.xxxxl,
  );
}
