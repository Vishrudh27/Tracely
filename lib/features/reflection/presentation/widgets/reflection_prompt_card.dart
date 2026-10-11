import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../providers/reflection_prompt_providers.dart';
import 'pause_and_reflect_sheet.dart';

/// Contextual prompt card displayed under the Dashboard greeting.
///
/// Driven by [reflectionPromptStateProvider]:
/// - [ReflectionPromptState.morningAfter]: Warm clay tint, prompts to reflect on yesterday's missed habits.
/// - [ReflectionPromptState.evening]: Surface variant fill, prompts to reflect on today's incomplete habits.
/// - [ReflectionPromptState.none]: Renders [SizedBox.shrink] with no reserved space.
///
/// Smoothly animates appearance/disappearance using [AnimatedSize] and [AnimatedSwitcher]
/// with [AppDurations.medium] and [AppCurves.easeOut].
class ReflectionPromptCard extends ConsumerWidget {
  const ReflectionPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promptStateAsync = ref.watch(reflectionPromptStateProvider);
    final promptState =
        promptStateAsync.asData?.value ?? ReflectionPromptState.none;
    final today = ref.watch(currentDateProvider);

    Widget content;
    if (promptState == ReflectionPromptState.none) {
      content = const SizedBox.shrink(key: ValueKey('none'));
    } else {
      final isMorningAfter = promptState == ReflectionPromptState.morningAfter;
      final targetDate = isMorningAfter ? today.addDays(-1) : today;
      final title = isMorningAfter
          ? 'Yesterday left a few things behind.'
          : 'Not everything got done today?';
      final subtitle =
          isMorningAfter ? 'Want to note why?' : 'Tell us why, anytime.';
      final fillColor =
          isMorningAfter ? AppColors.clayTint : AppColors.surfaceVariant;
      final borderColor = isMorningAfter
          ? AppColors.clay.withValues(alpha: 0.25)
          : AppColors.border;

      content = Padding(
        key: ValueKey(promptState),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          0,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.cardMinHeight),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: borderColor,
              width: AppSizes.divider,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: AppSizes.chipHeight,
                    child: ElevatedButton(
                      onPressed: () async {
                        final missedHabits = await ref
                            .read(habitRepositoryProvider)
                            .getMissedHabitsForDate(targetDate);
                        if (context.mounted) {
                          await PauseAndReflectSheet.show(
                            context: context,
                            targetDate: targetDate,
                            missedHabits: missedHabits,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnPrimary,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.chip,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                      ),
                      child: Text(
                        'Reflect',
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(reflectionPromptStateProvider.notifier)
                          .skip(targetDate);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: AppDurations.medium,
      curve: AppCurves.easeOut,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: AppDurations.medium,
        switchInCurve: AppCurves.easeOut,
        switchOutCurve: AppCurves.easeOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: content,
      ),
    );
  }
}
