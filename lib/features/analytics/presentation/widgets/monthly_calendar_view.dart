import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Monthly calendar view for the Statistics screen.
///
/// Clean calendar with completion dots beneath date numbers.
/// Color intensity based on that day's completion percentage.
/// Swipe left/right to navigate months.
/// Today is circled with AppColors.primary ring.
class MonthlyCalendarView extends StatefulWidget {
  const MonthlyCalendarView({
    super.key,
    required this.heatmapData,
    required this.opacity,
    required this.scale,
  });

  final Map<DateTime, double> heatmapData;
  final double opacity;
  final double scale;

  @override
  State<MonthlyCalendarView> createState() => _MonthlyCalendarViewState();
}

class _MonthlyCalendarViewState extends State<MonthlyCalendarView> {
  late DateTime _displayMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
    // Don't navigate to future months
    if (!nextMonth.isAfter(DateTime(now.year, now.month, 1))) {
      setState(() => _displayMonth = nextMonth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _displayMonth.year == now.year &&
        _displayMonth.month == now.month;

    return Opacity(
      opacity: widget.opacity,
      child: Transform.scale(
        scale: widget.scale,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! < -200) _nextMonth();
              if (details.primaryVelocity! > 200) _prevMonth();
            },
            child: Container(
              padding: AppSpacing.card,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.card,
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.sm,
              ),
              child: Column(
                children: [
                  // Month nav header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _prevMonth,
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.textSecondary,
                        ),
                        iconSize: AppSizes.iconLg,
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        _monthLabel(_displayMonth),
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: isCurrentMonth ? null : _nextMonth,
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: isCurrentMonth
                              ? AppColors.disabled
                              : AppColors.textSecondary,
                        ),
                        iconSize: AppSizes.iconLg,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Day-of-week labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                        .map(
                          (d) => SizedBox(
                            width: 36,
                            child: Center(
                              child: Text(
                                d,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: AppColors.textDisabled,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Calendar grid
                  AnimatedSwitcher(
                    duration: AppDurations.fast,
                    child: _buildCalendarGrid(context, now),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, DateTime now) {
    final firstDay = _displayMonth;
    final daysInMonth = DateTime(firstDay.year, firstDay.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7; // Mon=0, Sun=6

    return Column(
      key: ValueKey(_displayMonth),
      children: _buildWeeks(context, now, daysInMonth, startOffset),
    );
  }

  List<Widget> _buildWeeks(
    BuildContext context,
    DateTime now,
    int daysInMonth,
    int startOffset,
  ) {
    final rows = <Widget>[];
    final cells = startOffset + daysInMonth;
    final totalRows = (cells / 7).ceil();

    for (int row = 0; row < totalRows; row++) {
      final dayWidgets = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;
        final dayNum = cellIndex - startOffset + 1;

        if (dayNum < 1 || dayNum > daysInMonth) {
          dayWidgets.add(const SizedBox(width: 36, height: 44));
          continue;
        }

        final date = DateTime(
          _displayMonth.year,
          _displayMonth.month,
          dayNum,
        );
        final isToday = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
        final isFuture = date.isAfter(now);
        final pct = widget.heatmapData[date];

        dayWidgets.add(
          _CalendarCell(
            dayNum: dayNum,
            isToday: isToday,
            isFuture: isFuture,
            completionPct: pct,
          ),
        );
      }
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: dayWidgets,
        ),
      );
      if (row < totalRows - 1) {
        rows.add(const SizedBox(height: AppSpacing.xxs));
      }
    }
    return rows;
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.dayNum,
    required this.isToday,
    required this.isFuture,
    this.completionPct,
  });

  final int dayNum;
  final bool isToday;
  final bool isFuture;
  final double? completionPct;

  Color _dotColor() {
    if (completionPct == null || completionPct == 0) return Colors.transparent;
    if (completionPct! < 0.25) return AppColors.heatmap[1];
    if (completionPct! < 0.50) return AppColors.heatmap[2];
    if (completionPct! < 0.75) return AppColors.heatmap[3];
    return AppColors.heatmap[4];
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor();
    final hasDot = dotColor != Colors.transparent;

    return SizedBox(
      width: 36,
      height: 44,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  )
                : null,
            child: Center(
              child: Text(
                '$dayNum',
                style: context.textTheme.bodySmall?.copyWith(
                  color: isToday
                      ? AppColors.primary
                      : isFuture
                          ? AppColors.textDisabled
                          : AppColors.textPrimary,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Completion dot
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasDot ? dotColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
