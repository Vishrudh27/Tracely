import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../../data/services/database_service.dart';
import '../widgets/category_picker.dart';
import '../widgets/emoji_picker_grid.dart';
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
  String? _selectedEmoji;
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
    _selectedEmoji = habit.emoji;
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
          emoji: drift.Value(_selectedEmoji),
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final habitsAsync = ref.watch(activeHabitsProvider);

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
          'Edit Habit',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => const SizedBox.shrink(),
          data: (categories) {
            final habit = habitsAsync.asData?.value
                .where((h) => h.id == widget.habitId)
                .firstOrNull;

            if (habit != null) _loadHabit(habit, categories);

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: AppSpacing.screen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        _buildNameField(),
                        const SizedBox(height: AppSpacing.xxxl),
                        _buildSectionLabel(AppStrings.categoryLabel),
                        const SizedBox(height: AppSpacing.md),
                        CategoryPicker(
                          categories: categories,
                          selected: _selectedCategory,
                          onSelected: (c) =>
                              setState(() => _selectedCategory = c),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        _buildSectionLabel(AppStrings.frequencyLabel),
                        const SizedBox(height: AppSpacing.md),
                        FrequencySelector(
                          frequencyType: _frequencyType,
                          specificDays: _specificDays,
                          onFrequencyTypeChanged: (v) =>
                              setState(() => _frequencyType = v),
                          onSpecificDaysChanged: (v) =>
                              setState(() => _specificDays = v),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        _buildSectionLabel('${AppStrings.emojiLabel} (optional)'),
                        const SizedBox(height: AppSpacing.md),
                        EmojiPickerGrid(
                          selected: _selectedEmoji,
                          onSelected: (e) => setState(
                            () => _selectedEmoji =
                                e == _selectedEmoji ? null : e,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        // Archive button
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
                        const SizedBox(height: AppSpacing.huge),
                      ],
                    ),
                  ),
                ),
                _buildSaveButton(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      onChanged: (_) => setState(() {}),
      textCapitalization: TextCapitalization.sentences,
      style: context.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: AppStrings.habitNameHint,
        hintStyle: context.textTheme.headlineSmall?.copyWith(
          color: AppColors.textDisabled,
          fontWeight: FontWeight.w400,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: context.textTheme.labelMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
      ),
      child: SizedBox(
        width: double.infinity,
        height: AppSizes.buttonHeight,
        child: ElevatedButton(
          onPressed: _canSave ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.disabled,
            foregroundColor: AppColors.textOnPrimary,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  AppStrings.updateHabitButton,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
