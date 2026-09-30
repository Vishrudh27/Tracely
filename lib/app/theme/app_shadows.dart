import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A black drop shadow is invisible on AppColors' near-black dark
/// background — depth there comes entirely from the surface/background
/// tone steps (see the dark-mode doc on [AppColors]), same as Material's
/// own dark theme, which drops shadow-based elevation in favor of tone.
/// So every level here goes empty in dark mode rather than painting a
/// shadow nobody can see.
final class AppShadows {
  AppShadows._();

  static const List<BoxShadow> _sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static List<BoxShadow> get sm => AppColors.isDark ? const [] : _sm;

  static const List<BoxShadow> _md = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static List<BoxShadow> get md => AppColors.isDark ? const [] : _md;

  static const List<BoxShadow> _lg = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static List<BoxShadow> get lg => AppColors.isDark ? const [] : _lg;
}
