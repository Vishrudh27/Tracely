import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/utils/habit_schedule.dart';
import '../../../../core/utils/streak_calculator.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/database/daos/reflection_dao.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../analytics/presentation/widgets/most_common_reasons_card.dart';

/// A single habit's story — identity, streak trio, a year of history, and
/// the reasons it slipped.
///
/// Reached by tapping a habit in the Habits screen. Fully reactive: toggling
/// the habit's completion anywhere else in the app updates this screen live.
///
/// Deleting lives on the Edit screen, not here — Stitch's header carries only
/// back + edit.
class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen>
    with SingleTickerProviderStateMixin {
  /// Columns in the "This year" heatmap — 16 weeks, matching Stitch's grid.
  static const _weeks = 16;

  late final AnimationController _controller;
  late final Animation<double> _identityOpacity;
  late final Animation<double> _identityScale;
  late final Animation<double> _statsOpacity;
  late final Animation<double> _statsSlide;
  late final Animation<double> _sectionsOpacity;
  late final Animation<double> _sectionsSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
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
        _HabitDetailHeader(onEdit: null),
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

    final category = categoryAsync.asData?.value;
    final completions = completionsAsync.asData?.value ?? const [];
    final dates = completions.map((c) => c.completedDate).toList();

    bool isDayScheduled(DateTime day) =>
        isScheduledOn(habit.frequencyType, habit.frequencyConfig, day);
    final currentStreak =
        StreakCalculator.currentStreak(dates, isScheduled: isDayScheduled);
    final longestStreak =
        StreakCalculator.longestStreak(dates, isScheduled: isDayScheduled);

    final today = DateTime.now().startOfDay;
    final createdDay = habit.createdAt.startOfDay;
    final dateSet = dates.map((d) => d.startOfDay).toSet();

    final recentRate = recentCompletionRate(
      frequencyType: habit.frequencyType,
      frequencyConfig: habit.frequencyConfig,
      today: today,
      createdDay: createdDay,
      completedDays: dateSet,
    );

    // 16 weeks of columns, Monday-first, ending with the current week.
    final gridStart = today.startOfWeek.addDays(-(_weeks - 1) * 7);

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
                    Opacity(
                      opacity: _identityOpacity.value,
                      child: Transform.scale(
                        scale: _identityScale.value,
                        child: _HabitIdentity(
                          habit: habit,
                          categoryName: category?.name ?? 'General',
                          iconKey: habit.emoji ?? category?.emoji,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Opacity(
                      opacity: _statsOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _statsSlide.value),
                        child: _StatTrio(
                          currentStreak: currentStreak,
                          bestStreak: longestStreak,
                          recentRate: recentRate,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Opacity(
                      opacity: _sectionsOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _sectionsSlide.value),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader('This year'),
                            _YearHeatmap(
                              start: gridStart,
                              weeks: _weeks,
                              today: today,
                              createdDay: createdDay,
                              completedDays: dateSet,
                              frequencyType: habit.frequencyType,
                              frequencyConfig: habit.frequencyConfig,
                            ),
                            if (reasons.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xxl),
                              _SectionHeader('Why it slipped'),
                              _WhyItSlipped(reasons: reasons),
                            ],
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

  /// Null while the habit is loading or already gone — the edit button is
  /// hidden rather than disabled, since there is nothing to edit.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
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
  });

  final Habit habit;
  final String categoryName;

  /// The habit's own icon, falling back to its category's.
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Icon(
            AppIconRegistry.resolve(iconKey),
            size: AppSizes.iconXxl,
            color: AppColors.textPrimary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            habit.name,
            style: context.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$categoryName • '
            '${frequencyLabel(habit.frequencyType, habit.frequencyConfig)}',
            style: context.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat trio — current streak, best streak, last 30 days
// ---------------------------------------------------------------------------

class _StatTrio extends StatelessWidget {
  const _StatTrio({
    required this.currentStreak,
    required this.bestStreak,
    required this.recentRate,
  });

  final int currentStreak;
  final int bestStreak;
  final int recentRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            value: '$currentStreak',
            label: 'Current streak',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _StatCard(value: '$bestStreak', label: 'Best streak')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(value: '$recentRate%', label: 'Last 30 days'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          // Cards without an icon reserve its height so all three line up.
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Icon(
                icon,
                size: AppSizes.iconSm,
                color: AppColors.accentTerracotta,
              ),
            )
          else
            const SizedBox(height: AppSizes.iconSm + AppSpacing.xs),
          // Three cards across is tight on a 360dp screen — scale down rather
          // than clip "100%" or "Current streak".
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: context.textTheme.displayMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: context.textTheme.bodySmall,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(title, style: context.textTheme.titleMedium),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// "This year" heatmap — 16 Monday-first columns of this habit's history
// ---------------------------------------------------------------------------

class _YearHeatmap extends StatelessWidget {
  const _YearHeatmap({
    required this.start,
    required this.weeks,
    required this.today,
    required this.createdDay,
    required this.completedDays,
    required this.frequencyType,
    required this.frequencyConfig,
  });

  /// Monday of the leftmost column.
  final DateTime start;
  final int weeks;
  final DateTime today;
  final DateTime createdDay;
  final Set<DateTime> completedDays;
  final String frequencyType;
  final String? frequencyConfig;

  static const _cell = 14.0;
  static const _gap = 3.0;
  static const _step = _cell + _gap;
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  // Monday-first, with alternating rows blank — same as Stitch's M/W/F/S.
  static const _dayLabels = ['M', '', 'W', '', 'F', '', 'S'];

  /// A single habit is either done or not, so only the two ends of the shared
  /// brown ramp are used; the legend still shows all five for continuity with
  /// Statistics.
  ///
  /// Days outside the habit's schedule are blank, not misses — a Mon–Fri
  /// habit shouldn't look like it failed every weekend.
  Color _cellColor(DateTime day) {
    if (day.isAfter(today) ||
        day.isBefore(createdDay) ||
        !isScheduledOn(frequencyType, frequencyConfig, day)) {
      return Colors.transparent;
    }
    return completedDays.contains(day)
        ? AppColors.heatmap.last
        : AppColors.heatmap.first;
  }

  @override
  Widget build(BuildContext context) {
    final gridWidth = weeks * _cell + (weeks - 1) * _gap;

    // A month label sits above the first column that starts in that month.
    final labels = <int, String>{};
    var lastMonth = -1;
    for (var c = 0; c < weeks; c++) {
      final month = start.addDays(c * 7).month;
      if (month != lastMonth) {
        labels[c] = _months[month - 1];
        lastMonth = month;
      }
    }
    // Column 0 always gets a label, so it collides when the grid happens to
    // start in the last week of a month. Two columns apart is ~34px — just
    // enough for a three-letter month.
    if (labels.containsKey(1) || labels.containsKey(2)) labels.remove(0);

    return _SectionCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: _cell + AppSpacing.sm),
                SizedBox(
                  width: gridWidth,
                  height: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final entry in labels.entries)
                        Positioned(
                          left: entry.key * _step,
                          child: Text(
                            entry.value,
                            style: context.textTheme.labelSmall
                                ?.copyWith(color: AppColors.textDisabled),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    for (var r = 0; r < 7; r++) ...[
                      if (r > 0) const SizedBox(height: _gap),
                      SizedBox(
                        width: _cell,
                        height: _cell,
                        child: Text(
                          _dayLabels[r],
                          textAlign: TextAlign.center,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: AppColors.textDisabled,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                Row(
                  children: [
                    for (var c = 0; c < weeks; c++) ...[
                      if (c > 0) const SizedBox(width: _gap),
                      Column(
                        children: [
                          for (var r = 0; r < 7; r++) ...[
                            if (r > 0) const SizedBox(height: _gap),
                            Container(
                              width: _cell,
                              height: _cell,
                              decoration: BoxDecoration(
                                color: _cellColor(start.addDays(c * 7 + r)),
                                borderRadius: BorderRadius.circular(3.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _HeatmapLegend(),
          ],
        ),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.labelSmall
        ?.copyWith(color: AppColors.textDisabled);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Less', style: style),
        const SizedBox(width: AppSpacing.xs),
        for (final color in AppColors.heatmap) ...[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ],
        const SizedBox(width: AppSpacing.xs),
        Text('More', style: style),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// "Why it slipped" — this habit's own Pause & Reflect reasons
// ---------------------------------------------------------------------------

class _WhyItSlipped extends StatelessWidget {
  const _WhyItSlipped({required this.reasons});

  final List<ReasonFrequency> reasons;

  @override
  Widget build(BuildContext context) {
    final total = reasons.fold<int>(0, (sum, r) => sum + r.count);

    return _SectionCard(
      child: Column(
        children: [
          for (var i = 0; i < reasons.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            ReasonRow(reason: reasons[i], totalCount: total),
          ],
        ],
      ),
    );
  }
}
