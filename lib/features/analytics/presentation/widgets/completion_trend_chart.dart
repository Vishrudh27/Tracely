import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';
import '../../../../data/repositories/habit_repository.dart';

/// Line chart showing daily completion % over the last N days.
///
/// Uses fl_chart with smooth bezier curves, minimal axes.
/// Toggle between 7d / 30d / 90d with animated chip selectors.
/// Line animates from left to right on entrance via [drawProgress].
class CompletionTrendChart extends ConsumerWidget {
  const CompletionTrendChart({
    super.key,
    required this.trendData,
    required this.opacity,
    required this.translateY,
    required this.drawProgress, // 0.0–1.0 drives line draw animation
  });

  final List<DailyCompletion> trendData;
  final double opacity;
  final double translateY;
  final double drawProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDays = ref.watch(trendDaysProvider);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completion Trend',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    // Period toggle chips
                    Row(
                      children: [7, 30, 90].map((days) {
                        final isSelected = selectedDays == days;
                        return GestureDetector(
                          onTap: () =>
                              ref.read(trendDaysProvider.notifier).select(days),
                          child: AnimatedContainer(
                            duration: AppDurations.fast,
                            margin: const EdgeInsets.only(left: AppSpacing.xs),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surfaceVariant,
                              borderRadius: AppRadius.chip,
                            ),
                            child: Text(
                              '${days}d',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: isSelected
                                    ? AppColors.textOnPrimary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: AppSizes.chartHeight,
                  child: trendData.isEmpty
                      ? Center(
                          child: Text(
                            'Complete some habits to see your trend.',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppColors.textDisabled,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _buildChart(context, selectedDays),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, int days) {
    // Clip trendData to drawProgress (left→right animation)
    final visibleCount =
        ((trendData.length * drawProgress).round()).clamp(2, trendData.length);

    // Need at least 2 spots to draw a line — guard for early animation frames
    if (trendData.length < 2) return const SizedBox.shrink();

    final visible = trendData.sublist(0, visibleCount);

    final spots = visible.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.percentage * 100);
    }).toList();

    final avgPct = trendData.isEmpty
        ? 0.0
        : trendData.map((d) => d.percentage).reduce((a, b) => a + b) /
            trendData.length;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 50,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}%',
                style: context.textTheme.labelSmall?.copyWith(
                  color: AppColors.textDisabled,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (trendData.length / 3).floorToDouble().clamp(1, 30),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trendData.length) {
                  return const SizedBox.shrink();
                }
                final date = trendData[idx].date;
                return Text(
                  '${date.day}/${date.month}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Average line
          if (avgPct > 0)
            LineChartBarData(
              spots: [
                FlSpot(0, avgPct * 100),
                FlSpot((trendData.length - 1).toDouble(), avgPct * 100),
              ],
              isCurved: false,
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              barWidth: 1,
              dashArray: [6, 4],
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${s.y.toStringAsFixed(0)}%',
                    context.textTheme.labelSmall!.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
