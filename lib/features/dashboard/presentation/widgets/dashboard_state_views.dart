import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/greeting_utils.dart';
import '../../../../core/widgets/tracely_shimmer.dart';
import '../../../../data/models/task_models.dart';
import 'todays_tasks_section.dart';

/// The Dashboard's three non-loaded states, traced from Stitch's
/// `dashboard_empty_state`, `dashboard_error_state` and
/// `dashboard_loading_skeleton` mocks.
///
/// These are dashboard-specific on purpose: the shared [TracelyEmptyState] is
/// a bare centred block, but Stitch gives the dashboard its own greeting-topped
/// empty page, a card-framed error, and a full-shape skeleton. Kept out of the
/// screen file only so that file stays about the loaded state.

// ---------------------------------------------------------------------------
// Empty — no habits yet
// ---------------------------------------------------------------------------

class DashboardEmptyView extends StatelessWidget {
  const DashboardEmptyView({
    super.key,
    required this.onAddHabit,
    this.onSettingsTap,
  });

  final VoidCallback onAddHabit;

  /// Not in Stitch's mock — see [DashboardGreetingSection.onSettingsTap].
  /// A first-run account has no habits to open Edit Habit from either, so
  /// this empty page is actually the one place Settings must stay reachable.
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Greeting stays even with nothing to show, so a first-run
              // screen still feels like the app rather than a placeholder.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      GreetingUtils.greeting(),
                      style: context.textTheme.displaySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.emptyDashboardSubtitle,
                      style: context.textTheme.titleSmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (onSettingsTap != null)
                IconButton(
                  onPressed: onSettingsTap,
                  icon: const Icon(Icons.settings_outlined),
                  iconSize: AppSizes.iconLg,
                  color: AppColors.textSecondary,
                  tooltip: 'Settings',
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.huge),
          const Center(child: _DashedRing()),
          const SizedBox(height: AppSpacing.xxl),

          Text(
            AppStrings.emptyDashboardTitle,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                AppStrings.emptyDashboardBody,
                textAlign: TextAlign.center,
                style: context.textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: SizedBox(
              width: 200,
              height: AppSizes.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: onAddHabit,
                icon: const Icon(Icons.add_rounded, size: AppSizes.iconMd),
                label: Text(AppStrings.emptyDashboardCta),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                  textStyle: context.textTheme.titleMedium
                      ?.copyWith(color: AppColors.textOnPrimary),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.huge - AppSpacing.xs),
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.fab,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '“${AppStrings.motivationFooter.first}”',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          const _QuietRitualTip(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// The slowly rotating dashed placeholder ring with a small centre dot.
class _DashedRing extends StatefulWidget {
  const _DashedRing();

  @override
  State<_DashedRing> createState() => _DashedRingState();
}

class _DashedRingState extends State<_DashedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Stitch spins it once every 40s — a barely-there drift, not a spinner.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _controller,
            child: const CustomPaint(
              size: Size(64, 64),
              painter: _DashedRingPainter(),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final circle = Path()
      ..addOval(Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.width / 2 - 2,
      ));

    // 5-on / 5-gap dashes, matching stroke-dasharray="5 5".
    for (final metric in circle.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 5).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) => false;
}

class _QuietRitualTip extends StatelessWidget {
  const _QuietRitualTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.button,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.avatarMd,
            height: AppSizes.avatarMd,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.small,
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 22,
              color: AppColors.accentTerracotta,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.emptyDashboardTipTitle,
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  AppStrings.emptyDashboardTipBody,
                  style: context.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rest day — habits exist, just none scheduled today
// ---------------------------------------------------------------------------

/// Not in Stitch — added because [DashboardEmptyView]'s "Add First Habit"
/// first-run copy was also firing for an account that has habits, just none
/// due today (e.g. a Mon–Fri habit on a Saturday), and it hid Today's Tasks
/// along with it. This is deliberately quieter: no CTA, no dashed ring, and
/// tasks (which aren't schedule-gated) still show.
class DashboardRestDayView extends StatelessWidget {
  const DashboardRestDayView({
    super.key,
    required this.tasks,
    required this.onToggleTask,
    this.onSettingsTap,
  });

  final List<TaskWithCategory> tasks;
  final void Function(int taskId, bool isDone) onToggleTask;

  /// Not in Stitch's mock — see [DashboardGreetingSection.onSettingsTap].
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    // TodaysTasksSection pads its own horizontal xl, so it sits outside the
    // padded block below rather than nested in it — otherwise it would get
    // xl twice.
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            GreetingUtils.greeting(),
                            style: context.textTheme.displaySmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppStrings.restDayGreetingSubtitle,
                            style: context.textTheme.titleSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (onSettingsTap != null)
                      IconButton(
                        onPressed: onSettingsTap,
                        icon: const Icon(Icons.settings_outlined),
                        iconSize: AppSizes.iconLg,
                        color: AppColors.textSecondary,
                        tooltip: 'Settings',
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.huge),
                Center(
                  child: Container(
                    width: AppSizes.avatarXl,
                    height: AppSizes.avatarXl,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.self_improvement_rounded,
                      size: AppSizes.iconXl,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                Text(
                  AppStrings.restDayTitle,
                  textAlign: TextAlign.center,
                  style: context.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      AppStrings.restDayBody,
                      textAlign: TextAlign.center,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),

          if (tasks.isNotEmpty)
            TodaysTasksSection(
              tasks: tasks,
              onToggle: onToggleTask,
              allDone: false,
              opacity: 1.0,
              translateY: 0.0,
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error — the habits stream threw
// ---------------------------------------------------------------------------

class DashboardErrorView extends StatelessWidget {
  const DashboardErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 64,
                height: 64,
                child: CustomPaint(painter: _BrokenCloudPainter()),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.errorDashboardTitle,
                textAlign: TextAlign.center,
                style: context.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  AppStrings.errorDashboardBody,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                height: AppSizes.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(AppStrings.errorDashboardCta),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                    textStyle: context.textTheme.titleMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A broken outline cloud with a small pebble beneath it — the SVG from
/// `dashboard_error_state`, in its native 64×64 box.
class _BrokenCloudPainter extends CustomPainter {
  const _BrokenCloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);

    final stroke = Paint()
      ..color = AppColors.borderOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final top = Path()
      ..moveTo(19, 46)
      ..lineTo(45, 46)
      ..cubicTo(51.6274, 46, 57, 40.6274, 57, 34)
      ..cubicTo(57, 27.671, 52.0934, 22.4883, 45.8824, 22.0368)
      ..cubicTo(44.4754, 14.0768, 37.5255, 8, 29.1429, 8)
      ..cubicTo(23.6934, 8, 18.9197, 10.5847, 15.8, 14.59);
    canvas.drawPath(top, stroke);

    final left = Path()
      ..moveTo(12.2, 19.3)
      ..cubicTo(8.6, 21.6, 7, 25.8, 7, 30.5)
      ..cubicTo(7, 38.5, 12.5, 45.5, 20.5, 46);
    canvas.drawPath(left, stroke);

    canvas.drawCircle(
      const Offset(32, 53),
      1.5,
      Paint()..color = AppColors.borderOutline,
    );
  }

  @override
  bool shouldRepaint(_BrokenCloudPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Loading — full-shape skeleton
// ---------------------------------------------------------------------------

class DashboardLoadingView extends StatelessWidget {
  const DashboardLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const TracelyShimmerLine(width: 190, height: 28),
          const SizedBox(height: AppSpacing.sm),
          const TracelyShimmerLine(width: 130, height: 16),

          const SizedBox(height: AppSpacing.xxl),
          _progressCardSkeleton(),

          const SizedBox(height: AppSpacing.xxl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              TracelyShimmerLine(width: 130, height: 18),
              TracelyShimmerLine(width: 50, height: 14),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final w in const [140.0, 125.0, 150.0, 135.0]) ...[
            _habitTileSkeleton(w),
            const SizedBox(height: AppSpacing.sm + 2),
          ],

          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              TracelyShimmerLine(width: 115, height: 18),
              TracelyShimmerLine(width: 40, height: 14),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final w in const [170.0, 150.0, 190.0]) _taskRowSkeleton(w),
        ],
      ),
    );
  }

  Widget _progressCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          // The ring: a filled recessed disc with a card-coloured hole, so it
          // reads as a stroke without animating one.
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  TracelyShimmerLine(width: 36, height: 20),
                  SizedBox(height: AppSpacing.xs),
                  TracelyShimmerLine(width: 48, height: 10),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                TracelyShimmerLine(width: 110, height: 22),
                SizedBox(height: AppSpacing.sm),
                TracelyShimmerLine(width: 80, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitTileSkeleton(double titleWidth) {
    return Container(
      height: AppSizes.cardMinHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          _dot(28, shape: BoxShape.circle),
          const SizedBox(width: AppSpacing.md),
          _dot(20, radius: AppRadius.small),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TracelyShimmerLine(width: titleWidth, height: 15),
                const SizedBox(height: AppSpacing.xs + 2),
                TracelyShimmerLine(width: titleWidth * 0.6, height: 12),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          TracelyShimmer(
            width: 3,
            height: 32,
            borderRadius: AppRadius.fab,
          ),
        ],
      ),
    );
  }

  Widget _taskRowSkeleton(double titleWidth) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _dot(22, radius: AppRadius.small),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TracelyShimmerLine(width: titleWidth, height: 15),
                const SizedBox(height: AppSpacing.xs + 2),
                TracelyShimmerLine(width: titleWidth * 0.55, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double size, {BoxShape shape = BoxShape.rectangle, BorderRadius? radius}) {
    return TracelyShimmer(
      width: size,
      height: size,
      borderRadius: shape == BoxShape.circle
          ? BorderRadius.circular(size / 2)
          : (radius ?? AppRadius.small),
    );
  }
}
