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

  /// Set at startup from the saved Reduce Motion preference (see
  /// `MotionService`), and again whenever Settings toggles it. When true,
  /// every duration below collapses to zero instead of animating.
  static bool reduceMotion = false;

  static Duration _d(int milliseconds) =>
      reduceMotion ? Duration.zero : Duration(milliseconds: milliseconds);

  /// One-off duration for a screen's own entrance/exit animation that's
  /// tuned specifically for it and doesn't warrant a shared named token
  /// below — still gated by [reduceMotion] like every other getter here.
  /// The "never use Duration(...) directly in widgets" rule means routing
  /// through this, not through `Duration(milliseconds: ...)`.
  static Duration custom(int milliseconds) => _d(milliseconds);

  //--------------------------------------------------------------------------
  // Micro Interactions
  //--------------------------------------------------------------------------

  /// Button press
  static Duration get instant => _d(100);

  /// Small UI feedback
  static Duration get micro => _d(150);

  //--------------------------------------------------------------------------
  // Standard Animations
  //--------------------------------------------------------------------------

  /// Cards
  static Duration get fast => _d(200);

  /// Most widgets
  static Duration get medium => _d(300);

  /// Larger widgets
  static Duration get slow => _d(400);

  //--------------------------------------------------------------------------
  // Navigation
  //--------------------------------------------------------------------------

  /// Page transition
  static Duration get pageTransition => _d(280);

  /// Bottom Navigation
  static Duration get navigation => _d(250);

  /// Hero Animation
  static Duration get hero => _d(350);

  //--------------------------------------------------------------------------
  // Components
  //--------------------------------------------------------------------------

  /// Bottom Sheet
  static Duration get bottomSheet => _d(300);

  /// Dialog
  static Duration get dialog => _d(250);

  /// Snackbar
  static Duration get snackBar => _d(250);

  /// Tooltip
  static Duration get tooltip => _d(200);

  //--------------------------------------------------------------------------
  // Lists
  //--------------------------------------------------------------------------

  /// List insertion/removal
  static Duration get listItem => _d(220);

  /// Stagger delay
  static Duration get stagger => _d(40);

  //--------------------------------------------------------------------------
  // Habit Tracking
  //--------------------------------------------------------------------------

  /// Habit completion
  static Duration get habitComplete => _d(220);

  /// Streak update
  static Duration get streak => _d(300);

  //--------------------------------------------------------------------------
  // Analytics
  //--------------------------------------------------------------------------

  /// Chart animation
  static Duration get chart => _d(700);

  /// Heatmap loading
  static Duration get heatmap => _d(600);

  /// Progress bars
  static Duration get progress => _d(500);

  //--------------------------------------------------------------------------
  // Loading
  //--------------------------------------------------------------------------

  static Duration get loading => _d(500);

  static Duration get shimmer => _d(1200);

  //--------------------------------------------------------------------------
  // Scroll
  //--------------------------------------------------------------------------

  /// AppBar collapse
  static Duration get appBar => _d(250);
}
