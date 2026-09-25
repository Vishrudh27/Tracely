import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../data/models/task_models.dart';

/// A single task row — deliberately flatter than [HabitTile]: no card fill,
/// just a hairline divider below, matching the "tasks are lighter-weight
/// than habits" rule from the Tasks screen spec.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    this.showOverdueLabel = false,
    this.showDate = false,
  });

  final TaskWithCategory task;
  final ValueChanged<bool> onToggle;

  /// When true, the due-time line renders in the error tone instead of
  /// textSecondary — used for rows under the OVERDUE group.
  final bool showOverdueLabel;

  /// When true, prefixes the meta line with a relative day label
  /// ("Yesterday", "Tomorrow", "Oct 14") instead of bare time — used
  /// wherever the row isn't already grouped under a same-day section
  /// header (the OVERDUE group, and the flat Upcoming/Overdue tabs).
  final bool showDate;

  Color get _priorityColor => switch (task.priority) {
        TaskPriority.high => AppColors.priorityHigh,
        TaskPriority.normal => AppColors.priorityMedium,
        TaskPriority.low => AppColors.priorityLow,
      };

  String? get _metaLine {
    String? whenPart = task.dueTime != null ? _formatTime(task.dueTime!) : null;
    if (showDate && task.dueDate != null) {
      final dateLabel = _dateLabel(task.dueDate!);
      whenPart = whenPart != null ? '$dateLabel, $whenPart' : dateLabel;
    }
    final parts = <String>[
      ?whenPart,
      if (task.categoryName != null) task.categoryName!,
    ];
    return parts.isEmpty ? null : parts.join(' • ');
  }

  static String _dateLabel(DateTime date) {
    if (date.isYesterday) return 'Yesterday';
    if (date.isSameDay(DateTime.now().addDays(1))) return 'Tomorrow';
    return DateFormat('MMM d').format(date);
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
    final meta = _metaLine;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Checkbox(checked: task.isDone, onChanged: onToggle),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.title,
                style: AppTypography.textTheme.bodyLarge?.copyWith(
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
              if (meta != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  meta,
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: showOverdueLabel && !task.isDone
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _priorityColor, shape: BoxShape.circle),
        ),
      ],
    );

    return Opacity(
      opacity: task.isDone ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: content,
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        width: AppSizes.checkbox,
        height: AppSizes.checkbox,
        decoration: BoxDecoration(
          color: checked ? AppColors.success : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: checked
              ? null
              : Border.all(color: AppColors.borderOutline, width: 2),
        ),
        child: checked
            ? const Icon(Icons.check, size: 16, color: AppColors.textOnPrimary)
            : null,
      ),
    );
  }
}
