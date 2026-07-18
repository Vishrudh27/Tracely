/// Centralized animation durations.
///
/// Rules:
/// - Never use Duration(...) directly in widgets.
/// - Always use AppDurations.
/// - Keeps the entire application animation timing consistent.
///
/// Motion Philosophy:
/// Calm > Flashy
/// Smooth > Fast
/// Natural > Dramatic
final class AppDurations {
  AppDurations._();

  //--------------------------------------------------------------------------
  // Micro Interactions
  //--------------------------------------------------------------------------

  /// Button press
  static const Duration instant = Duration(milliseconds: 100);

  /// Small UI feedback
  static const Duration micro = Duration(milliseconds: 150);

  //--------------------------------------------------------------------------
  // Standard Animations
  //--------------------------------------------------------------------------

  /// Cards
  static const Duration fast = Duration(milliseconds: 200);

  /// Most widgets
  static const Duration medium = Duration(milliseconds: 300);

  /// Larger widgets
  static const Duration slow = Duration(milliseconds: 400);

  //--------------------------------------------------------------------------
  // Navigation
  //--------------------------------------------------------------------------

  /// Page transition
  static const Duration pageTransition = Duration(milliseconds: 280);

  /// Bottom Navigation
  static const Duration navigation = Duration(milliseconds: 250);

  /// Hero Animation
  static const Duration hero = Duration(milliseconds: 350);

  //--------------------------------------------------------------------------
  // Components
  //--------------------------------------------------------------------------

  /// Bottom Sheet
  static const Duration bottomSheet = Duration(milliseconds: 300);

  /// Dialog
  static const Duration dialog = Duration(milliseconds: 250);

  /// Snackbar
  static const Duration snackBar = Duration(milliseconds: 250);

  /// Tooltip
  static const Duration tooltip = Duration(milliseconds: 200);

  //--------------------------------------------------------------------------
  // Lists
  //--------------------------------------------------------------------------

  /// List insertion/removal
  static const Duration listItem = Duration(milliseconds: 220);

  /// Stagger delay
  static const Duration stagger = Duration(milliseconds: 40);

  //--------------------------------------------------------------------------
  // Habit Tracking
  //--------------------------------------------------------------------------

  /// Habit completion
  static const Duration habitComplete = Duration(milliseconds: 220);

  /// Streak update
  static const Duration streak = Duration(milliseconds: 300);

  //--------------------------------------------------------------------------
  // Analytics
  //--------------------------------------------------------------------------

  /// Chart animation
  static const Duration chart = Duration(milliseconds: 700);

  /// Heatmap loading
  static const Duration heatmap = Duration(milliseconds: 600);

  /// Progress bars
  static const Duration progress = Duration(milliseconds: 500);

  //--------------------------------------------------------------------------
  // Loading
  //--------------------------------------------------------------------------

  static const Duration loading = Duration(milliseconds: 500);

  static const Duration shimmer = Duration(milliseconds: 1200);

  //--------------------------------------------------------------------------
  // Scroll
  //--------------------------------------------------------------------------

  /// AppBar collapse
  static const Duration appBar = Duration(milliseconds: 250);
}
