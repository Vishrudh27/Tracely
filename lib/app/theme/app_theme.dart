import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),

      scaffoldBackgroundColor: AppColors.background,

      textTheme: AppTypography.textTheme,
    );
  }
}
