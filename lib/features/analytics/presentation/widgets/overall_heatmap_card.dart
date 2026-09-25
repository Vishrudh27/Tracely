import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';

/// 3-month GitHub-style heatmap card for the Statistics screen.
///
/// Cells are colored from AppColors.heatmap[0..4] based on completion %.
/// On entrance, cells fill in a wave pattern left→right, top→bottom.
///
/// Uses a custom TracelyHeatmap widget (GridView-based) for full style control.
class OverallHeatmapCard extends StatelessWidget {
  const OverallHeatmapCard({
    super.key,
    required this.heatmapData,
    required this.opacity,
    required this.translateY,
    required this.waveProgress, // 0.0–1.0 controls wave fill animation
  });

  final Map<DateTime, double> heatmapData;
  final double opacity;
  final double translateY;
  final double waveProgress;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TracelyHeatmap(
                  data: heatmapData,
                  waveProgress: waveProgress,
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: _HeatmapLegend(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legend showing the heatmap color scale.
class _HeatmapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Less',
          style: context.textTheme.labelSmall?.copyWith(
            color: AppColors.textDisabled,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        ...AppColors.heatmap.map(
          (c) => Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          'More',
          style: context.textTheme.labelSmall?.copyWith(
            color: AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}

/// Custom heatmap widget — 3 months of cells in a scrollable row-based grid.
class _TracelyHeatmap extends StatelessWidget {
  const _TracelyHeatmap({
    required this.data,
    required this.waveProgress,
  });

  final Map<DateTime, double> data;
  final double waveProgress;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Complete your first habit to see your heatmap.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ),
      );
    }

    // Build the week columns: each column = 7 days (Mon–Sun)
    final today = DateTime.now();
    final endDate = DateTime(today.year, today.month, today.day);
    final startDate = DateTime(today.year, today.month - 3, today.day);

    // Calculate all days in range
    final allDays = <DateTime>[];
    var d = startDate;
    // Align to the Monday of the start week
    final adjustedStart = d.subtract(Duration(days: d.weekday - 1));
    d = adjustedStart;
    while (!d.isAfter(endDate)) {
      allDays.add(d);
      d = d.add(const Duration(days: 1));
    }

    // Group into weeks (columns of 7)
    final weeks = <List<DateTime>>[];
    for (int i = 0; i < allDays.length; i += 7) {
      final end = (i + 7).clamp(0, allDays.length);
      weeks.add(allDays.sublist(i, end));
    }

    final totalCells = allDays.length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day labels column
          Column(
            children: ['M', '', 'W', '', 'F', '', 'S'].map((label) {
              return SizedBox(
                height: AppSizes.heatmapCell + AppSizes.heatmapSpacing,
                child: Center(
                  child: Text(
                    label,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: AppColors.textDisabled,
                      fontSize: 9,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: AppSpacing.xxs),

          // Week columns
          ...weeks.asMap().entries.map((weekEntry) {
            final weekIndex = weekEntry.key;
            final week = weekEntry.value;

            return Padding(
              padding: const EdgeInsets.only(right: AppSizes.heatmapSpacing),
              child: Column(
                children: List.generate(7, (dayIndex) {
                  if (dayIndex >= week.length) {
                    return SizedBox(
                      width: AppSizes.heatmapCell,
                      height: AppSizes.heatmapCell +
                          AppSizes.heatmapSpacing,
                    );
                  }
                  final day = week[dayIndex];
                  final cellIndex = weekIndex * 7 + dayIndex;
                  final cellProgress =
                      totalCells == 0 ? 1.0 : cellIndex / totalCells;
                  final isVisible = waveProgress >= cellProgress;

                  final pct =
                      data[DateTime(day.year, day.month, day.day)] ?? -1;
                  final isFuture = day.isAfter(endDate);
                  final isBeforeStart = day.isBefore(startDate);

                  int level;
                  if (isFuture || isBeforeStart || pct < 0) {
                    level = -1; // invisible / no habit data
                  } else if (pct == 0) {
                    level = 0;
                  } else if (pct < 0.25) {
                    level = 1;
                  } else if (pct < 0.50) {
                    level = 2;
                  } else if (pct < 0.75) {
                    level = 3;
                  } else {
                    level = 4;
                  }

                  final isToday = day.year == today.year &&
                      day.month == today.month &&
                      day.day == today.day;

                  return AnimatedOpacity(
                    opacity: isVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 80),
                    child: Container(
                      width: AppSizes.heatmapCell,
                      height: AppSizes.heatmapCell,
                      margin: const EdgeInsets.only(
                        bottom: AppSizes.heatmapSpacing,
                      ),
                      decoration: BoxDecoration(
                        color: level < 0
                            ? Colors.transparent
                            : AppColors.heatmap[level],
                        borderRadius: BorderRadius.circular(3),
                        border: isToday
                            ? Border.all(
                                color: AppColors.primary,
                                width: 1.5,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}
