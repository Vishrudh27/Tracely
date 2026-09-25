import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../core/widgets/tracely_shimmer.dart';
import '../../../../data/models/habit_models.dart';
import '../../../../data/database/daos/reflection_dao.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../widgets/completion_trend_chart.dart';
import '../widgets/overall_heatmap_card.dart';
import '../widgets/statistics_header.dart';
import '../widgets/most_common_reasons_card.dart';
import '../widgets/streak_display_card.dart';
import '../widgets/weekly_insights_card.dart';

/// Full Statistics screen, matching `statistics/code.html`.
///
/// Order: hero streak card, period chips, completion trend chart,
/// "Overall activity" heatmap, weekly insight, "what gets in the way".
/// Entrance animation: 1000ms total, single AnimationController.
class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _streakOpacity;
  late final Animation<double> _streakSlide;
  late final Animation<double> _streakCount; // count-up 0.0→1.0
  late final Animation<double> _chartOpacity;
  late final Animation<double> _chartSlide;
  late final Animation<double> _chartDraw; // line draw 0.0→1.0
  late final Animation<double> _heatmapOpacity;
  late final Animation<double> _heatmapSlide;
  late final Animation<double> _heatmapWave; // wave fill 0.0→1.0
  late final Animation<double> _insightOpacity;
  late final Animation<double> _insightSlide;
  late final Animation<double> _reasonsOpacity;
  late final Animation<double> _reasonsSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  void _setupAnimations() {
    // 1. Streak hero: 0.00–0.30
    _streakOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.25, curve: Curves.easeOut),
    );
    _streakSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.28, curve: Curves.easeOutCubic),
      ),
    );
    _streakCount = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.30, curve: Curves.easeOutCubic),
    );

    // 2. Completion trend chart: 0.20–0.50
    _chartOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.20, 0.40, curve: Curves.easeOut),
    );
    _chartSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.42, curve: Curves.easeOutCubic),
      ),
    );
    _chartDraw = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.55, curve: Curves.easeInOutCubic),
    );

    // 3. Overall activity heatmap: 0.40–0.65
    _heatmapOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.40, 0.58, curve: Curves.easeOut),
    );
    _heatmapSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.60, curve: Curves.easeOutCubic),
      ),
    );
    _heatmapWave = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.70, curve: Curves.easeInOutCubic),
    );

    // 4. Weekly insight: 0.55–0.75
    _insightOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.72, curve: Curves.easeOut),
    );
    _insightSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // 5. What gets in the way: 0.65–0.85
    _reasonsOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.65, 0.82, curve: Curves.easeOut),
    );
    _reasonsSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.85, curve: Curves.easeOutCubic),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const StatisticsHeader(),
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return heatmapAsync.when(
                    loading: () => _buildLoadingState(),
                    error: (err, stack) => _buildLoadingState(),
                    data: (heatmapData) {
                      if (heatmapData.isEmpty) return _buildEmptyState();

                      return _buildContent(
                        heatmapData: heatmapData,
                        streakAsync: streakAsync,
                        insightAsync: insightAsync,
                        reasonsAsync: reasonsAsync,
                        trendAsync: trendAsync,
                        breakdownsAsync: breakdownsAsync,
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
          TracelyShimmer(
            width: double.infinity,
            height: 160,
            borderRadius: AppRadius.card,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          TracelyShimmer(
            width: double.infinity,
            height: AppSizes.chartHeight + 60,
            borderRadius: AppRadius.card,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          TracelyShimmer(
            width: double.infinity,
            height: 160,
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
  }) {
    final streak = streakAsync.asData?.value;
    final insight = insightAsync.asData?.value;
    final reasons = reasonsAsync.asData?.value ?? <ReasonFrequency>[];
    final trendData = trendAsync.asData?.value ?? <DailyCompletion>[];
    final breakdowns = breakdownsAsync.asData?.value ?? <HabitBreakdown>[];
    final totalCompletions =
        breakdowns.fold<int>(0, (sum, b) => sum + b.totalCompletions);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.massive),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),

          // 1. Streak hero card
          if (streak != null)
            StreakDisplayCard(
              streak: streak,
              totalCompletions: totalCompletions,
              opacity: _streakOpacity.value,
              translateY: _streakSlide.value,
              countProgress: _streakCount.value,
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: TracelyShimmer(
                width: double.infinity,
                height: 160,
                borderRadius: AppRadius.card,
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),

          // 2. Period chips
          _PeriodSelector(),

          const SizedBox(height: AppSpacing.xxl),

          // 3. Completion trend chart
          CompletionTrendChart(
            trendData: trendData,
            opacity: _chartOpacity.value,
            translateY: _chartSlide.value,
            drawProgress: _chartDraw.value,
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 4. Overall activity
          SectionHeader(
            title: 'Overall activity',
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          ),
          const SizedBox(height: AppSpacing.sm),
          OverallHeatmapCard(
            heatmapData: heatmapData,
            opacity: _heatmapOpacity.value,
            translateY: _heatmapSlide.value,
            waveProgress: _heatmapWave.value,
          ),

          const SizedBox(height: AppSpacing.xxl),

          // 5. Weekly insight
          if (insight != null)
            WeeklyInsightsCard(
              insight: insight,
              opacity: _insightOpacity.value,
              translateY: _insightSlide.value,
            ),

          const SizedBox(height: AppSpacing.xxl),

          // 6. What gets in the way (hidden if < 3 entries)
          MostCommonReasonsCard(
            reasons: reasons,
            opacity: _reasonsOpacity.value,
            translateY: _reasonsSlide.value,
          ),
        ],
      ),
    );
  }
}

/// 7/30/90-day period toggle, controlling [trendDaysProvider].
class _PeriodSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(trendDaysProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        children: [7, 30, 90].map((days) {
          final isSelected = selected == days;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => ref.read(trendDaysProvider.notifier).select(days),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                height: AppSizes.chipHeight,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: AppRadius.small,
                  boxShadow: isSelected ? AppShadows.sm : null,
                ),
                child: Text(
                  '$days days',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
