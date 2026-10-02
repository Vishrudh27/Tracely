import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/habit_schedule.dart';

/// Optional time-of-day picker field — tap opens the system time picker,
/// the trailing ✕ clears it. Value is minutes since midnight.
///
/// Same look as Add Task's private `_SelectorField`.
class ReminderTimeField extends StatelessWidget {
  const ReminderTimeField({
    super.key,
    required this.minuteOfDay,
    required this.onChanged,
    this.emptyLabel = AppStrings.reminderAdd,
  });

  final int? minuteOfDay;
  final ValueChanged<int?> onChanged;
  final String emptyLabel;

  Future<void> _pick(BuildContext context) async {
    final current = minuteOfDay ?? 8 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked != null) onChanged(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final value = minuteOfDay;
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        height: AppSizes.inputHeight,
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.input,
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: AppSizes.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                value == null ? emptyLabel : clockLabel(value),
                style: context.textTheme.bodyLarge?.copyWith(
                  color: value == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null)
              IconButton(
                tooltip: 'Remove reminder',
                icon: Icon(
                  Icons.close_rounded,
                  size: AppSizes.iconMd,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => onChanged(null),
              )
            else
              const SizedBox(width: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
