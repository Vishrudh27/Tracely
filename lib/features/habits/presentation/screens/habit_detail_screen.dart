import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../core/utils/behavior_insights.dart';
import '../../../../core/utils/habit_schedule.dart';
import '../../../../core/utils/streak_calculator.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/database/daos/reflection_dao.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../analytics/presentation/widgets/most_common_reasons_card.dart';
import '../../../reflection/presentation/widgets/reflection_taxonomy.dart';

/// A single habit's comprehensive story:
/// - Identity & category branding
/// - Hero Momentum Gauge with live streak, best streak, consistency, and bounce-back
/// - Interactive 28-day rolling calendar grid with touch inspection
/// - Hero Why Statistics & Resilience breakdown
///
/// Reached by tapping a habit in the Habits screen. Fully reactive: toggling
/// the habit's completion anywhere updates this screen live.
class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _identityOpacity;
  late final Animation<double> _identityScale;
  late final Animation<double> _statsOpacity;
  late final Animation<double> _statsSlide;
  late final Animation<double> _sectionsOpacity;
  late final Animation<double> _sectionsSlide;

  DateTime? _inspectedDay;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.custom(700),
    );
    _identityOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _identityScale = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutBack),
      ),
    );
    _statsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
    );
    _statsSlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.70, curve: Curves.easeOutCubic),
      ),
    );
    _sectionsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.90, curve: Curves.easeOut),
    );
    _sectionsSlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.95, curve: Curves.easeOutCubic),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habitAsync = ref.watch(habitByIdProvider(widget.habitId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: habitAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => _buildNotFound(context),
          data: (habit) {
            if (habit == null) return _buildNotFound(context);
            return _buildBody(context, habit);
          },
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Column(
      children: [
        const _HabitDetailHeader(onEdit: null),
        const Expanded(
          child: TracelyEmptyState(
            icon: Icons.search_off_rounded,
            title: "This habit isn't here anymore.",
            body: 'It may have been removed.',
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, Habit habit) {
    final categoryAsync = ref.watch(categoryByIdProvider(habit.categoryId));
    final completionsAsync =
        ref.watch(habitCompletionsProvider(widget.habitId));
    final reasons =
        ref.watch(habitReasonsProvider(widget.habitId)).asData?.value ??
            const <ReasonFrequency>[];
    final reflectionsMap =
        ref.watch(habitReflectionsMapProvider(widget.habitId)).asData?.value ??
            const <DateTime, HabitReflection>{};

    final category = categoryAsync.asData?.value;
    final completions = completionsAsync.asData?.value ?? const [];
    final dates = completions.map((c) => c.completedDate).toList();

    bool isDayScheduled(DateTime day) =>
        isScheduledOn(habit.frequencyType, habit.frequencyConfig, day);

    final currentStreak =
        StreakCalculator.currentStreak(dates, isScheduled: isDayScheduled);
    final longestStreak =
        StreakCalculator.longestStreak(dates, isScheduled: isDayScheduled);

    final today = ref.watch(currentDateProvider).startOfDay;
    final createdDay = habit.createdAt.startOfDay;
    final dateSet = dates.map((d) => d.startOfDay).toSet();

    final recentRate = recentCompletionRate(
      frequencyType: habit.frequencyType,
      frequencyConfig: habit.frequencyConfig,
      today: today,
      createdDay: createdDay,
      completedDays: dateSet,
    );

    final bounceBack = StreakCalculator.bounceBackStats(
      completionDates: dates,
      createdDay: createdDay,
      today: today,
      isScheduled: isDayScheduled,
    );

    final usualMinute = usualCompletionMinute(
      completions.map((c) => c.completedAt),
      today: today,
    );

    final categoryColor = category != null
        ? Color(category.colorValue)
        : AppColors.categoryCustom;

    final inspected = _inspectedDay ?? today;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          children: [
            _HabitDetailHeader(
              onEdit: () => context.push('/habits/edit/${habit.id}'),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.huge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Identity
                    Opacity(
                      opacity: _identityOpacity.value,
                      child: Transform.scale(
                        scale: _identityScale.value,
                        child: _HabitIdentity(
                          habit: habit,
                          categoryName: category?.name ?? 'General',
                          iconKey: habit.emoji ?? category?.emoji,
                          usualMinute: usualMinute,
                          categoryColor: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Hero Momentum Gauge
                    Opacity(
                      opacity: _statsOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _statsSlide.value),
                        child: _HeroMomentumGauge(
                          currentStreak: currentStreak,
                          bestStreak: longestStreak,
                          consistencyRate: recentRate,
                          bounceBackRate: bounceBack.rate,
                          categoryColor: categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Sections: 28-Day Grid + Why Statistics
                    Opacity(
                      opacity: _sectionsOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _sectionsSlide.value),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader('Past 4 Weeks History'),
                            _RollingCalendarGrid(
                              today: today,
                              createdDay: createdDay,
                              completedDays: dateSet,
                              reflectionsMap: reflectionsMap,
                              isScheduled: isDayScheduled,
                              categoryColor: categoryColor,
                              inspectedDay: inspected,
                              onSelectDay: (day) =>
                                  setState(() => _inspectedDay = day),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            const _SectionHeader('Why it slipped & Resilience'),
                            _HeroWhyStatistics(
                              reasons: reasons,
                              bounceBack: bounceBack,
                              categoryColor: categoryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Header — back + generic title + edit, on a hairline-bottomed bar
// ---------------------------------------------------------------------------

class _HabitDetailHeader extends StatelessWidget {
  const _HabitDetailHeader({required this.onEdit});

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            iconSize: AppSizes.iconLg,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              'Habit Detail',
              style: context.textTheme.headlineMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              iconSize: 22,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Identity — icon, name, "Category • Frequency"
// ---------------------------------------------------------------------------

class _HabitIdentity extends StatelessWidget {
  const _HabitIdentity({
    required this.habit,
    required this.categoryName,
    required this.iconKey,
    required this.categoryColor,
    this.usualMinute,
  });

  final Habit habit;
  final String categoryName;
  final String? iconKey;
  final Color categoryColor;
  final int? usualMinute;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: categoryColor.withValues(alpha: 0.28),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: categoryColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                AppIconRegistry.resolve(iconKey),
                size: 32,
                color: categoryColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            habit.name,
            style: context.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$categoryName • '
                '${frequencyLabel(habit.frequencyType, habit.frequencyConfig)}',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (usualMinute != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${AppStrings.usuallyDoneAround} ${clockLabel(usualMinute!)}',
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.textDisabled,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Momentum Gauge — Centerpiece flame streak & sub-metrics trio
// ---------------------------------------------------------------------------

class _HeroMomentumGauge extends StatelessWidget {
  const _HeroMomentumGauge({
    required this.currentStreak,
    required this.bestStreak,
    required this.consistencyRate,
    required this.bounceBackRate,
    required this.categoryColor,
  });

  final int currentStreak;
  final int bestStreak;
  final int consistencyRate;
  final int bounceBackRate;
  final Color categoryColor;

  String _motto() {
    if (currentStreak >= 30) {
      return 'Unstoppable rhythm • Habit deeply ingrained.';
    }
    if (currentStreak >= 14) {
      return 'Strong momentum • Consistency is second nature.';
    }
    if (currentStreak >= 7) {
      return 'Solid weekly rhythm • Keep the fire burning.';
    }
    if (currentStreak > 0) {
      return 'Active streak • Every single day compounds.';
    }
    return 'Your next streak starts with one small step today.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.7),
          width: 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Centerpiece streak display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentTerracotta.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.accentTerracotta.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 28,
                    color: AppColors.accentTerracotta,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$currentStreak',
                        style: context.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 40,
                          height: 1.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        currentStreak == 1 ? 'DAY' : 'DAYS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.accentTerracotta,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'CURRENT STREAK',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _motto(),
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(
              color: AppColors.border.withValues(alpha: 0.5),
              height: 1,
            ),
          ),

          // Sub-metrics trio strip
          Row(
            children: [
              Expanded(
                child: _SubMetricCol(
                  icon: Icons.military_tech_outlined,
                  iconColor: AppColors.clay,
                  value: '$bestStreak d',
                  label: 'All-Time Best',
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _SubMetricCol(
                  icon: Icons.pie_chart_outline_rounded,
                  iconColor: categoryColor,
                  value: '$consistencyRate%',
                  label: 'Consistency',
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              Expanded(
                child: _SubMetricCol(
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.accentTerracotta,
                  value: '$bounceBackRate%',
                  label: 'Bounce-Back',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubMetricCol extends StatelessWidget {
  const _SubMetricCol({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: AppColors.textDisabled,
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section Header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 28-Day Rolling Calendar Grid with Touch Inspection Micro-Card
// ---------------------------------------------------------------------------

class _RollingCalendarGrid extends StatelessWidget {
  const _RollingCalendarGrid({
    required this.today,
    required this.createdDay,
    required this.completedDays,
    required this.reflectionsMap,
    required this.isScheduled,
    required this.categoryColor,
    required this.inspectedDay,
    required this.onSelectDay,
  });

  final DateTime today;
  final DateTime createdDay;
  final Set<DateTime> completedDays;
  final Map<DateTime, HabitReflection> reflectionsMap;
  final bool Function(DateTime) isScheduled;
  final Color categoryColor;
  final DateTime inspectedDay;
  final ValueChanged<DateTime> onSelectDay;

  static const _weekHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    // 4 weeks (28 days) ending on the current week's Sunday
    final currentWeekStart = today.startOfWeek;
    final gridStart = currentWeekStart.addDays(-21);
    final allDays = List.generate(28, (i) => gridStart.addDays(i));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.65),
          width: 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Weekday column header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final h in _weekHeaders)
                SizedBox(
                  width: 38,
                  child: Text(
                    h,
                    textAlign: TextAlign.center,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // 4 weeks of rows (7 days each)
          for (int week = 0; week < 4; week++) ...[
            if (week > 0) const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int d = 0; d < 7; d++) ...[
                  _CalendarDayCell(
                    day: allDays[week * 7 + d],
                    today: today,
                    isCompleted: completedDays.contains(allDays[week * 7 + d]),
                    hasReflection:
                        reflectionsMap.containsKey(allDays[week * 7 + d]),
                    isScheduled: isScheduled(allDays[week * 7 + d]),
                    isSelected: inspectedDay == allDays[week * 7 + d],
                    categoryColor: categoryColor,
                    onTap: () => onSelectDay(allDays[week * 7 + d]),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Divider(
            color: AppColors.border.withValues(alpha: 0.5),
            height: 1,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Touch Inspection Micro-Card
          _DayInspectionCard(
            day: inspectedDay,
            today: today,
            isCompleted: completedDays.contains(inspectedDay),
            isScheduled: isScheduled(inspectedDay),
            reflection: reflectionsMap[inspectedDay],
            categoryColor: categoryColor,
          ),
        ],
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.today,
    required this.isCompleted,
    required this.hasReflection,
    required this.isScheduled,
    required this.isSelected,
    required this.categoryColor,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final bool isCompleted;
  final bool hasReflection;
  final bool isScheduled;
  final bool isSelected;
  final Color categoryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    final isFuture = day.isAfter(today);

    Color bg;
    Border? border;
    Color textColor;

    if (isCompleted) {
      bg = categoryColor;
      textColor = Colors.white;
      if (isSelected) {
        border = Border.all(color: AppColors.textPrimary, width: 2);
      }
    } else if (hasReflection) {
      bg = AppColors.clay.withValues(alpha: 0.16);
      border = Border.all(
        color: isSelected ? AppColors.textPrimary : AppColors.clay,
        width: isSelected ? 2 : 1.25,
      );
      textColor = AppColors.clay;
    } else if (isScheduled && !isFuture) {
      bg = AppColors.surfaceVariant.withValues(alpha: 0.4);
      border = Border.all(
        color: isSelected
            ? AppColors.textPrimary
            : (isToday
                ? categoryColor
                : AppColors.border.withValues(alpha: 0.6)),
        width: isSelected ? 2 : (isToday ? 1.5 : 0.75),
      );
      textColor = isToday ? AppColors.textPrimary : AppColors.textDisabled;
    } else {
      // Future or not scheduled
      bg = Colors.transparent;
      if (isSelected) {
        border = Border.all(color: AppColors.textPrimary, width: 2);
      }
      textColor = isFuture
          ? AppColors.textDisabled.withValues(alpha: 0.35)
          : AppColors.textDisabled.withValues(alpha: 0.45);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(9),
          border: border,
          boxShadow: isCompleted
              ? [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCompleted || isToday || hasReflection
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: textColor,
              ),
            ),
            // Reflection indicator mini stone pebble
            if (hasReflection && !isCompleted)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.clay,
                  ),
                ),
              ),
            // Tiny checkmark for completed
            if (isCompleted)
              Positioned(
                bottom: 2.5,
                child: const Icon(
                  Icons.check_rounded,
                  size: 9,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Touch Inspection Micro-Card
// ---------------------------------------------------------------------------

class _DayInspectionCard extends StatelessWidget {
  const _DayInspectionCard({
    required this.day,
    required this.today,
    required this.isCompleted,
    required this.isScheduled,
    required this.reflection,
    required this.categoryColor,
  });

  final DateTime day;
  final DateTime today;
  final bool isCompleted;
  final bool isScheduled;
  final HabitReflection? reflection;
  final Color categoryColor;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_weekdays[day.weekday - 1]}, ${_months[day.month - 1]} ${day.day}'
        '${day == today ? ' (Today)' : ''}';

    final isFuture = day.isAfter(today);

    Widget statusWidget;
    if (isCompleted) {
      statusWidget = Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: AppRadius.chip,
              border: Border.all(
                color: categoryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 13, color: categoryColor),
                const SizedBox(width: 4),
                Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Habit completed successfully.',
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (reflection != null) {
      List<String> reasonLabels = [];
      try {
        final keys = (jsonDecode(reflection!.reasonKeys) as List).cast<String>();
        reasonLabels = keys.map(findReasonLabel).toList();
      } catch (_) {}

      final stoneText = reasonLabels.isNotEmpty
          ? reasonLabels.join(' • ')
          : 'Reflected';

      statusWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.clay.withValues(alpha: 0.14),
                  borderRadius: AppRadius.chip,
                  border: Border.all(
                    color: AppColors.clay.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_rounded, size: 13, color: AppColors.clay),
                    const SizedBox(width: 4),
                    Text(
                      'Missed & Reflected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.clay,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  stoneText,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (reflection!.followUpAnswer != null &&
              reflection!.followUpAnswer!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Note: "${reflection!.followUpAnswer}"',
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    } else if (isScheduled && !isFuture) {
      statusWidget = Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.chip,
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 13,
                  color: AppColors.textDisabled,
                ),
                const SizedBox(width: 4),
                Text(
                  day == today ? 'Pending Today' : 'Missed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              day == today
                  ? 'Ready to complete today.'
                  : 'Scheduled but not recorded.',
              style: context.textTheme.bodySmall?.copyWith(
                color: AppColors.textDisabled,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      );
    } else if (isFuture) {
      statusWidget = Text(
        'Upcoming scheduled day.',
        style: context.textTheme.bodySmall?.copyWith(
          color: AppColors.textDisabled,
          fontSize: 11.5,
        ),
      );
    } else {
      statusWidget = Text(
        'Rest day • Not scheduled by frequency.',
        style: context.textTheme.bodySmall?.copyWith(
          color: AppColors.textDisabled,
          fontSize: 11.5,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateLabel,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          statusWidget,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Why Statistics & Resilience Section
// ---------------------------------------------------------------------------

class _HeroWhyStatistics extends StatelessWidget {
  const _HeroWhyStatistics({
    required this.reasons,
    required this.bounceBack,
    required this.categoryColor,
  });

  final List<ReasonFrequency> reasons;
  final ({int rate, int recoveredCount, int totalMisses}) bounceBack;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final total = reasons.fold<int>(0, (sum, r) => sum + r.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------------------
        // 1. Resilience & Bounce-Back Rate Card
        // ---------------------------------------------------------------------
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.65),
              width: 1,
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentTerracotta.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.accentTerracotta.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 24,
                    color: AppColors.accentTerracotta,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${bounceBack.rate}%',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentTerracotta,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Bounce-Back Rate',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bounceBack.totalMisses == 0
                          ? 'Flawless consistency! No scheduled days missed.'
                          : (bounceBack.recoveredCount > 0
                              ? 'Recovered the next day after ${bounceBack.recoveredCount} of ${bounceBack.totalMisses} slips.'
                              : 'Keep going! Every pause is data to bounce back from.'),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ---------------------------------------------------------------------
        // 2. Obstacles & Stone Breakdown
        // ---------------------------------------------------------------------
        if (reasons.isNotEmpty) ...[
          // Primary Obstacle Callout Card
          _PrimaryObstacleCard(
            topReason: reasons.first,
            totalReasons: total,
          ),

          const SizedBox(height: AppSpacing.md),

          // Stone Pebbles Breakdown & Ranked Bars
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.65),
                width: 1,
              ),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reflection stones distribution',
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Stone Pebble Chips
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final r in reasons)
                      _StonePebbleChip(
                        reason: r,
                        totalCount: total,
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),
                Divider(
                  color: AppColors.border.withValues(alpha: 0.5),
                  height: 1,
                ),
                const SizedBox(height: AppSpacing.md),

                // Progress Rows
                for (var i = 0; i < reasons.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  ReasonRow(reason: reasons[i], totalCount: total),
                ],
              ],
            ),
          ),
        ] else ...[
          // Empty State Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.65),
                width: 1,
              ),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 32,
                  color: AppColors.clay,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Flawless Momentum',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'No slip-ups logged for this habit yet. Whenever life gets in the way, Pause & Reflect stones will map your friction patterns here.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Primary Obstacle Card
// ---------------------------------------------------------------------------

class _PrimaryObstacleCard extends StatelessWidget {
  const _PrimaryObstacleCard({
    required this.topReason,
    required this.totalReasons,
  });

  final ReasonFrequency topReason;
  final int totalReasons;

  String _tacticalAdvice(String reasonKey) {
    return switch (reasonKey) {
      'low_energy' || 'poor_sleep' || 'felt_sick' || 'burned_out' || 'energy' =>
        'Energy dips are the primary friction. Consider an easier recovery version or scheduling earlier.',
      'too_busy' || 'unexpected_work' || 'meetings' || 'family' || 'time' =>
        'Time crunches disrupt this habit most. Try habit-stacking with an existing daily anchor.',
      'lost_motivation' || 'procrastinated' || 'forgot' || 'felt_overwhelmed' || 'couldnt_focus' || 'mind' =>
        'Motivation ebbs and flows. Lowering the activation threshold by 50% keeps streaks alive.',
      _ =>
        'External factors disrupt consistency. Preparing environment or cues the night before helps.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final display = reasonDisplayInfo(topReason.reason);
    final percent = totalReasons > 0
        ? ((topReason.count / totalReasons) * 100).round()
        : 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: display.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: display.color.withValues(alpha: 0.28),
          width: 1.25,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: display.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(display.icon, size: 16, color: display.color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRIMARY OBSTACLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: display.color,
                      ),
                    ),
                    Text(
                      '${display.label} ($percent% of misses)',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            _tacticalAdvice(topReason.reason),
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stone Pebble Chip
// ---------------------------------------------------------------------------

class _StonePebbleChip extends StatelessWidget {
  const _StonePebbleChip({
    required this.reason,
    required this.totalCount,
  });

  final ReasonFrequency reason;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final display = reasonDisplayInfo(reason.reason);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: display.color.withValues(alpha: 0.10),
        borderRadius: AppRadius.chip,
        border: Border.all(
          color: display.color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(display.icon, size: 13, color: display.color),
          const SizedBox(width: 5),
          Text(
            display.label,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: display.color,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: display.color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${reason.count}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: display.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
