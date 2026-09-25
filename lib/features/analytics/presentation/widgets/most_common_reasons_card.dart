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
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What gets in the way', style: context.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),

                // Reason rows
                for (var i = 0; i < reasons.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  ReasonRow(reason: reasons[i], totalCount: totalCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ReasonRow — a single reason with icon, label, bar, and percentage
// ---------------------------------------------------------------------------

/// One reason: icon, label, share bar, percentage.
///
/// Shared by Statistics' "What gets in the way" and Habit Detail's
/// "Why it slipped" — same row, different scope of data.
class ReasonRow extends StatelessWidget {
  const ReasonRow({
    super.key,
    required this.reason,
    required this.totalCount,
  });

  final ReasonFrequency reason;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final percentage = totalCount > 0 ? reason.count / totalCount : 0.0;
    final display = reasonDisplayInfo(reason.reason);

    return Row(
        children: [
          Icon(display.icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 96,
            child: Text(
              display.label,
              style: context.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: percentage.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${(percentage * 100).round()}%',
              textAlign: TextAlign.right,
              style: context.textTheme.bodySmall,
            ),
          ),
        ],
      );
  }
}

// ---------------------------------------------------------------------------
// Reason key → display info mapping
// ---------------------------------------------------------------------------

/// Display metadata for a reason key — icon, human label, and bar color.
class ReasonDisplay {
  const ReasonDisplay({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
}

/// Maps a reason key from HabitReflections to its display information.
///
/// One row is stored per reason, so each key here is atomic and gets its own
/// label — collapsing them to their category made distinct reasons like
/// "Forgot" and "Couldn't focus" render as two identical rows. The icon and
/// colour still come from the reason's category. Keys written before the
/// one-row-per-reason change are the bare category names, kept below.
ReasonDisplay reasonDisplayInfo(String reasonKey) {
  return switch (reasonKey) {
    'low_energy' => _energy('Low energy'),
    'poor_sleep' => _energy('Poor sleep'),
    'felt_sick' => _energy('Felt sick'),
    'burned_out' => _energy('Burned out'),
    'energy' => _energy('Energy'),

    'too_busy' => _time('Too busy'),
    'unexpected_work' => _time('Unexpected work'),
    'meetings' => _time('Meetings'),
    'family' => _time('Family'),
    'time' => _time('Time'),

    'lost_motivation' => _mind('Lost motivation'),
    'procrastinated' => _mind('Procrastinated'),
    'forgot' => _mind('Forgot'),
    'felt_overwhelmed' => _mind('Overwhelmed'),
    'couldnt_focus' => _mind("Couldn't focus"),
    'mind' => _mind('Focus'),

    'traveling' => _environment('Traveling'),
    'weather' => _environment('Weather'),
    'no_equipment' => _environment('No equipment'),
    'outside_home' => _environment('Away from home'),
    'environment' => _environment('Environment'),

    'needed_rest' => _personal('Needed rest'),
    'mental_break' => _personal('Mental break'),
    'personal_event' => _personal('Personal event'),
    'emergency' => _personal('Emergency'),
    'personal' => _personal('Personal'),

    // Custom text and anything unrecognised.
    _ => const ReasonDisplay(
        icon: Icons.edit_outlined,
        label: 'Other',
        color: AppColors.categoryCustom,
      ),
  };
}

ReasonDisplay _energy(String label) => ReasonDisplay(
      icon: Icons.bedtime_outlined,
      label: label,
      color: AppColors.categoryHealth,
    );

ReasonDisplay _time(String label) => ReasonDisplay(
      icon: Icons.schedule_outlined,
      label: label,
      color: AppColors.categoryFitness,
    );

ReasonDisplay _mind(String label) => ReasonDisplay(
      icon: Icons.psychology_outlined,
      label: label,
      color: AppColors.categoryMind,
    );

ReasonDisplay _environment(String label) => ReasonDisplay(
      icon: Icons.public_outlined,
      label: label,
      color: AppColors.categorySocial,
    );

ReasonDisplay _personal(String label) => ReasonDisplay(
      icon: Icons.favorite_outline,
      label: label,
      color: AppColors.categoryCreativity,
    );
