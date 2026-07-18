import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// Per-habit breakdown list for the Statistics screen.
///
/// Each card shows: emoji, name, thin completion bar, streak indicator.
/// Tapping a card expands it to show a mini 4-week individual heatmap.
class HabitBreakdownList extends StatelessWidget {
  const HabitBreakdownList({
    super.key,
    required this.breakdowns,
    required this.opacity,
    required this.translateY,
    required this.controller,
    required this.intervalStart,
    required this.intervalEnd,
  });

  final List<HabitBreakdown> breakdowns;
  final double opacity;
  final double translateY;
  final AnimationController controller;
  final double intervalStart;
  final double intervalEnd;

  @override
  Widget build(BuildContext context) {
    if (breakdowns.isEmpty) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Your Habits',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...breakdowns.asMap().entries.map((entry) {
                final i = entry.key;
                final breakdown = entry.value;

                // Staggered animation per item
                final itemWindow = intervalEnd - intervalStart;
                final step = itemWindow / (breakdowns.length + 1);
                final start = (intervalStart + i * step * 0.6)
                    .clamp(0.0, 0.99);
                final end = (start + step * 1.5).clamp(start + 0.01, 1.0);

                final itemOpacity = CurvedAnimation(
                  parent: controller,
                  curve: Interval(start, end, curve: AppCurves.list),
                );
                final itemSlide = Tween<double>(begin: 20, end: 0).animate(
                  CurvedAnimation(
                    parent: controller,
                    curve: Interval(
                      start,
                      end,
                      curve: AppCurves.emphasizedDecelerate,
                    ),
                  ),
                );

                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) => Opacity(
                    opacity: itemOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, itemSlide.value),
                      child: child,
                    ),
                  ),
                  child: _HabitBreakdownCard(breakdown: breakdown),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable per-habit breakdown card.
class _HabitBreakdownCard extends StatefulWidget {
  const _HabitBreakdownCard({required this.breakdown});

  final HabitBreakdown breakdown;

  @override
  State<_HabitBreakdownCard> createState() => _HabitBreakdownCardState();
}

class _HabitBreakdownCardState extends State<_HabitBreakdownCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: AppDurations.medium,
    );
    _expandAnim = CurvedAnimation(
      parent: _expandController,
      curve: AppCurves.emphasizedDecelerate,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.breakdown.completionRate * 100).round();

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
            Row(
              children: [
                // Category dot
                Container(
                  width: AppSizes.categoryDot,
                  height: AppSizes.categoryDot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(widget.breakdown.categoryColorValue),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.breakdown.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.breakdown.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Streak badge
                if (widget.breakdown.currentStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.streakActive.withValues(alpha: 0.1),
                      borderRadius: AppRadius.chip,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.breakdown.currentStreak}',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: AppColors.streakActive,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: AppSpacing.xs),
                // Expand chevron
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: AppDurations.fast,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textDisabled,
                    size: AppSizes.iconMd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Completion bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.breakdown.completionRate.clamp(0.0, 1.0),
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(widget.breakdown.categoryColorValue),
                      ),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$pct%',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Expanded: mini stats
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  children: [
                    _StatChip(
                      label: 'Total',
                      value: '${widget.breakdown.totalCompletions}×',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(
                      label: 'Best streak',
                      value: '${widget.breakdown.longestStreak}d',
                      icon: Icons.emoji_events_outlined,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatChip(
                      label: '30-day rate',
                      value: '$pct%',
                      icon: Icons.trending_up_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.small,
        ),
        child: Column(
          children: [
            Icon(icon, size: AppSizes.iconSm, color: AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(
              value,
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: AppColors.textDisabled,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
