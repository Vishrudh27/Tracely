import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';

/// Frequency selector for habit scheduling.
///
/// Offers three options:
/// - Daily: every day
/// - Specific days: choose weekdays
/// - X per week: enter a number
class FrequencySelector extends StatelessWidget {
  const FrequencySelector({
    super.key,
    required this.frequencyType,
    required this.specificDays,
    required this.onFrequencyTypeChanged,
    required this.onSpecificDaysChanged,
  });

  final String frequencyType;
  final List<int> specificDays;
  final ValueChanged<String> onFrequencyTypeChanged;
  final ValueChanged<List<int>> onSpecificDaysChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Frequency type chips
        Row(
          children: [
            _FrequencyChip(
              label: AppStrings.frequencyDaily,
              isSelected: frequencyType == 'daily',
              onTap: () => onFrequencyTypeChanged('daily'),
            ),
            const SizedBox(width: AppSpacing.sm),
            _FrequencyChip(
              label: AppStrings.frequencySpecificDays,
              isSelected: frequencyType == 'specific_days',
              onTap: () => onFrequencyTypeChanged('specific_days'),
            ),
          ],
        ),

        // Specific days selector (visible only when specific_days is chosen)
        if (frequencyType == 'specific_days') ...[
          const SizedBox(height: AppSpacing.md),
          _DaySelector(
            selectedDays: specificDays,
            onChanged: onSpecificDaysChanged,
          ),
        ],
      ],
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  const _FrequencyChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: AppSpacing.chip,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: AppRadius.chip,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.selectedDays,
    required this.onChanged,
  });

  final List<int> selectedDays;
  final ValueChanged<List<int>> onChanged;

  // Mon=1..Sun=7
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayIndex = i + 1; // Mon=1
        final isSelected = selectedDays.contains(dayIndex);

        return GestureDetector(
          onTap: () {
            final updated = List<int>.from(selectedDays);
            if (isSelected) {
              updated.remove(dayIndex);
            } else {
              updated.add(dayIndex);
            }
            onChanged(updated);
          },
          child: AnimatedContainer(
            duration: AppDurations.fast,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.primary : AppColors.surface,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Center(
              child: Text(
                _days[i],
                style: context.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? AppColors.textOnPrimary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
