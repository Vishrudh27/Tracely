import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/models/task_models.dart';

/// The Dashboard's "Today's Tasks" section — a flat, lighter-weight list
/// beneath Today's Habits, matching the Stitch dashboard's merged
/// habits+tasks layout (no card fill, hairline dividers between rows).
class TodaysTasksSection extends StatelessWidget {
  const TodaysTasksSection({
    super.key,
    required this.tasks,
    required this.onToggle,
    required this.allDone,
    required this.opacity,
    required this.translateY,
  });

  final List<TaskWithCategory> tasks;
  final void Function(int taskId, bool isDone) onToggle;

  /// Whether every habit today is complete — recolors checkmarks from
  /// coffee-brown to success green, matching `dashboard_all_done_state`.
  final bool allDone;
  final double opacity;
  final double translateY;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final doneCount = tasks.where((t) => t.isDone).length;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: AppStrings.sectionTodaysTasks,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              trailing: CountBadge(done: doneCount, total: tasks.length),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Column(
                children: [
                  for (final task in tasks)
                    _TaskRow(task: task, onToggle: onToggle, allDone: allDone),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.allDone,
  });

  final TaskWithCategory task;
  final void Function(int taskId, bool isDone) onToggle;
  final bool allDone;

  Color get _dotColor {
    if (task.isDone) return AppColors.textDisabled;
    return switch (task.priority) {
      TaskPriority.high => AppColors.priorityHigh,
      TaskPriority.normal => AppColors.priorityMedium,
      TaskPriority.low => AppColors.priorityLow,
    };
  }

  String get _metaLine {
    final time = task.dueTime;
    if (time == null) return 'Today';
    return 'Today, ${_formatTime(time)}';
  }

  static String _formatTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return hhmm;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final checkedColor = allDone ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onToggle(task.id, !task.isDone),
            child: AnimatedContainer(
              duration: AppDurations.fast,
              curve: AppCurves.standard,
              width: AppSizes.checkbox,
              height: AppSizes.checkbox,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                color: task.isDone ? checkedColor : Colors.transparent,
                border: task.isDone
                    ? null
                    : Border.all(color: AppColors.borderOutline, width: 2),
              ),
              child: task.isDone
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: AppColors.textOnPrimary,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontSize: 15,
                    color: task.isDone
                        ? AppColors.textDisabled
                        : AppColors.textPrimary,
                    decoration:
                        task.isDone ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(_metaLine, style: context.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: _dotColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
