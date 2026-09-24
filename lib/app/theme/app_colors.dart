import 'package:flutter/material.dart';

/// Centralized color tokens for the entire application.
///
/// Rules:
/// - Never use Colors.blue, Colors.red, etc. directly.
/// - Never use raw hex values outside this file.
/// - Always reference semantic colors like:
///   AppColors.primary
///   AppColors.surface
///   AppColors.success
///
/// NOTE:
/// "Clay & Oat" — WCAG AA-verified brown palette, resolved in
/// docs/stitch_prompt_kit.md §5.1. Replaces the Stone & Sand dev palette.
/// Values below are the tokens actually rendered across the audited Stitch
/// screens, not the full auto-generated Material scaffold (most of which
/// never reaches markup).
final class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Backgrounds
  // ---------------------------------------------------------------------------

  static const Color background = Color(0xFFFAF8F5); // page-bg

  static const Color surface = Color(0xFFFFFFFF); // surface-card

  static const Color surfaceVariant = Color(0xFFF2EDE6); // surface-recessed

  // ---------------------------------------------------------------------------
  // Brand Colors
  // ---------------------------------------------------------------------------

  static const Color primary = Color(0xFF6F4E37); // primary-coffee

  static const Color primaryLight = Color(0xFFEABDA0);

  static const Color primaryDark = Color(0xFF553722);

  /// Secondary accent — kept as an alias of [accentTerracotta] so existing
  /// call sites re-skin automatically. Prefer [accentTerracotta] in new code.
  static const Color secondary = accentTerracotta;

  /// Fill-only terracotta accent (icons, dots, selected borders). Contrast
  /// against background is ~3.2–3.7:1 — meets the 3:1 UI-component
  /// threshold but NOT the 4.5:1 text threshold. Never use for text.
  static const Color accentTerracotta = Color(0xFFC2703D);

  /// Darker terracotta safe for text (~4.5:1+ on background/surface).
  /// Use this, not [accentTerracotta], whenever terracotta colors a label,
  /// button, or any other readable string.
  static const Color accentText = Color(0xFF9A4F24);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Color(0xFF1F1A15);

  static const Color textSecondary = Color(0xFF655A4E);

  static const Color textDisabled = Color(0xFF9A8E83);

  static const Color textOnPrimary = Colors.white;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF5A7233); // feedback-success

  static const Color warning = accentTerracotta;

  static const Color error = Color(0xFF9C4A32); // feedback-error — muted, never harsh red

  static const Color info = Color(0xFF5C7A99); // not in the Stitch kit; desaturated to fit the warm palette

  // ---------------------------------------------------------------------------
  // Borders & Divider
  // ---------------------------------------------------------------------------

  static const Color border = Color(0xFFE6DFD5); // border-hairline

  static const Color divider = Color(0xFFE6DFD5);

  /// A stronger outline than [border] — for interactive element edges
  /// (checkboxes, input fields) that need to read as tappable, not just
  /// as a quiet section divider.
  static const Color borderOutline = Color(0xFF9F8D7B);

  // ---------------------------------------------------------------------------
  // Disabled
  // ---------------------------------------------------------------------------

  static const Color disabled = Color(0xFF9A8E83);

  // ---------------------------------------------------------------------------
  // Overlay
  // ---------------------------------------------------------------------------

  static const Color overlay = Color(0x66000000);

  // ---------------------------------------------------------------------------
  // Heatmap
  // ---------------------------------------------------------------------------

  static const List<Color> heatmap = [
    surfaceVariant,
    primaryLight,
    accentTerracotta,
    primary,
    primaryDark,
  ];

  // ---------------------------------------------------------------------------
  // Chart Colors
  // ---------------------------------------------------------------------------

  static const List<Color> chartPalette = [
    primary,
    accentTerracotta,
    success,
    accentText,
    primaryLight,
  ];

  // ---------------------------------------------------------------------------
  // Category Colors (muted, warm variants — never harsh)
  //
  // NOT yet re-harmonized for Clay & Oat — still the Stone & Sand-era hues
  // (saturated blue/violet/rose/teal). They read as a clash next to the new
  // brown chrome. Left as-is deliberately: unlike heatmap/chart/streak above,
  // these need to stay visually distinct from each other (they're how a habit
  // list tells categories apart at a glance), so re-choosing 8 mutually
  // distinguishable warm tones is its own design pass, not a token swap —
  // do it when the Habits/Statistics screens are up for their own build stage.
  // ---------------------------------------------------------------------------

  static const Color categoryHealth = Color(0xFF65A30D); // Olive green
  static const Color categoryMind = Color(0xFF7C3AED); // Soft violet
  static const Color categoryFitness = Color(0xFFEA580C); // Warm orange
  static const Color categoryLearning = Color(0xFF2563EB); // Calm blue
  static const Color categoryCreativity = Color(0xFFDB2777); // Soft rose
  static const Color categorySocial = Color(0xFF0891B2); // Teal
  static const Color categorySelfCare = Color(0xFFD97706); // Amber
  static const Color categoryCustom = Color(0xFF78716C); // Stone

  // ---------------------------------------------------------------------------
  // Completion States (gentle, never alarming)
  // ---------------------------------------------------------------------------

  static const Color completedBackground = Color(0xFFF0FDF4); // Very faint green
  static const Color completedBorder = Color(0xFFBBF7D0); // Light green border
  static const Color uncompletedBackground = Color(0xFFFAFAF9); // Near-white warm
  static const Color recoveryDay = Color(0xFFFEF3C7); // Lightest amber

  // ---------------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------------

  static const Color streakActive = accentTerracotta;
  static const Color streakRecord = primary;
  static const Color insightCard = Color(0xFFFFFBEB); // Warm cream background

  // ---------------------------------------------------------------------------
  // Task Priority
  // ---------------------------------------------------------------------------

  static const Color priorityHigh = accentTerracotta;
  static const Color priorityMedium = Color(0xFF97692A);
  static const Color priorityLow = textDisabled;
}
