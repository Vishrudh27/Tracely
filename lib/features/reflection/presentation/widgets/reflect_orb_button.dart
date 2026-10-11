import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../providers/reflection_prompt_providers.dart';
import 'pause_and_reflect_sheet.dart';
import 'reflection_orb.dart';

/// Permanent header entry point button on the Dashboard.
///
/// Placed immediately left of the Settings button with an [AppSpacing.md] gap.
/// Displays a 20px [ReflectionOrb] inside a 40px circle footprint matching the
/// Settings button.
///
/// Progress:
/// - 0.0 when no reflection exists for today.
/// - 0.5 when 1 stone (or custom note) has been recorded for today.
/// - 1.0 when 2 stones have been recorded for today.
///
/// Tapping always opens the reflection sheet for today (prefilled if existing).
class ReflectOrbButton extends ConsumerWidget {
  const ReflectOrbButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(currentDateProvider);
    final reflection =
        ref.watch(reflectionForDateProvider(today)).asData?.value;

    double progress = 0.0;
    if (reflection != null) {
      try {
        final keys = (jsonDecode(reflection.reasonKeys) as List);
        progress = (keys.length / 2).clamp(0.0, 1.0);
        if (progress == 0.0 &&
            reflection.customText != null &&
            reflection.customText!.trim().isNotEmpty) {
          progress = 0.5;
        }
      } catch (_) {
        progress = 1.0;
      }
    }

    return Semantics(
      label: 'Reflect on today',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final missedHabits = await ref
                .read(habitRepositoryProvider)
                .getMissedHabitsForDate(today);
            if (context.mounted) {
              await PauseAndReflectSheet.show(
                context: context,
                targetDate: today,
                missedHabits: missedHabits,
              );
            }
          },
          child: Container(
            width: AppSizes.buttonSmallHeight, // 40px
            height: AppSizes.buttonSmallHeight, // 40px
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.isDark
                  ? (progress > 0
                      ? AppColors.clay.withValues(alpha: 0.14)
                      : const Color(0xFF221E19))
                  : (progress > 0
                      ? AppColors.clay.withValues(alpha: 0.08)
                      : AppColors.surfaceVariant),
              border: Border.all(
                color: progress > 0
                    ? AppColors.clay
                        .withValues(alpha: AppColors.isDark ? 0.35 : 0.25)
                    : (AppColors.isDark
                        ? const Color(0xFF38322B)
                        : AppColors.border),
                width: AppSizes.divider,
              ),
            ),
            child: Center(
              child: ReflectionOrb(
                progress: progress,
                size: AppSizes.orbSizeSmall, // 20px
              ),
            ),
          ),
        ),
      ),
    );
  }
}
