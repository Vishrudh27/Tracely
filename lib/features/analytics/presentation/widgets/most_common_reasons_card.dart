import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/database/daos/reflection_dao.dart';

/// Ranked breakdown of why habits were missed over the last 30 days.
///
/// Displays data from `HabitReflections` via [ReflectionDao.watchMostCommonReasons].
/// Hidden when fewer than 3 reflection entries exist — not enough data to
/// be meaningful, and a near-empty stat is worse than no stat (§4.3).
///
/// Animation parameters are received from the parent
/// [StatisticsScreen]'s single AnimationController (Interval 0.40–0.57).
class MostCommonReasonsCard extends StatelessWidget {
  const MostCommonReasonsCard({
    super.key,
    required this.reasons,
    required this.opacity,
    required this.translateY,
  });

  final List<ReasonFrequency> reasons;
  final double opacity;
  final double translateY;

  @override
  Widget build(BuildContext context) {
    // Guard: hide card when fewer than 3 entries exist (§4.3)
    if (reasons.length < 3) return const SizedBox.shrink();

    final totalCount = reasons.fold<int>(0, (sum, r) => sum + r.count);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Container(
            width: double.infinity,
            padding: AppSpacing.statisticsCard,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text('🪞', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'What Gets in the Way',
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Patterns from your reflections',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Reason rows
                ...reasons.map(
                  (reason) => _ReasonRow(
                    reason: reason,
                    totalCount: totalCount,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ReasonRow — a single reason with emoji, label, bar, and percentage
// ---------------------------------------------------------------------------

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.totalCount,
  });

  final ReasonFrequency reason;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final percentage = totalCount > 0 ? reason.count / totalCount : 0.0;
    final display = _reasonDisplayInfo(reason.reason);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          // Emoji
          SizedBox(
            width: AppSpacing.xxl,
            child: Text(
              display.emoji,
              style: const TextStyle(fontSize: 16),
            ),
          ),

          // Label + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display.label,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: percentage.clamp(0.0, 1.0),
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      display.color,
                    ),
                    minHeight: AppSpacing.xs,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // Percentage
          SizedBox(
            width: 40,
            child: Text(
              '${(percentage * 100).round()}%',
              textAlign: TextAlign.right,
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reason key → display info mapping
// ---------------------------------------------------------------------------

/// Display metadata for a reason key — emoji, human label, and bar color.
class _ReasonDisplay {
  const _ReasonDisplay({
    required this.emoji,
    required this.label,
    required this.color,
  });
  final String emoji;
  final String label;
  final Color color;
}

/// Maps a reason key from HabitReflections to its display information.
///
/// One row is stored per reason, so each key here is atomic. Rows written
/// before that change hold comma-joined keys and fall through to "Other".
_ReasonDisplay _reasonDisplayInfo(String reasonKey) {
  return switch (reasonKey) {
    // Energy category
    'low_energy' ||
    'poor_sleep' ||
    'felt_sick' ||
    'burned_out' ||
    'energy' =>
      const _ReasonDisplay(
        emoji: '🌱',
        label: 'Energy',
        color: AppColors.categoryHealth,
      ),

    // Time category
    'too_busy' ||
    'unexpected_work' ||
    'meetings' ||
    'family' ||
    'time' =>
      const _ReasonDisplay(
        emoji: '⏰',
        label: 'Time',
        color: AppColors.categoryFitness,
      ),

    // Mind category
    'lost_motivation' ||
    'procrastinated' ||
    'forgot' ||
    'felt_overwhelmed' ||
    'couldnt_focus' ||
    'mind' =>
      const _ReasonDisplay(
        emoji: '🧠',
        label: 'Focus',
        color: AppColors.categoryMind,
      ),

    // Environment category
    'traveling' ||
    'weather' ||
    'no_equipment' ||
    'outside_home' ||
    'environment' =>
      const _ReasonDisplay(
        emoji: '🌍',
        label: 'Environment',
        color: AppColors.categorySocial,
      ),

    // Personal category
    'needed_rest' ||
    'mental_break' ||
    'personal_event' ||
    'emergency' ||
    'personal' =>
      const _ReasonDisplay(
        emoji: '❤️',
        label: 'Personal',
        color: AppColors.categoryCreativity,
      ),

    // Custom / other
    _ => const _ReasonDisplay(
        emoji: '✍️',
        label: 'Other',
        color: AppColors.categoryCustom,
      ),
  };
}
