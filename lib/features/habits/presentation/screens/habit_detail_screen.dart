import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/utils/streak_calculator.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/habit_repository.dart';

/// A single habit's story — streak, stats, and a 4-week visual history.
///
/// Reached by tapping a habit in the Habits screen. Fully reactive: toggling
/// the habit's completion anywhere else in the app updates this screen live.
class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heroOpacity;
  late final Animation<double> _heroScale;
  late final Animation<double> _statsOpacity;
  late final Animation<double> _statsSlide;
  late final Animation<double> _gridOpacity;
  late final Animation<double> _gridSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _heroScale = Tween<double>(begin: 0.85, end: 1.0).animate(
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
    _gridOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.90, curve: Curves.easeOut),
    );
    _gridSlide = Tween<double>(begin: 16, end: 0).animate(
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
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              color: AppColors.textSecondary,
            ),
          ),
        ),
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

    final category = categoryAsync.asData?.value;
    final completions = completionsAsync.asData?.value ?? const [];
    final dates = completions.map((c) => c.completedDate).toList();

    final currentStreak = StreakCalculator.currentStreak(dates);
    final longestStreak = StreakCalculator.longestStreak(dates);

    final todayNorm = DateTime.now().startOfDay;
    final dateSet = dates.map((d) => d.startOfDay).toSet();

    // Sunday-first week, matching the grid's S-M-T-W-T-F-S labels below.
    final sundayThisWeek = todayNorm.addDays(-(todayNorm.weekday % 7));
    var thisWeekCount = 0;
    for (var i = 0; i < 7; i++) {
      final d = sundayThisWeek.addDays(i);
      if (!d.isAfter(todayNorm) && dateSet.contains(d)) thisWeekCount++;
    }

    // This month: 1st through today.
    final daysInMonth = todayNorm.endOfMonth.day;
    var thisMonthCount = 0;
    for (var day = 1; day <= todayNorm.day; day++) {
      if (dateSet.contains(DateTime(todayNorm.year, todayNorm.month, day))) {
        thisMonthCount++;
      }
    }

    // 4-week grid, Sunday-first, ending on the Saturday of the current week.
    final gridStart = sundayThisWeek.addDays(-21);
    final gridDays = List.generate(28, (i) => gridStart.addDays(i));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HabitDetailHeader(habit: habit, category: category),
                  Opacity(
                    opacity: _heroOpacity.value,
                    child: Transform.scale(
                      scale: _heroScale.value,
                      child: _StreakHero(streak: currentStreak),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Opacity(
                    opacity: _statsOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _statsSlide.value),
                      child: _StatsGrid(
                        longestStreak: longestStreak,
                        thisWeek: thisWeekCount,
                        thisMonth: thisMonthCount,
                        daysInMonth: daysInMonth,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Opacity(
                    opacity: _gridOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _gridSlide.value),
                      child: _MonthlyGrid(
                        days: gridDays,
                        completedDays: dateSet,
                        today: todayNorm,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.massive),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HabitDetailHeader extends StatelessWidget {
  const _HabitDetailHeader({required this.habit, this.category});

  final Habit habit;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final color =
        category != null ? Color(category!.colorValue) : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textSecondary,
          ),
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(
              AppIconRegistry.resolve(habit.emoji ?? category?.emoji),
              color: color,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              habit.name,
              style: context.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: AppColors.surface,
            iconColor: AppColors.textSecondary,
            onSelected: (value) {
              if (value == 'edit') {
                context.push('/habits/edit/${habit.id}');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit habit')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.accentTerracotta,
            size: AppSizes.iconXl,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$streak',
            style: context.textTheme.displayLarge?.copyWith(
              fontSize: 72,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.fab,
            ),
            child: Text(
              'DAY STREAK',
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.longestStreak,
    required this.thisWeek,
    required this.thisMonth,
    required this.daysInMonth,
  });

  final int longestStreak;
  final int thisWeek;
  final int thisMonth;
  final int daysInMonth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          // Longest streak — full width, decorative trophy corner.
          Container(
            width: double.infinity,
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -12,
                  top: -12,
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 88,
                    color: AppColors.accentTerracotta.withValues(alpha: 0.08),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LONGEST STREAK',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '$longestStreak Days',
                          style: context.textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.accentTerracotta,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.star_rounded,
                        color: AppColors.accentTerracotta,
                        size: AppSizes.iconSm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'THIS WEEK',
                  value: thisWeek,
                  total: 7,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _StatCard(
                  label: 'THIS MONTH',
                  value: thisMonth,
                  total: daysInMonth,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$value',
                  style: context.textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                TextSpan(
                  text: ' / $total',
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyGrid extends StatelessWidget {
  const _MonthlyGrid({
    required this.days,
    required this.completedDays,
    required this.today,
  });

  final List<DateTime> days;
  final Set<DateTime> completedDays;
  final DateTime today;

  static const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        width: double.infinity,
        padding: AppSpacing.card,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A visual memory of your consistency',
              style: context.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Last 4 weeks',
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (var week = 0; week < 4; week++) ...[
              if (week > 0) const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final day = days[week * 7 + i];
                  final isFuture = day.isAfter(today);
                  final isCompleted = completedDays.contains(day);
                  return Container(
                    width: AppSizes.iconXl,
                    height: AppSizes.iconXl,
                    decoration: BoxDecoration(
                      color: isFuture
                          ? Colors.transparent
                          : (isCompleted
                              ? AppColors.primary
                              : AppColors.surfaceVariant),
                      borderRadius: AppRadius.small,
                      border: isFuture
                          ? Border.all(color: AppColors.border)
                          : null,
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weekdayLabels
                  .map(
                    (l) => SizedBox(
                      width: AppSizes.iconXl,
                      child: Text(
                        l,
                        textAlign: TextAlign.center,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
