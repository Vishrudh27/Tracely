import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../core/utils/habit_schedule.dart';
import '../../../../core/utils/streak_calculator.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/habit_repository.dart';

/// Elevated habit management card in the Habits list.
///
/// Displays:
/// - Category-accented icon squircle
/// - Habit title with category badge and frequency cadence
/// - Live streak flame pill (`🔥 12d` or `0d`)
/// - 7-day rolling micro-progress track (Monday–Sunday cadence)
///
/// Fully reactive via Riverpod: completion toggles across the app update
/// this card's streak and 7-day indicators in real time without screen refresh.
class HabitManagementTile extends ConsumerWidget {
  const HabitManagementTile({
    super.key,
    required this.habit,
    required this.onTap,
    this.category,
  });

  final Habit habit;
  final Category? category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionsAsync = ref.watch(habitCompletionsProvider(habit.id));
    final completions = completionsAsync.asData?.value ?? const [];
    final dates = completions.map((c) => c.completedDate).toList();
    final completedSet = dates.map((d) => d.startOfDay).toSet();

    final today = ref.watch(currentDateProvider).startOfDay;
    bool isDayScheduled(DateTime day) =>
        isScheduledOn(habit.frequencyType, habit.frequencyConfig, day);

    final currentStreak =
        StreakCalculator.currentStreak(dates, isScheduled: isDayScheduled);

    final categoryColor = category != null
        ? Color(category!.colorValue)
        : AppColors.categoryCustom;
    final iconKey = habit.emoji ?? category?.emoji;

    // 7 days ending on today (6 days ago to today)
    final weekDays = List.generate(7, (i) => today.addDays(i - 6));

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.65),
          width: 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: categoryColor.withValues(alpha: 0.08),
          highlightColor: categoryColor.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // -------------------------------------------------------------
                // Top Row: Icon + Title + Streak Pill + Chevron
                // -------------------------------------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Category icon box
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: categoryColor.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          AppIconRegistry.resolve(iconKey),
                          size: 20,
                          color: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Title + Category/Frequency
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            habit.name,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: categoryColor,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '${category?.name ?? 'General'} • ${frequencyLabel(habit.frequencyType, habit.frequencyConfig)}',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),

                    // Streak pill + Chevron
                    _StreakFlamePill(streak: currentStreak),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textDisabled,
                      size: AppSizes.iconMd,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // -------------------------------------------------------------
                // Bottom Row: 7-Day Mini Track
                // -------------------------------------------------------------
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.4),
                      width: 0.75,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final day in weekDays)
                        _MiniDayDot(
                          day: day,
                          isToday: day == today,
                          isScheduled: isDayScheduled(day),
                          isCompleted: completedSet.contains(day),
                          activeColor: categoryColor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Streak Flame Pill
// -----------------------------------------------------------------------------

class _StreakFlamePill extends StatelessWidget {
  const _StreakFlamePill({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    if (streak > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: AppColors.accentTerracotta.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: AppColors.accentTerracotta.withValues(alpha: 0.30),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: AppColors.accentTerracotta,
            ),
            const SizedBox(width: 3),
            Text(
              '$streak',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accentTerracotta,
                height: 1.1,
              ),
            ),
            Text(
              'd',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.accentTerracotta,
                height: 1.1,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.7),
          width: 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            size: 13,
            color: AppColors.textDisabled,
          ),
          const SizedBox(width: 3),
          Text(
            '0d',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textDisabled,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Mini Day Dot
// -----------------------------------------------------------------------------

class _MiniDayDot extends StatelessWidget {
  const _MiniDayDot({
    required this.day,
    required this.isToday,
    required this.isScheduled,
    required this.isCompleted,
    required this.activeColor,
  });

  final DateTime day;
  final bool isToday;
  final bool isScheduled;
  final bool isCompleted;
  final Color activeColor;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final letter = _dayLetters[day.weekday - 1];

    Widget indicator;
    if (isCompleted) {
      indicator = Container(
        width: 19,
        height: 19,
        decoration: BoxDecoration(
          color: activeColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.35),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.check_rounded,
            size: 12,
            color: Colors.white,
          ),
        ),
      );
    } else if (isScheduled) {
      if (isToday) {
        indicator = Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(color: activeColor, width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      } else {
        // Scheduled but missed in past
        indicator = Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
          child: Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }
    } else {
      // Rest / Not scheduled
      indicator = SizedBox(
        width: 19,
        height: 19,
        child: Center(
          child: Container(
            width: 4,
            height: 1.5,
            decoration: BoxDecoration(
              color: AppColors.textDisabled.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          letter,
          style: context.textTheme.labelSmall?.copyWith(
            fontSize: 9.5,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            color: isToday ? AppColors.textPrimary : AppColors.textDisabled,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 3.5),
        indicator,
      ],
    );
  }
}
