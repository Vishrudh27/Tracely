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
/// The "Today" filter (default) is a smart combined view: Overdue + Today +
/// Tomorrow, grouped under headers, since overdue items always need
/// surfacing regardless of which day the user opened the app on. The other
/// three filters (Upcoming, Overdue, Done) are single flat lists.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _searching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: AppTypography.textTheme.bodyLarge,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search tasks',
                    ),
                  )
                : Text(
                    AppStrings.tasksScreenTitle,
                    style: AppTypography.textTheme.displaySmall,
                  ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                _searching ? Icons.close_rounded : Icons.search_rounded,
                size: 22,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _searchController.clear();
              }),
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
          final query = _searchController.text.trim().toLowerCase();
          final visible = query.isEmpty
              ? allTasks
              : allTasks
                  .where((t) => t.title.toLowerCase().contains(query))
                  .toList();

          if (allTasks.isEmpty) {
            return TracelyEmptyState(
              icon: Icons.checklist_rounded,
              title: AppStrings.emptyTasksTitle,
              body: AppStrings.emptyTasksBody,
              ctaLabel: AppStrings.emptyTasksCta,
              onCta: () => context.push(AppRouter.addTask),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.xs,
                ),
                child: _FilterRow(
                  selected: filter,
                  onSelect: (f) =>
                      ref.read(taskFilterProvider.notifier).select(f),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: _TaskListForFilter(
                  filter: filter,
                  tasks: visible,
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
  const _FilterRow({required this.selected, required this.onSelect});

  final TaskFilter selected;
  final ValueChanged<TaskFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: AppStrings.taskFilterToday,
            selected: selected == TaskFilter.today,
            onTap: () => onSelect(TaskFilter.today),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterChip(
            label: AppStrings.taskFilterUpcoming,
            selected: selected == TaskFilter.upcoming,
            onTap: () => onSelect(TaskFilter.upcoming),
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterChip(
            label: AppStrings.taskFilterOverdue,
            selected: selected == TaskFilter.overdue,
            onTap: () => onSelect(TaskFilter.overdue),
            leadingDotColor: AppColors.accentTerracotta,
          ),
          const SizedBox(width: AppSpacing.sm),
          _FilterChip(
            label: AppStrings.taskFilterDone,
            selected: selected == TaskFilter.done,
            onTap: () => onSelect(TaskFilter.done),
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: selected ? AppShadows.sm : null,
        ),
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
              style: AppTypography.textTheme.labelLarge?.copyWith(
                color: selected
                    ? AppColors.textOnPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
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

  Widget _group(
    BuildContext context,
    String header,
    List<TaskWithCategory> items, {
    bool overdue = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: Text(
            header,
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.textDisabled,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        for (final task in items)
          _taskRow(context, task, overdue: overdue, showDate: overdue),
      ],
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
        final notDone = tasks.where((t) => !t.isDone).toList();
        final overdue = notDone
            .where((t) => t.groupFor(today) == TaskGroup.overdue)
            .toList();
        // Today keeps done tasks inline (dimmed, struck through, in place)
        // rather than dropping them — matches Stitch's "Prepare herbal
        // infusion" example and Dashboard's todaysTasksProvider.
        final dueToday =
            tasks.where((t) => t.groupFor(today) == TaskGroup.today).toList();
        final tomorrow = notDone
            .where((t) => t.groupFor(today) == TaskGroup.tomorrow)
            .toList();
        if (overdue.isEmpty && dueToday.isEmpty && tomorrow.isEmpty) {
          return const TracelyEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'All caught up',
            body: 'Nothing overdue, due today, or due tomorrow.',
          );
        }
        final sections = [
          (AppStrings.taskGroupOverdue, overdue, true),
          (AppStrings.taskGroupToday, dueToday, false),
          (AppStrings.taskGroupTomorrow, tomorrow, false),
        ].where((s) => s.$2.isNotEmpty).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.huge),
          children: [
            for (var i = 0; i < sections.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? AppSpacing.xs : AppSpacing.lg),
                child: _group(
                  context,
                  sections[i].$1,
                  sections[i].$2,
                  overdue: sections[i].$3,
                ),
              ),
          ],
        );

      case TaskFilter.upcoming:
        final upcoming = tasks
            .where((t) => !t.isDone && t.groupFor(today) == TaskGroup.upcoming)
            .toList();
        if (upcoming.isEmpty) {
          return const TracelyEmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nothing further out',
            body: 'Tasks due later than tomorrow will show up here.',
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
