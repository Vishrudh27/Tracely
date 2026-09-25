import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../core/widgets/animated_list_item.dart';
import '../../../../core/widgets/count_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../data/models/habit_models.dart';
import '../../../../data/models/task_models.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../data/services/reflection_gate_service.dart';
import '../../../reflection/presentation/widgets/pause_and_reflect_sheet.dart';
import '../widgets/daily_progress_card.dart';
import '../widgets/dashboard_greeting_section.dart';
import '../widgets/dashboard_motivation_footer.dart';
import '../widgets/dashboard_state_views.dart';
import '../widgets/habit_tile.dart';
import '../widgets/todays_tasks_section.dart';

/// The Dashboard — Tracely's daily companion screen, matching the Stitch
/// `dashboard/code.html` mockup: plain greeting header, ring progress card,
/// Today's Habits, Today's Tasks, quote footer.
///
/// Entrance animation (total: 950ms) uses a single AnimationController.
/// All child widgets receive animated values computed from Interval slices.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _greetingOpacity;
  late final Animation<double> _greetingSlide;
  late final Animation<double> _progressOpacity;
  late final Animation<double> _progressSlide;
  late final Animation<double> _habitsHeaderOpacity;
  late final Animation<double> _habitsHeaderSlide;
  late final Animation<double> _tasksOpacity;
  late final Animation<double> _tasksSlide;
  late final Animation<double> _footerOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      _checkPauseAndReflect();
    });
  }

  void _setupAnimations() {
    // 1. Greeting: 0.0–0.20
    _greetingOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
    );
    _greetingSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Progress card: 0.10–0.40
    _progressOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.10, 0.40, curve: Curves.easeOut),
    );
    _progressSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Habits header: 0.25–0.45
    _habitsHeaderOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.45, curve: Curves.easeOut),
    );
    _habitsHeaderSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Today's Tasks: 0.55–0.80
    _tasksOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
    );
    _tasksSlide = Tween<double>(begin: 16, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.83, curve: Curves.easeOutCubic),
      ),
    );

    // 5. Footer: 0.80–1.0
    _footerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
    );
  }

  Future<void> _checkPauseAndReflect() async {
    // Only trigger if mounted and context is available
    if (!mounted) return;

    try {
      // Check if there were any habits missed yesterday
      final yesterday = ref.read(currentDateProvider).addDays(-1);
      final missedHabits = await ref
          .read(habitRepositoryProvider)
          .getMissedHabitsForDate(yesterday);

      if (!mounted || missedHabits.isEmpty) return;

      // Gate: once per calendar day, however the sheet is answered.
      final shouldShow = await ReflectionGateService.shouldShowPauseAndReflect();
      if (!mounted || !shouldShow) return;

      await ReflectionGateService.markPauseAndReflectShown();
      if (!mounted) return;

      await PauseAndReflectSheet.show(
        context: context,
        missedHabits: missedHabits,
      );
    } catch (_) {
      // An optional reflection prompt must never take the dashboard down.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Small counts read better as words — "All five, done." matches Stitch;
  /// above ten, digits are clearer than spelling them out.
  static String _countWord(int n) {
    const words = [
      'zero', 'one', 'two', 'three', 'four', 'five',
      'six', 'seven', 'eight', 'nine', 'ten',
    ];
    return n >= 0 && n < words.length ? words[n] : '$n';
  }

  Future<void> _toggleHabit(int habitId) async {
    final today = ref.read(currentDateProvider);
    await ref.read(habitRepositoryProvider).toggleCompletion(habitId, today);
  }

  Future<void> _toggleTask(int taskId, bool isDone) async {
    await ref.read(taskRepositoryProvider).setTaskDone(taskId, isDone);
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(todaysHabitsProvider);
    final activeHabitsAsync = ref.watch(activeHabitsProvider);
    final tasksAsync = ref.watch(todaysTasksProvider);
    final streakAsync = ref.watch(overallStreakProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return habitsAsync.when(
              loading: () => _buildLoadingState(),
              error: (err, stack) => _buildErrorState(err),
              data: (habits) {
                if (habits.isEmpty) {
                  // Zero scheduled *today* has two very different causes:
                  // no habit ever created (true first-run empty state), or
                  // habits exist but none are due today, e.g. a Mon–Fri
                  // habit's Saturday (a rest day — Today's Tasks still
                  // matters there, since tasks aren't schedule-gated).
                  final hasAnyHabit =
                      activeHabitsAsync.asData?.value.isNotEmpty ?? false;
                  return hasAnyHabit
                      ? _buildRestDayState(tasksAsync.asData?.value ?? [])
                      : _buildEmptyState();
                }
                // Single source of truth: the ring and the header count
                // both derive from this same habits list.
                final progress = DailyProgress(
                  completedCount:
                      habits.where((h) => h.isCompletedToday).length,
                  totalCount: habits.length,
                );
                return _buildLoadedState(
                  habits: habits,
                  progress: progress,
                  tasks: tasksAsync.asData?.value ?? [],
                  currentStreak:
                      streakAsync.asData?.value.currentStreak ?? 0,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------

  Widget _buildLoadingState() => const DashboardLoadingView();

  // ---------------------------------------------------------------------------
  // Error state
  // ---------------------------------------------------------------------------

  Widget _buildErrorState(Object error) {
    return DashboardErrorView(
      onRetry: () => ref.invalidate(todaysHabitsProvider),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Opacity(
      opacity: _greetingOpacity.value,
      child: DashboardEmptyView(
        onAddHabit: () => context.push(AppRouter.addHabit),
        onSettingsTap: () => context.push(AppRouter.settings),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rest-day state — habits exist, none scheduled today
  // ---------------------------------------------------------------------------

  Widget _buildRestDayState(List<TaskWithCategory> tasks) {
    return Opacity(
      opacity: _greetingOpacity.value,
      child: DashboardRestDayView(
        tasks: tasks,
        onToggleTask: _toggleTask,
        onSettingsTap: () => context.push(AppRouter.settings),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loaded state
  // ---------------------------------------------------------------------------

  Widget _buildLoadedState({
    required List<HabitWithCompletion> habits,
    required DailyProgress progress,
    required List<TaskWithCategory> tasks,
    required int currentStreak,
  }) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // 1. Greeting
              DashboardGreetingSection(
                opacity: _greetingOpacity.value,
                translateY: _greetingSlide.value,
                currentStreak: currentStreak,
                allDone: progress.allDone,
                onSettingsTap: () => context.push(AppRouter.settings),
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              // 2. Daily Progress Ring
              DailyProgressCard(
                progress: progress,
                controller: _controller,
                cardOpacity: _progressOpacity.value,
                cardTranslateY: _progressSlide.value,
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              // 3. Today's Habits header
              Opacity(
                opacity: _habitsHeaderOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _habitsHeaderSlide.value),
                  child: SectionHeader(
                    title: AppStrings.sectionTodaysHabits,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    trailing: CountBadge(
                      done:
                          habits.where((h) => h.isCompletedToday).length,
                      total: habits.length,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),

        // 3b. Habit tiles (staggered)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              return AnimatedListItem(
                controller: _controller,
                index: i,
                totalItems: habits.length,
                intervalStart: 0.30,
                intervalEnd: 0.70,
                child: HabitTile(
                  habit: habits[i],
                  onToggle: () => _toggleHabit(habits[i].habitId),
                  allDone: progress.allDone,
                ),
              );
            },
            childCount: habits.length,
          ),
        ),

        SliverToBoxAdapter(
          child: Column(
            children: [
              if (progress.allDone) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'All ${_countWord(progress.totalCount)}, done.',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.sectionGap),

              // 4. Today's Tasks
              TodaysTasksSection(
                tasks: tasks,
                onToggle: _toggleTask,
                allDone: progress.allDone,
                opacity: _tasksOpacity.value,
                translateY: _tasksSlide.value,
              ),

              // 5. Motivation footer
              DashboardMotivationFooter(
                opacity: _footerOpacity.value,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
