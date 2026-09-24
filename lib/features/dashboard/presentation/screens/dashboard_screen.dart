import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../core/widgets/tracely_shimmer.dart';
import '../../../../core/widgets/tracely_top_bar.dart';
import '../../../../data/models/habit_models.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../../data/services/reflection_gate_service.dart';
import '../../../reflection/presentation/widgets/pause_and_reflect_sheet.dart';
import '../widgets/breathing_background.dart';
import '../widgets/daily_progress_card.dart';
import '../widgets/dashboard_greeting_section.dart';
import '../widgets/dashboard_motivation_footer.dart';
import '../widgets/habit_tile.dart';
import '../widgets/quick_stats_row.dart';
import '../widgets/recent_activity_section.dart';
import '../widgets/weekly_heatmap_preview.dart';

/// The Dashboard — Tracely's daily companion screen.
///
/// Entrance animation (total: 1200ms) uses a single AnimationController.
/// All child widgets receive animated values computed from Interval slices.
///
/// Also features:
/// - §6.6 Breathing background (ambient radial pulse)
/// - §6.7 Momentum nudge (subtle text when 60–99% complete)
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _greetingOpacity;
  late final Animation<double> _greetingSlide;
  late final Animation<double> _progressOpacity;
  late final Animation<double> _progressSlide;
  late final Animation<double> _habitsHeaderOpacity;
  late final Animation<double> _habitsHeaderSlide;
  late final Animation<double> _heatmapOpacity;
  late final Animation<double> _heatmapSlide;
  late final Animation<double> _activityOpacity;
  late final Animation<double> _activitySlide;
  late final Animation<double> _footerOpacity;
  late final Animation<double> _nudgeOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      _checkPauseAndReflect();
    });
  }

  void _setupAnimations() {
    // 1. Greeting: 0.0–0.20
    _greetingOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
    );
    _greetingSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Progress card: 0.10–0.40
    _progressOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.10, 0.40, curve: Curves.easeOut),
    );
    _progressSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Habits header: 0.25–0.45
    _habitsHeaderOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.45, curve: Curves.easeOut),
    );
    _habitsHeaderSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Weekly heatmap: 0.50–0.75
    _heatmapOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.75, curve: Curves.easeOut),
    );
    _heatmapSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Activity: 0.65–0.85
    _activityOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
    );
    _activitySlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.88, curve: Curves.easeOutCubic),
      ),
    );

    // 6. Footer: 0.80–1.0
    _footerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
    );

    // Momentum nudge: appears after everything else settles (0.85–1.0)
    _nudgeOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
    );
  }

  Future<void> _checkPauseAndReflect() async {
    // Only trigger if mounted and context is available
    if (!mounted) return;

    try {
      // Check if there were any habits missed yesterday
      final yesterday = ref.read(currentDateProvider).addDays(-1);
      final missedHabits = await ref
          .read(habitRepositoryProvider)
          .getMissedHabitsForDate(yesterday);

      if (!mounted || missedHabits.isEmpty) return;

      // Gate: once per calendar day, however the sheet is answered.
      final shouldShow = await ReflectionGateService.shouldShowPauseAndReflect();
      if (!mounted || !shouldShow) return;

      await ReflectionGateService.markPauseAndReflectShown();
      if (!mounted) return;

      await PauseAndReflectSheet.show(
        context: context,
        missedHabits: missedHabits,
      );
    } catch (_) {
      // An optional reflection prompt must never take the dashboard down.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleHabit(int habitId) async {
    final today = ref.read(currentDateProvider);
    await ref.read(habitRepositoryProvider).toggleCompletion(habitId, today);
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(todaysHabitsProvider);
    final progressAsync = ref.watch(todaysProgressProvider);
    final heatmapAsync = ref.watch(weeklyHeatmapProvider);
    final activityAsync = ref.watch(recentCompletionsProvider);
    final streakAsync = ref.watch(overallStreakProvider);

    final progress = progressAsync.asData?.value ??
        const DailyProgress(completedCount: 0, totalCount: 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // §6.6 Breathing background — ambient radial pulse
          BreathingBackground(
            weeklyCompletionRate: progress.percentage,
          ),

          SafeArea(
            child: Column(
              children: [
                TracelyTopBar(onAvatarTap: () => context.push(AppRouter.settings)),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return habitsAsync.when(
                        loading: () => _buildLoadingState(),
                        error: (err, stack) => _buildErrorState(err),
                        data: (habits) {
                          if (habits.isEmpty) {
                            return _buildEmptyState();
                          }
                          return _buildLoadedState(
                            habits: habits,
                            progress: progress,
                            heatmapAsync: heatmapAsync,
                            activityAsync: activityAsync,
                            currentStreak:
                                streakAsync.asData?.value.currentStreak ?? 0,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const TracelyShimmerLine(width: 160, height: 28),
          const SizedBox(height: AppSpacing.sm),
          const TracelyShimmerLine(width: 120, height: 16),
          const SizedBox(height: AppSpacing.xxl),
          TracelyShimmer(
            width: double.infinity,
            height: 130,
            borderRadius: AppRadius.card,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TracelyShimmerLine(width: 140, height: 18),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TracelyShimmer(
                width: double.infinity,
                height: AppSizes.cardMinHeight,
                borderRadius: AppRadius.card,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  Widget _buildErrorState(Object error) {
    return TracelyEmptyState(
      icon: Icons.cloud_off_rounded,
      title: AppStrings.errorDashboardTitle,
      body: AppStrings.errorDashboardBody,
      ctaLabel: AppStrings.errorDashboardCta,
      onCta: () => ref.invalidate(todaysHabitsProvider),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Opacity(
      opacity: _greetingOpacity.value,
      child: TracelyEmptyState(
        icon: Icons.self_improvement_rounded,
        title: AppStrings.emptyDashboardTitle,
        body: AppStrings.emptyDashboardBody,
        ctaLabel: AppStrings.emptyDashboardCta,
        onCta: () => context.push(AppRouter.addHabit),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loaded state
  // ---------------------------------------------------------------------------

  Widget _buildLoadedState({
    required List<HabitWithCompletion> habits,
    required DailyProgress progress,
    required AsyncValue<List<DayCompletion>> heatmapAsync,
    required AsyncValue<List<CompletionWithHabit>> activityAsync,
    required int currentStreak,
  }) {
    final heatmap = heatmapAsync.asData?.value ?? [];
    final activity = activityAsync.asData?.value ?? [];
    final weeklyConsistency = heatmap.isEmpty
        ? 0.0
        : heatmap.map((d) => d.completionPercentage).reduce((a, b) => a + b) /
            heatmap.length;

    // §6.7 Momentum nudge: show when 60–99% done
    final showNudge =
        !progress.isEmpty && !progress.allDone && progress.percentage >= 0.6;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // 1. Greeting
              DashboardGreetingSection(
                opacity: _greetingOpacity.value,
                translateY: _greetingSlide.value,
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              // 2. Daily Progress Ring
              DailyProgressCard(
                progress: progress,
                controller: _controller,
                cardOpacity: _progressOpacity.value,
                cardTranslateY: _progressSlide.value,
              ),

              // §6.7 Momentum nudge
              if (showNudge)
                AnimatedOpacity(
                  opacity: _nudgeOpacity.value,
                  duration: AppDurations.medium,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      left: AppSpacing.xxl,
                    ),
                    child: Text(
                      'Almost there — just ${progress.remaining} left.',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.sectionGap),

              // 3. Today's Habits header
              Opacity(
                opacity: _habitsHeaderOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _habitsHeaderSlide.value),
                  child: SectionHeader(
                    title: AppStrings.sectionTodaysHabits,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xs,
                    ),
                    trailing: Text(
                      '${habits.where((h) => h.isCompletedToday).length}/${habits.length}',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),

        // 3b. Habit tiles (staggered)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              return AnimatedListItem(
                controller: _controller,
                index: i,
                totalItems: habits.length,
                intervalStart: 0.30,
                intervalEnd: 0.70,
                child: HabitTile(
                  habit: habits[i],
                  onToggle: () => _toggleHabit(habits[i].habitId),
                ),
              );
            },
            childCount: habits.length,
          ),
        ),

        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sectionGap),

              // 4. Weekly Heatmap
              WeeklyHeatmapPreview(
                days: heatmap,
                opacity: _heatmapOpacity.value,
                translateY: _heatmapSlide.value,
                onTap: () => context.go(AppRouter.statistics),
              ),

              const SizedBox(height: AppSpacing.sm),

              // 4b. Quick stat chips — streak + weekly consistency
              QuickStatsRow(
                currentStreak: currentStreak,
                weeklyConsistency: weeklyConsistency,
                opacity: _heatmapOpacity.value,
                translateY: _heatmapSlide.value,
              ),

              if (activity.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sectionGap),

                // 5. Recent Activity
                RecentActivitySection(
                  completions: activity,
                  opacity: _activityOpacity.value,
                  translateY: _activitySlide.value,
                ),
              ],

              // 6. Motivation footer
              DashboardMotivationFooter(
                opacity: _footerOpacity.value,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
