import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// Recent activity section showing the last 3 completions.
///
/// Warm, minimal cards. Never shows "no activity" with negative framing.
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({
    super.key,
    required this.completions,
    required this.opacity,
    required this.translateY,
  });

  final List<CompletionWithHabit> completions;
  final double opacity;
  final double translateY;

  @override
  Widget build(BuildContext context) {
    if (completions.isEmpty) return const SizedBox.shrink();

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
                Text(
                  AppStrings.sectionRecentActivity,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...completions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  return Column(
                    children: [
                      _ActivityItem(completion: c),
                      if (i < completions.length - 1)
                        Divider(
                          height: AppSpacing.lg,
                          thickness: AppSizes.divider,
                          color: AppColors.divider,
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.completion});

  final CompletionWithHabit completion;

  String get _timeLabel {
    final now = DateTime.now();
    final completedAt = completion.completedAt;
    final diffMins = now.difference(completedAt).inMinutes;

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return '$diffMins min ago';

    final diffHours = now.difference(completedAt).inHours;
    if (diffHours < 24) return '$diffHours hr ago';

    final diffDays = now.difference(completedAt).inDays;
    if (diffDays == 1) return AppStrings.yesterdayLabel;
    return '$diffDays${AppStrings.daysAgoLabel}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(completion.habitEmoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            completion.habitName,
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          _timeLabel,
          style: context.textTheme.labelSmall?.copyWith(
            color: AppColors.textDisabled,
          ),
        ),
      ],
    );
  }
}
