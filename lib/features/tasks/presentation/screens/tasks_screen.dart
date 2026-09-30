import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../data/models/task_models.dart';
import '../../../../data/repositories/task_repository.dart';
import '../widgets/task_tile.dart';

/// The to-do list. Deliberately flatter and lighter than Habits — see
/// docs/stitch_prompt_kit.md §3.12.
///
/// Each filter shows exactly what its name says, no overlap: Today = due
/// today only, Upcoming = due tomorrow or later, Overdue = past due, Done =
/// completed. Overdue used to also appear under Today; that double listing
/// was the "categorization" bug fixed here.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final filter = ref.watch(taskFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody(tasksAsync, filter)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRouter.addTask),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: AppSizes.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.tasksScreenTitle,
              style: AppTypography.textTheme.displaySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<TaskWithCategory>> tasksAsync,
    TaskFilter filter,
  ) {
    return tasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => TracelyEmptyState(
        icon: Icons.error_outline,
        title: AppStrings.errorDashboardTitle,
        body: AppStrings.errorDashboardBody,
      ),
      data: (allTasks) {
        if (allTasks.isEmpty) {
          return TracelyEmptyState(
            icon: Icons.checklist_rounded,
            title: AppStrings.emptyTasksTitle,
            body: AppStrings.emptyTasksBody,
            ctaLabel: AppStrings.emptyTasksCta,
            onCta: () => context.push(AppRouter.addTask),
          );
        }

        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        final hasOverdue = allTasks.any(
          (t) => !t.isDone && t.groupFor(todayOnly) == TaskGroup.overdue,
        );

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xs,
              ),
              child: _FilterRow(
                selected: filter,
                hasOverdue: hasOverdue,
                onSelect: (f) =>
                    ref.read(taskFilterProvider.notifier).select(f),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _TaskListForFilter(
                filter: filter,
                tasks: allTasks,
                ref: ref,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.hasOverdue,
    required this.onSelect,
  });

  final TaskFilter selected;
  final bool hasOverdue;
  final ValueChanged<TaskFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    // Only 4 filters — one row, equal-width, always fits with no scroll
    // and no wrap (unlike the 9-chip category filter on Habits).
    return SizedBox(
      height: AppSizes.chipHeight,
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              label: AppStrings.taskFilterToday,
              selected: selected == TaskFilter.today,
              onTap: () => onSelect(TaskFilter.today),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _FilterChip(
              label: AppStrings.taskFilterUpcoming,
              selected: selected == TaskFilter.upcoming,
              onTap: () => onSelect(TaskFilter.upcoming),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _FilterChip(
              label: AppStrings.taskFilterOverdue,
              selected: selected == TaskFilter.overdue,
              onTap: () => onSelect(TaskFilter.overdue),
              // Red while tasks are overdue, green once caught up — not a
              // static color, since this chip is a status indicator.
              leadingDotColor:
                  hasOverdue ? AppColors.statusOverdue : AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _FilterChip(
              label: AppStrings.taskFilterDone,
              selected: selected == TaskFilter.done,
              onTap: () => onSelect(TaskFilter.done),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingDotColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? leadingDotColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        height: AppSizes.chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: selected ? AppShadows.sm : null,
        ),
        // Equal-width slots on narrow screens get tight for "Upcoming" /
        // "Overdue" — shrink to fit rather than let the row overflow.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingDotColor != null && !selected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: leadingDotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                style: AppTypography.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? AppColors.textOnPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the task list body for whichever filter is selected.
///
/// Takes [ref] directly rather than wrapping itself in a `Consumer` — the
/// caller ([_TasksScreenState]) already has one via `ConsumerState`.
class _TaskListForFilter extends StatelessWidget {
  const _TaskListForFilter({
    required this.filter,
    required this.tasks,
    required this.ref,
  });

  final TaskFilter filter;
  final List<TaskWithCategory> tasks;
  final WidgetRef ref;

  Future<void> _toggle(TaskWithCategory task, bool value) {
    return ref.read(taskRepositoryProvider).setTaskDone(task.id, value);
  }

  Future<bool> _confirmDeleteTask(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const Text('Delete this task?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// A task row, swipe-to-delete — right-to-left reveals a red delete
  /// backdrop, confirmed the same way habit deletion is (see
  /// HabitDetailScreen). Not part of any Stitch mock; added on request.
  Widget _taskRow(
    BuildContext context,
    TaskWithCategory task, {
    bool overdue = false,
    bool showDate = false,
  }) {
    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await _confirmDeleteTask(context);
        if (!confirmed) return false;
        await ref.read(taskRepositoryProvider).deleteTask(task.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${task.title}" deleted.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return true;
      },
      child: TaskTile(
        task: task,
        showOverdueLabel: overdue,
        showDate: showDate,
        onToggle: (value) => _toggle(task, value),
      ),
    );
  }

  Widget _flatList(
    BuildContext context,
    List<TaskWithCategory> items, {
    bool overdue = false,
    bool showDate = true,
  }) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.huge),
      children: [
        for (final task in items)
          _taskRow(context, task, overdue: overdue, showDate: showDate),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case TaskFilter.today:
        // Today means today — overdue and tomorrow have their own tabs now,
        // so this tab no longer folds them in (they were double-listed).
        // Done tasks stay inline (dimmed, struck through, in place) rather
        // than dropping, matching Dashboard's todaysTasksProvider.
        final dueToday = tasks
            .where((t) => t.groupFor(today) == TaskGroup.today)
            .toList();
        if (dueToday.isEmpty) {
          return const TracelyEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'All caught up',
            body: 'Nothing due today.',
          );
        }
        return _flatList(context, dueToday, showDate: false);

      case TaskFilter.upcoming:
        final upcoming = tasks
            .where(
              (t) =>
                  !t.isDone &&
                  (t.groupFor(today) == TaskGroup.tomorrow ||
                      t.groupFor(today) == TaskGroup.upcoming),
            )
            .toList();
        if (upcoming.isEmpty) {
          return const TracelyEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nothing further out',
            body: 'Tasks due after today will show up here.',
          );
        }
        return _flatList(context, upcoming);

      case TaskFilter.overdue:
        final overdue = tasks
            .where((t) => !t.isDone && t.groupFor(today) == TaskGroup.overdue)
            .toList();
        if (overdue.isEmpty) {
          return const TracelyEmptyState(
            icon: Icons.celebration_outlined,
            title: 'Nothing overdue',
            body: 'You are fully caught up.',
          );
        }
        return _flatList(context, overdue, overdue: true);

      case TaskFilter.done:
        final done = tasks.where((t) => t.isDone).toList();
        if (done.isEmpty) {
          return const TracelyEmptyState(
            icon: Icons.task_alt_outlined,
            title: 'Nothing completed yet',
            body: 'Tasks you finish will collect here.',
          );
        }
        // Stitch shows "Completed at 9:15 AM" here — a completion timestamp
        // this schema doesn't store (only a done/not-done boolean). Showing
        // the due date instead would misleadingly imply that's when it was
        // finished, so this falls back to bare time + category.
        return _flatList(context, done, showDate: false);
    }
  }
}
