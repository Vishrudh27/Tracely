import 'package:flutter/widgets.dart';

/// Centralized spacing tokens.
///
/// Rules:
/// - Never use raw spacing values like 13, 17, 21.
/// - Always use AppSpacing tokens.
/// - Keeps the entire application visually consistent.
///
/// Base spacing unit: 4px
final class AppSpacing {
  AppSpacing._();

  // Base Scale
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
  static const double massive = 64;

  // Screen Padding
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: lg,
  );

  // Card Padding
  static const EdgeInsets card = EdgeInsets.all(lg);

  // List Item Padding
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  // Dialog Padding
  static const EdgeInsets dialog = EdgeInsets.all(xxl);

  // Bottom Sheet Padding
  static const EdgeInsets bottomSheet = EdgeInsets.fromLTRB(xl, xl, xl, huge);

  // Input Field Padding
  static const EdgeInsets input = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  // Chip Padding
  static const EdgeInsets chip = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  // Button Padding
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: xxl,
    vertical: md,
  );

  // AppBar Padding
  static const EdgeInsets appBar = EdgeInsets.symmetric(horizontal: lg);

  // FAB Margin
  static const EdgeInsets fab = EdgeInsets.all(lg);

  // Habit Tile
  static const EdgeInsets habitTile = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  // Statistics Card
  static const EdgeInsets statisticsCard = EdgeInsets.all(xl);

  // Section gap (vertical spacing between dashboard sections)
  static const double sectionGap = xxl;
}
