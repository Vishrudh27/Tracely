
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// A single habit tile shown in the "Today's Habits" section.
///
/// Shows the habit emoji, name, category dot, and a completion checkbox.
/// The checkbox has a rich multi-phase micro-animation per §5.4:
///   Phase 1: Scale bounce (spring overshoot)
///   Phase 2: Fill morph (empty → filled with checkmark)
///   Phase 3: Ripple glow (radial expand + fade)
///   Phase 4: Text crossfade (subtle color + strikethrough)
///   Bonus:   Tile-level press feedback (scale 1.0→0.98→1.0)
class HabitTile extends StatefulWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.onToggle,
  });

  final HabitWithCompletion habit;
  final VoidCallback onToggle;

  @override
  State<HabitTile> createState() => _HabitTileState();
}

class _HabitTileState extends State<HabitTile>
    with TickerProviderStateMixin {
  // Checkbox micro-interaction controller
  late final AnimationController _checkController;
  // Tile press feedback controller (subtle scale)
  late final AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: AppDurations.habitComplete,
    );
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    // Sync initial state — if already completed, start at end
    if (widget.habit.isCompletedToday) {
      _checkController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(HabitTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.habit.isCompletedToday != oldWidget.habit.isCompletedToday) {
      if (widget.habit.isCompletedToday) {
        _checkController.forward();
      } else {
        _checkController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    // Brief tile-press feedback
    _pressController.forward().then((_) => _pressController.reverse());
    if (widget.habit.isCompletedToday) {
      _checkController.reverse();
    } else {
      _checkController.forward();
    }
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    // ── Checkbox animations ──────────────────────────────────────────────────

    // Phase 1: Spring scale bounce on the checkbox (1.0→0.82→1.12→1.0)
    final checkScaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.82)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.82, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: AppCurves.habitCompletion)),
        weight: 30,
      ),
    ]).animate(_checkController);

    // Phase 2: Fill color morph (border→success)
    final fillColorAnim = ColorTween(
      begin: AppColors.border,
      end: AppColors.success,
    ).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.10, 0.75, curve: Curves.easeOut),
      ),
    );

    // Phase 3: Glow ring expansion
    final glowOpacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.15, 0.70, curve: Curves.easeOut),
      ),
    );

    final glowScaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // Phase 4: Text color shift + strikethrough fade-in
    final textColorAnim = ColorTween(
      begin: AppColors.textPrimary,
      end: AppColors.textSecondary,
    ).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.10, 0.85, curve: Curves.easeOut),
      ),
    );

    // Checkmark icon opacity (appears as fill completes)
    final checkmarkOpacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.45, 0.80, curve: Curves.easeOut),
      ),
    );

    // Tile border color morphs subtly on completion
    final borderColorAnim = ColorTween(
      begin: AppColors.border,
      end: AppColors.completedBorder,
    ).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOut),
      ),
    );

    // Tile background color morphs on completion
    final bgColorAnim = ColorTween(
      begin: AppColors.uncompletedBackground,
      end: AppColors.completedBackground,
    ).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.15, 0.85, curve: Curves.easeOut),
      ),
    );

    // Tile-level press scale
    final tileScaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_checkController, _pressController]),
      builder: (context, _) {
        final isCompleted = widget.habit.isCompletedToday;

        return Transform.scale(
          scale: tileScaleAnim.value,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: bgColorAnim.value,
              borderRadius: AppRadius.card,
              border: Border.all(
                color: borderColorAnim.value ?? AppColors.border,
                width: isCompleted ? 1.2 : 1.0,
              ),
              boxShadow: isCompleted ? AppShadows.sm : AppShadows.sm,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.card,
                onTap: _handleTap,
                splashColor: AppColors.primary.withValues(alpha: 0.05),
                highlightColor: AppColors.primary.withValues(alpha: 0.02),
                child: Padding(
                  padding: AppSpacing.habitTile,
                  child: Row(
                    children: [
                      // Category dot
                      _CategoryDot(colorValue: widget.habit.categoryColorValue),
                      const SizedBox(width: AppSpacing.md),

                      // Habit emoji
                      Text(
                        widget.habit.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Habit name with animated text
                      Expanded(
                        child: Text(
                          widget.habit.name,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: textColorAnim.value,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor:
                                AppColors.textDisabled.withValues(alpha: 0.5),
                            decorationThickness: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: AppSpacing.md),

                      // Completion checkbox with glow
                      _AnimatedCheckbox(
                        checkScale: checkScaleAnim.value,
                        fillColor: fillColorAnim.value ?? AppColors.border,
                        glowOpacity: glowOpacityAnim.value,
                        glowScale: glowScaleAnim.value,
                        checkmarkOpacity: checkmarkOpacityAnim.value,
                        isCompleted: isCompleted,
                        categoryColor: Color(widget.habit.categoryColorValue),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The animated circular checkbox with glow ring and checkmark.
class _AnimatedCheckbox extends StatelessWidget {
  const _AnimatedCheckbox({
    required this.checkScale,
    required this.fillColor,
    required this.glowOpacity,
    required this.glowScale,
    required this.checkmarkOpacity,
    required this.isCompleted,
    required this.categoryColor,
  });

  final double checkScale;
  final Color fillColor;
  final double glowOpacity;
  final double glowScale;
  final double checkmarkOpacity;
  final bool isCompleted;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.completionCheckboxRipple,
      height: AppSizes.completionCheckboxRipple,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring — expands and fades
          Transform.scale(
            scale: glowScale,
            child: Container(
              width: AppSizes.completionCheckboxRipple,
              height: AppSizes.completionCheckboxRipple,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(
                  alpha: 0.18 * glowOpacity,
                ),
              ),
            ),
          ),
          // Mid glow (tighter, brighter)
          Transform.scale(
            scale: (glowScale * 0.75).clamp(0.0, 1.0),
            child: Container(
              width: AppSizes.completionCheckboxRipple * 0.75,
              height: AppSizes.completionCheckboxRipple * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(
                  alpha: 0.10 * glowOpacity,
                ),
              ),
            ),
          ),
          // The checkbox circle
          Transform.scale(
            scale: checkScale,
            child: Container(
              width: AppSizes.completionCheckbox,
              height: AppSizes.completionCheckbox,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? fillColor : Colors.transparent,
                border: Border.all(
                  color: fillColor,
                  width: 2.0,
                ),
                boxShadow: isCompleted
                    ? [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: isCompleted
                  ? Opacity(
                      opacity: checkmarkOpacity,
                      child: Transform.rotate(
                        angle: (1 - checkmarkOpacity) * -0.5,
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: AppSizes.iconSm,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}



/// Small colored dot indicating the habit's category.
class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.colorValue});

  final int colorValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.categoryDot,
      height: AppSizes.categoryDot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(colorValue),
      ),
    );
  }
}
