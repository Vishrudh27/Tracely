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
/// Stone & Sand is the temporary development palette.
/// The entire palette can be replaced later without
/// changing any widget code.
final class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Backgrounds
  // ---------------------------------------------------------------------------

  static const Color background = Color(0xFFFAF9F6);

  static const Color surface = Color(0xFFFFFFFF);

  static const Color surfaceVariant = Color(0xFFF5F2EC);

  // ---------------------------------------------------------------------------
  // Brand Colors
  // ---------------------------------------------------------------------------

  static const Color primary = Color(0xFFB45309);

  static const Color primaryLight = Color(0xFFD97706);

  static const Color primaryDark = Color(0xFF92400E);

  static const Color secondary = Color(0xFF78716C);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color textPrimary = Color(0xFF1C1917);

  static const Color textSecondary = Color(0xFF78716C);

  static const Color textDisabled = Color(0xFFA8A29E);

  static const Color textOnPrimary = Colors.white;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF65A30D);

  static const Color warning = Color(0xFFD97706);

  static const Color error = Color(0xFFB91C1C);

  static const Color info = Color(0xFF2563EB);

  // ---------------------------------------------------------------------------
  // Borders & Divider
  // ---------------------------------------------------------------------------

  static const Color border = Color(0xFFE7E5E4);

  static const Color divider = Color(0xFFE7E5E4);

  // ---------------------------------------------------------------------------
  // Disabled
  // ---------------------------------------------------------------------------

  static const Color disabled = Color(0xFFD6D3D1);

  // ---------------------------------------------------------------------------
  // Overlay
  // ---------------------------------------------------------------------------

  static const Color overlay = Color(0x66000000);

  // ---------------------------------------------------------------------------
  // Heatmap
  // ---------------------------------------------------------------------------

  static const List<Color> heatmap = [
    Color(0xFFF5F5F4),
    Color(0xFFFDE68A),
    Color(0xFFF59E0B),
    Color(0xFFD97706),
    Color(0xFFB45309),
  ];

  // ---------------------------------------------------------------------------
  // Chart Colors
  // ---------------------------------------------------------------------------

  static const List<Color> chartPalette = [
    Color(0xFFB45309),
    Color(0xFF65A30D),
    Color(0xFF2563EB),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
  ];

  // ---------------------------------------------------------------------------
  // Category Colors (muted, warm variants — never harsh)
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

  static const Color streakActive = Color(0xFFD97706); // Amber
  static const Color streakRecord = Color(0xFFB45309); // Deep amber (= primary)
  static const Color insightCard = Color(0xFFFFFBEB); // Warm cream background
}
