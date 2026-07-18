import 'package:flutter/animation.dart';

/// Centralized animation curves.
///
/// Rules:
/// - Never use Curves.* directly inside widgets.
/// - Always use AppCurves.
/// - Ensures a consistent motion language throughout the app.
///
/// Motion Philosophy:
/// Calm • Smooth • Predictable • Premium
final class AppCurves {
  AppCurves._();

  //--------------------------------------------------------------------------
  // Standard Motion
  //--------------------------------------------------------------------------

  /// Default curve for most animations.
  static const Curve standard = Curves.easeInOutCubic;

  /// Used for content entering the screen.
  static const Curve emphasizedDecelerate = Curves.easeOutCubic;

  /// Used for content leaving the screen.
  static const Curve emphasizedAccelerate = Curves.easeInCubic;

  //--------------------------------------------------------------------------
  // Components
  //--------------------------------------------------------------------------

  /// Buttons
  static const Curve button = Curves.easeOutCubic;

  /// Cards
  static const Curve card = Curves.easeInOutCubic;

  /// Dialogs
  static const Curve dialog = Curves.easeOutCubic;

  /// Bottom Sheets
  static const Curve bottomSheet = Curves.easeOutCubic;

  //--------------------------------------------------------------------------
  // Navigation
  //--------------------------------------------------------------------------

  static const Curve pageTransition = Curves.easeInOutCubic;

  static const Curve hero = Curves.easeInOutCubic;

  static const Curve navigation = Curves.easeOutCubic;

  //--------------------------------------------------------------------------
  // Lists
  //--------------------------------------------------------------------------

  static const Curve list = Curves.easeOutCubic;

  static const Curve stagger = Curves.easeOut;

  //--------------------------------------------------------------------------
  // Habit Tracking
  //--------------------------------------------------------------------------

  static const Curve habitCompletion = Curves.easeOutBack;

  static const Curve streak = Curves.easeOutCubic;

  //--------------------------------------------------------------------------
  // Analytics
  //--------------------------------------------------------------------------

  static const Curve chart = Curves.easeOutCubic;

  static const Curve heatmap = Curves.easeInOutCubic;

  static const Curve progress = Curves.easeOutCubic;

  //--------------------------------------------------------------------------
  // Loading
  //--------------------------------------------------------------------------

  static const Curve loading = Curves.easeInOut;

  static const Curve shimmer = Curves.linear;

  //--------------------------------------------------------------------------
  // Scroll
  //--------------------------------------------------------------------------

  static const Curve appBar = Curves.easeOutCubic;
}
