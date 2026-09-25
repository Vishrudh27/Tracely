import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../../data/services/database_service.dart';
import '../widgets/category_picker.dart';
import '../widgets/habit_delete_dialog.dart';
import '../widgets/habit_form_tip_card.dart';
import '../widgets/icon_picker_grid.dart';
import '../widgets/frequency_selector.dart';

/// Edit Habit screen — pre-populated form for an existing habit.
///
/// Identical layout to AddHabitScreen but with pre-filled values
/// and an Archive option at the bottom.
class EditHabitScreen extends ConsumerStatefulWidget {
  const EditHabitScreen({super.key, required this.habitId});

  final int habitId;

  @override
  ConsumerState<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends ConsumerState<EditHabitScreen> {
  final _nameController = TextEditingController();
  Category? _selectedCategory;
  String _frequencyType = 'daily';
  List<int> _specificDays = [];
  String? _selectedIcon;
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _selectedCategory != null &&
      // "Specific days" with nothing picked saves a null config, which the
      // scheduler reads as "every day" — block it instead of silently lying.
      (_frequencyType != 'specific_days' || _specificDays.isNotEmpty);

  void _loadHabit(Habit habit, List<Category> categories) {
    if (_isLoaded) return;
    _isLoaded = true;
    _nameController.text = habit.name;
    _selectedIcon = habit.emoji;
    _frequencyType = habit.frequencyType;
    // Without this the chosen weekdays came back empty, so saving any edit
    // wrote a null config and quietly turned the habit back into a daily one.
    _specificDays = _parseSpecificDays(habit.frequencyConfig);
    _selectedCategory =
        categories.where((c) => c.id == habit.categoryId).firstOrNull;
  }

  static List<int> _parseSpecificDays(String? config) {
    if (config == null || config.isEmpty) return [];
    try {
      final decoded = jsonDecode(config);
      if (decoded is! List) return [];
      return decoded.whereType<num>().map((d) => d.toInt()).toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      String? frequencyConfig;
      if (_frequencyType == 'specific_days' && _specificDays.isNotEmpty) {
        frequencyConfig = '[${_specificDays.join(",")}]';
      }

      await db.habitDao.updateHabit(
        HabitsCompanion(
          id: drift.Value(widget.habitId),
          name: drift.Value(_nameController.text.trim()),
          emoji: drift.Value(_selectedIcon),
          categoryId: drift.Value(_selectedCategory!.id),
          frequencyType: drift.Value(_frequencyType),
          frequencyConfig: drift.Value(frequencyConfig),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _archive() async {
    final habit = await ref.read(appDatabaseProvider).habitDao
        .getHabitById(widget.habitId);
    if (habit == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Text(
          AppStrings.archiveConfirmTitle,
          style: ctx.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppStrings.archiveConfirmBody,
          style: ctx.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              AppStrings.archiveCancelCta,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              AppStrings.archiveConfirmCta,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(appDatabaseProvider).habitDao.archiveHabit(widget.habitId);
      if (mounted) context.pop();
    }
  }

  Future<void> _deleteHabit() async {
    final confirmed = await confirmDeleteHabit(context);
    if (!confirmed || !mounted) return;

    // Both Habit Detail and this Edit screen sit above Habits on the
    // stack and both become stale once this habit is gone, so replace
    // down to Habits rather than popping back through either of them.
    final db = ref.read(appDatabaseProvider);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final habitName = _nameController.text.trim();
    router.go(AppRouter.habits);

    await db.deleteHabit(widget.habitId);

    messenger.showSnackBar(
      SnackBar(
        content: Text('"$habitName" deleted.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final habitsAsync = ref.watch(activeHabitsProvider);

    // Load before the header builds, so Save reflects the real form state
    // immediately instead of the empty-name default for one frame.
    final loadedCategories = categoriesAsync.asData?.value;
    final habitToLoad =
        habitsAsync.asData?.value.where((h) => h.id == widget.habitId).firstOrNull;
    if (habitToLoad != null && loadedCategories != null) {
      _loadHabit(habitToLoad, loadedCategories);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => const SizedBox.shrink(),
                data: (categories) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.xl,
                      right: AppSpacing.xl,
                      top: AppSpacing.sm,
                      bottom: AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(AppStrings.habitNameLabel),
                        const SizedBox(height: AppSpacing.sm),
                        _buildNameField(),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildSectionLabel(AppStrings.iconLabel),
                        const SizedBox(height: AppSpacing.sm),
                        IconPickerGrid(
                          selected: _selectedIcon,
                          onSelected: (e) => setState(
                            () => _selectedIcon =
                                e == _selectedIcon ? null : e,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildSectionLabel(AppStrings.categoryLabel),
                        const SizedBox(height: AppSpacing.sm),
                        CategoryPicker(
                          categories: categories,
                          selected: _selectedCategory,
                          onSelected: (c) =>
                              setState(() => _selectedCategory = c),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        _buildSectionLabel(AppStrings.frequencyLabel),
                        const SizedBox(height: AppSpacing.sm),
                        FrequencySelector(
                          frequencyType: _frequencyType,
                          specificDays: _specificDays,
                          onFrequencyTypeChanged: (v) =>
                              setState(() => _frequencyType = v),
                          onSpecificDaysChanged: (v) =>
                              setState(() => _specificDays = v),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        const HabitFormTipCard(),
                        const SizedBox(height: AppSpacing.xxxl),
                        // Archive — not in Stitch's mock (it only covers
                        // "New Habit"), kept as this screen's own addition.
                        Center(
                          child: TextButton(
                            onPressed: _archive,
                            child: Text(
                              AppStrings.archiveHabitButton,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: _deleteHabit,
                            child: Text(
                              'Delete habit',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.huge),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: AppSizes.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              onPressed: () => context.pop(),
            ),
          ),
          Text('Edit Habit', style: context.textTheme.headlineMedium),
          TextButton(
            onPressed: _canSave ? _save : null,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Text(
                    AppStrings.updateHabitButton,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary.withValues(
                        alpha: _canSave ? 1 : 0.38,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return SizedBox(
      height: AppSizes.inputHeight,
      child: TextField(
        controller: _nameController,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.sentences,
        textAlignVertical: TextAlignVertical.center,
        style: context.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: AppStrings.habitNameHint,
          hintStyle: context.textTheme.bodyLarge?.copyWith(
            color: AppColors.textDisabled,
          ),
          filled: true,
          fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.borderOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.borderOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: context.textTheme.titleSmall);
  }
}
