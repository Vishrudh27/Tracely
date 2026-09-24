import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../core/widgets/tracely_shimmer.dart';
import '../../../../core/widgets/tracely_top_bar.dart';
import '../../../../data/models/habit_models.dart';
import '../../../../data/database/daos/reflection_dao.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../widgets/completion_trend_chart.dart';
import '../widgets/habit_breakdown_list.dart';
import '../widgets/monthly_calendar_view.dart';
import '../widgets/overall_heatmap_card.dart';
import '../widgets/statistics_header.dart';
import '../widgets/most_common_reasons_card.dart';
import '../widgets/streak_display_card.dart';
import '../widgets/weekly_insights_card.dart';

/// Full Statistics screen — Phase 3.
///
/// Entrance animation: 1200ms total, single AnimationController.
/// All 8 sections animate in with staggered intervals per §5.5.
///
/// Sections:
///   1. StatisticsHeader           (0.00–0.15)
///   2. OverallHeatmapCard         (0.08–0.40) + wave fill
///   3. StreakDisplayCard          (0.25–0.50) + count-up
///   4. WeeklyInsightsCard         (0.35–0.55)
///   5. MostCommonReasonsCard      (0.40–0.57) — hidden when < 3 entries
///   6. CompletionTrendChart       (0.45–0.75) + left→right draw
///   7. HabitBreakdownList         (0.60–0.82) staggered per item
///   8. MonthlyCalendarView        (0.72–0.95) + scale 0.97→1.0
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Section opacity + slide
  late final Animation<double> _headerOpacity;
  late final Animation<double> _headerSlide;
  late final Animation<double> _heatmapOpacity;
  late final Animation<double> _heatmapSlide;
  late final Animation<double> _heatmapWave;   // wave fill 0.0→1.0
  late final Animation<double> _streakOpacity;
  late final Animation<double> _streakSlide;
  late final Animation<double> _streakCount;   // count-up 0.0→1.0
  late final Animation<double> _insightOpacity;
  late final Animation<double> _insightSlide;
  late final Animation<double> _reasonsOpacity;
  late final Animation<double> _reasonsSlide;
  late final Animation<double> _chartOpacity;
  late final Animation<double> _chartSlide;
  late final Animation<double> _chartDraw;     // line draw 0.0→1.0
  late final Animation<double> _breakdownOpacity;
  late final Animation<double> _breakdownSlide;
  late final Animation<double> _calendarOpacity;
  late final Animation<double> _calendarScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  void _setupAnimations() {
    // 1. Header: 0.00–0.15
    _headerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.15, curve: Curves.easeOut),
    );
    _headerSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.18, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Heatmap: 0.08–0.40
    _heatmapOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.30, curve: Curves.easeOut),
    );
    _heatmapSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.08, 0.30, curve: Curves.easeOutCubic),
      ),
    );
    _heatmapWave = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.40, curve: Curves.easeInOutCubic),
    );

    // 3. Streak: 0.25–0.50
    _streakOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.45, curve: Curves.easeOut),
    );
    _streakSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _streakCount = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.50, curve: Curves.easeOutCubic),
    );

    // 4. Insight: 0.35–0.55
    _insightOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.55, curve: Curves.easeOut),
    );
    _insightSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.58, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Reasons: 0.40–0.57
    _reasonsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.40, 0.55, curve: Curves.easeOut),
    );
    _reasonsSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.57, curve: Curves.easeOutCubic),
      ),
    );

    // 6. Chart: 0.45–0.75
    _chartOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.60, curve: Curves.easeOut),
    );
    _chartSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    _chartDraw = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.52, 0.75, curve: Curves.easeInOutCubic),
    );

    // 7. Breakdown: 0.60–0.82
    _breakdownOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 0.75, curve: Curves.easeOut),
    );
    _breakdownSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.78, curve: Curves.easeOutCubic),
      ),
    );

    // 8. Calendar: 0.72–0.95
    _calendarOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.72, 0.90, curve: Curves.easeOut),
    );
    _calendarScale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.72, 0.95, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heatmapAsync = ref.watch(heatmapDataProvider);
    final streakAsync = ref.watch(overallStreakProvider);
    final insightAsync = ref.watch(weeklyInsightProvider);
    final reasonsAsync = ref.watch(mostCommonReasonsProvider);
    final trendAsync = ref.watch(completionTrendProvider);
    final breakdownsAsync = ref.watch(habitBreakdownsProvider);
    final daysSinceStart = ref.watch(daysSinceStartProvider).asData?.value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            TracelyTopBar(onAvatarTap: () => context.push(AppRouter.settings)),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Use heatmap as the primary data indicator
                  return heatmapAsync.when(
                    loading: () => _buildLoadingState(),
                    error: (err, stack) => _buildLoadingState(),
                    data: (heatmapData) {
                      final hasData = heatmapData.isNotEmpty;

                      if (!hasData) {
                        return _buildEmptyState();
                      }

                      return _buildContent(
                        heatmapData: heatmapData,
                        streakAsync: streakAsync,
                        insightAsync: insightAsync,
                        reasonsAsync: reasonsAsync,
                        trendAsync: trendAsync,
                        breakdownsAsync: breakdownsAsync,
                        daysSinceStart: daysSinceStart,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const TracelyShimmerLine(width: 160, height: 28),
          const SizedBox(height: AppSpacing.sm),
          const TracelyShimmerLine(width: 200, height: 16),
          const SizedBox(height: AppSpacing.xxl),
          TracelyShimmer(
            width: double.infinity,
            height: 160,
            borderRadius: AppRadius.card,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          TracelyShimmer(
            width: double.infinity,
            height: 120,
            borderRadius: AppRadius.card,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          TracelyShimmer(
            width: double.infinity,
            height: 100,
            borderRadius: AppRadius.card,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          TracelyShimmer(
            width: double.infinity,
            height: AppSizes.chartHeight + 60,
            borderRadius: AppRadius.card,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const TracelyEmptyState(
      icon: Icons.bar_chart_rounded,
      title: 'Your story starts here.',
      body:
          'Your journey starts with the first check. Once you complete a habit, your story will appear here.',
    );
  }

  Widget _buildContent({
    required Map<DateTime, double> heatmapData,
    required AsyncValue<StreakData> streakAsync,
    required AsyncValue<WeeklyInsight> insightAsync,
    required AsyncValue<List<ReasonFrequency>> reasonsAsync,
    required AsyncValue<List<DailyCompletion>> trendAsync,
    required AsyncValue<List<HabitBreakdown>> breakdownsAsync,
    required int daysSinceStart,
  }) {
    final streak = streakAsync.asData?.value;
    final insight = insightAsync.asData?.value;
    final reasons = reasonsAsync.asData?.value ?? <ReasonFrequency>[];
    final trendData = trendAsync.asData?.value ?? <DailyCompletion>[];
    final breakdowns = breakdownsAsync.asData?.value ?? <HabitBreakdown>[];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // 1. Header
              StatisticsHeader(
                opacity: _headerOpacity.value,
                translateY: _headerSlide.value,
                daysSinceStart: daysSinceStart,
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              // 2. Heatmap
              OverallHeatmapCard(
                heatmapData: heatmapData,
                opacity: _heatmapOpacity.value,
                translateY: _heatmapSlide.value,
                waveProgress: _heatmapWave.value,
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              // 3. Streak
              if (streak != null)
                StreakDisplayCard(
                  streak: streak,
                  opacity: _streakOpacity.value,
                  translateY: _streakSlide.value,
                  countProgress: _streakCount.value,
                )
              else
                TracelyShimmer(
                  width: double.infinity,
                  height: 120,
                  borderRadius: AppRadius.card,
                ),

              const SizedBox(height: AppSpacing.sectionGap),

              // 4. Weekly insight
              if (insight != null)
                WeeklyInsightsCard(
                  insight: insight,
                  opacity: _insightOpacity.value,
                  translateY: _insightSlide.value,
                ),

              const SizedBox(height: AppSpacing.sectionGap),

              // 5. Most common reasons (hidden if < 3 entries)
              MostCommonReasonsCard(
                reasons: reasons,
                opacity: _reasonsOpacity.value,
                translateY: _reasonsSlide.value,
              ),

              // Only add spacing if the card is actually visible
              if (reasons.length >= 3)
                const SizedBox(height: AppSpacing.sectionGap),

              // 6. Completion trend chart
              CompletionTrendChart(
                trendData: trendData,
                opacity: _chartOpacity.value,
                translateY: _chartSlide.value,
                drawProgress: _chartDraw.value,
              ),

              const SizedBox(height: AppSpacing.sectionGap),
            ],
          ),
        ),

        // 7. Habit breakdown list (staggered items)
        if (breakdowns.isNotEmpty)
          SliverToBoxAdapter(
            child: HabitBreakdownList(
              breakdowns: breakdowns,
              opacity: _breakdownOpacity.value,
              translateY: _breakdownSlide.value,
              controller: _controller,
              intervalStart: 0.60,
              intervalEnd: 0.82,
            ),
          ),

        // 8. Monthly calendar
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sectionGap),
              MonthlyCalendarView(
                heatmapData: heatmapData,
                opacity: _calendarOpacity.value,
                scale: _calendarScale.value,
              ),
              const SizedBox(height: AppSpacing.massive),
            ],
          ),
        ),
      ],
    );
  }
}
