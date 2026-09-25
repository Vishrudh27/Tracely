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

  /// A step lighter than [surfaceVariant] — used for decorative/tip cards
  /// where Stitch specifies `surface-container-low` instead of the more
  /// common `surface-recessed`.
  static const Color surfaceContainerLow = Color(0xFFF5F3F0);

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

  // One brown ramp, matching `statistics/code.html`'s activity heatmap —
  // no terracotta here, that accent is reserved for the weekly insight card.
  static const List<Color> heatmap = [
    Color(0xFFF1EDE7),
    Color(0xFFE3D3C0),
    Color(0xFFCDB094),
    Color(0xFFA97F58),
    primary,
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
  // Health/Mind/Fitness/Learning migrated 2026-09-25 to the exact hues
  // Stitch specifies in `add_habit/code.html`'s category chip selector — the
  // only place in the whole design system that defines category colors, and
  // it only covers these four. The real per-category color a habit displays
  // lives in the `categories.colorValue` DB column (see AppDatabase's
  // migration v3→v4 and `_seedDefaultCategories`); these constants exist for
  // the ReasonDisplay mapping and as the categoryCustom fallback.
  //
  // Creativity/Social/Self-Care have NO Stitch source — still the old Stone
  // & Sand-era hues (saturated rose/teal/amber), deliberately left alone
  // rather than inventing colors and calling them "Stitch's".
  // ---------------------------------------------------------------------------

  static const Color categoryHealth = Color(0xFF5A7233); // Stitch: Olive
  static const Color categoryMind = Color(0xFF6B5B8C); // Stitch: Violet
  static const Color categoryFitness = Color(0xFFAC5E2D); // Stitch: Terracotta
  static const Color categoryLearning = Color(0xFF3F6480); // Stitch: Slate
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
