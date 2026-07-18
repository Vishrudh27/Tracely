import 'package:flutter/widgets.dart';

/// Centralized border radius tokens.
///
/// Rules:
/// - Never use BorderRadius.circular() directly.
/// - Always use AppRadius.
/// - Keeps all components visually consistent.
///
/// Radius Scale
/// xs  -> 4
/// sm  -> 8
/// md  -> 12
/// lg  -> 16
/// xl  -> 20
/// pill -> 999
final class AppRadius {
  AppRadius._();

  // ---------------------------------------------------------------------------
  // Radius Values
  // ---------------------------------------------------------------------------

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;

  // ---------------------------------------------------------------------------
  // Component Radius
  // ---------------------------------------------------------------------------

  /// Standard cards
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));

  /// Buttons
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));

  /// Input fields
  static const BorderRadius input = BorderRadius.all(Radius.circular(md));

  /// Dialogs
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(lg));

  /// Bottom Sheets
  static const BorderRadius bottomSheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );

  /// Chips
  static const BorderRadius chip = BorderRadius.all(Radius.circular(sm));

  /// FAB
  static const BorderRadius fab = BorderRadius.all(Radius.circular(pill));

  /// Navigation Bar
  static const BorderRadius navigation = BorderRadius.all(Radius.circular(xl));

  /// Small widgets
  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
}
