import 'package:flutter/material.dart';

/// Extension methods on [BuildContext] for convenient theme access.
///
/// Reduces boilerplate like `Theme.of(context).textTheme.bodyLarge`
/// to `context.textTheme.bodyLarge`.
extension ContextExtensions on BuildContext {
  // ---------------------------------------------------------------------------
  // Theme shortcuts
  // ---------------------------------------------------------------------------

  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  // ---------------------------------------------------------------------------
  // Screen dimensions
  // ---------------------------------------------------------------------------

  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  EdgeInsets get viewInsets => MediaQuery.viewInsetsOf(this);

  // ---------------------------------------------------------------------------
  // Navigation shortcuts
  // ---------------------------------------------------------------------------

  bool get canPop => Navigator.of(this).canPop();
}
