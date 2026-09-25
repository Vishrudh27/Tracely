
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/models/habit_models.dart';

/// A single habit tile shown in the "Today's Habits" section.
///
/// Shows the habit icon, name, category dot, and a completion checkbox.
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
    this.allDone = false,
  });

  final HabitWithCompletion habit;
  final VoidCallback onToggle;

  /// Whether every habit today is complete — recolors the checkmark from
  /// coffee-brown to success green, matching `dashboard_all_done_state`.
  final bool allDone;

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

    // Phase 2: Fill color morph (outline→primary, or success once every
    // habit today is complete)
    final checkedColor = widget.allDone ? AppColors.success : AppColors.primary;
    final fillColorAnim = ColorTween(
      begin: AppColors.borderOutline,
      end: checkedColor,
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

    // Phase 4: Text color fade to disabled once completed
    final textColorAnim = ColorTween(
      begin: AppColors.textPrimary,
      end: AppColors.textDisabled,
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
              vertical: AppSpacing.xs,
            ),
            constraints: const BoxConstraints(minHeight: AppSizes.cardMinHeight),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.sm,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleTap,
                    splashColor: AppColors.primary.withValues(alpha: 0.05),
                    highlightColor: AppColors.primary.withValues(alpha: 0.02),
                    child: Padding(
                      padding: AppSpacing.habitTile,
                      child: Row(
                        children: [
                          // Completion checkbox with glow
                          _AnimatedCheckbox(
                            checkScale: checkScaleAnim.value,
                            fillColor: fillColorAnim.value ?? AppColors.border,
                            glowOpacity: glowOpacityAnim.value,
                            glowScale: glowScaleAnim.value,
                            checkmarkOpacity: checkmarkOpacityAnim.value,
                            isCompleted: isCompleted,
                            glowColor: checkedColor,
                          ),
                          const SizedBox(width: 14),

                          // Habit icon
                          Icon(
                            AppIconRegistry.resolve(widget.habit.emoji),
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 14),

                          // Name + category, stacked
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.habit.name,
                                  style: context.textTheme.titleMedium
                                      ?.copyWith(color: textColorAnim.value),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.habit.categoryName,
                                  style: context.textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Category accent bar, pinned to the right edge
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(widget.habit.categoryColorValue),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
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
    required this.glowColor,
  });

  final double checkScale;
  final Color fillColor;
  final double glowOpacity;
  final double glowScale;
  final double checkmarkOpacity;
  final bool isCompleted;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSizes.completionCheckbox,
      height: AppSizes.completionCheckbox,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Outer glow ring — expands and fades
          Transform.scale(
            scale: glowScale,
            child: Container(
              width: AppSizes.completionCheckboxRipple,
              height: AppSizes.completionCheckboxRipple,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withValues(alpha: 0.18 * glowOpacity),
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
                color: glowColor.withValues(alpha: 0.10 * glowOpacity),
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
                          color: glowColor.withValues(alpha: 0.25),
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
