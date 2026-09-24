import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/models/task_models.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../habits/presentation/widgets/category_picker.dart';

/// Full-screen Add Task form — deliberately lighter and shorter than Add
/// Habit: fewer fields, more air. See docs/stitch_prompt_kit.md §3.13.
class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _dueDate = DateTime.now();
  TimeOfDay? _dueTime;
  TaskPriority _priority = TaskPriority.normal;
  Category? _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSave => _titleController.text.trim().isNotEmpty && !_isSaving;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(taskRepositoryProvider).addTask(
            title: _titleController.text.trim(),
            dueDate: _dueDate == null
                ? null
                : DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day),
            dueTime: _dueTime == null
                ? null
                : '${_dueTime!.hour.toString().padLeft(2, '0')}:'
                    '${_dueTime!.minute.toString().padLeft(2, '0')}',
            priority: _priority,
            categoryId: _selectedCategory?.id,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _dueDateLabel {
    final date = _dueDate;
    if (date == null) return 'Pick a date';
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return isToday ? AppStrings.taskDueDateToday : DateFormat('d MMM').format(date);
  }

  String get _dueTimeLabel {
    final time = _dueTime;
    if (time == null) return 'Add time';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppStrings.addTaskTitle,
          style: context.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(
              AppStrings.saveTaskButton,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: _canSave
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.38),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              _Label(AppStrings.taskNameLabel),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _titleController,
                style: context.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: AppStrings.taskNameHint,
                  hintStyle: context.textTheme.bodyLarge
                      ?.copyWith(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: AppSpacing.input,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.input,
                    borderSide: BorderSide(color: AppColors.borderOutline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.input,
                    borderSide: BorderSide(color: AppColors.borderOutline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.input,
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              _Label(AppStrings.taskDueLabel),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _SelectorField(
                      icon: Icons.calendar_today_outlined,
                      label: _dueDateLabel,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _SelectorField(
                      icon: Icons.access_time_outlined,
                      label: _dueTimeLabel,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),

              _Label(AppStrings.taskPriorityLabel),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  _PriorityChip(
                    label: AppStrings.taskPriorityLow,
                    dotColor: AppColors.priorityLow,
                    selected: _priority == TaskPriority.low,
                    onTap: () => setState(() => _priority = TaskPriority.low),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _PriorityChip(
                    label: AppStrings.taskPriorityNormal,
                    dotColor: AppColors.priorityMedium,
                    selected: _priority == TaskPriority.normal,
                    onTap: () =>
                        setState(() => _priority = TaskPriority.normal),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _PriorityChip(
                    label: AppStrings.taskPriorityHigh,
                    dotColor: AppColors.priorityHigh,
                    selected: _priority == TaskPriority.high,
                    onTap: () =>
                        setState(() => _priority = TaskPriority.high),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),

              _Label(AppStrings.categoryLabel),
              const SizedBox(height: AppSpacing.sm),
              categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (cats) => CategoryPicker(
                  categories: cats,
                  selected: _selectedCategory,
                  onSelected: (c) => setState(() {
                    _selectedCategory = _selectedCategory?.id == c.id ? null : c;
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              _Label(AppStrings.taskNotesLabel),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 4,
                minLines: 4,
                style: context.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: AppStrings.taskNotesHint,
                  hintStyle: context.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: AppSpacing.input,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.input,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.input,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.input,
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppSizes.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.input,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSizes.iconMd, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: context.textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color dotColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: AppSizes.chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: context.textTheme.labelLarge?.copyWith(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
