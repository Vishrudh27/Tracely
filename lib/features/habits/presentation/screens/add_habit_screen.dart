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

/// Full-screen Add Habit form.
///
/// Slides up from the bottom (see AppRouter). Warm, inviting copy throughout.
/// The save button says "Start Building" — not "Save" or "Create".
class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  final _nameController = TextEditingController();
  Category? _selectedCategory;
  String _frequencyType = 'daily';
  List<int> _specificDays = [];
  String? _selectedEmoji;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _selectedCategory != null;

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      String? frequencyConfig;
      if (_frequencyType == 'specific_days' && _specificDays.isNotEmpty) {
        frequencyConfig = '[${_specificDays.join(",")}]';
      }

      await db.habitDao.insertHabit(
        HabitsCompanion.insert(
          name: _nameController.text.trim(),
          emoji: drift.Value(_selectedEmoji),
          categoryId: _selectedCategory!.id,
          frequencyType: drift.Value(_frequencyType),
          frequencyConfig: drift.Value(frequencyConfig),
        ),
      );

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          'New Habit',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // Habit name field
                    _buildNameField(),
                    const SizedBox(height: AppSpacing.xxxl),

                    // Category picker
                    _buildSectionLabel(AppStrings.categoryLabel),
                    const SizedBox(height: AppSpacing.md),
                    categoriesAsync.when(
                      data: (cats) => CategoryPicker(
                        categories: cats,
                        selected: _selectedCategory,
                        onSelected: (c) =>
                            setState(() => _selectedCategory = c),
                      ),
                      loading: () => const SizedBox(height: 120),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),

                    // Frequency selector
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

                    // Emoji picker
                    _buildSectionLabel('${AppStrings.emojiLabel} (optional)'),
                    const SizedBox(height: AppSpacing.md),
                    EmojiPickerGrid(
                      selected: _selectedEmoji,
                      onSelected: (e) =>
                          setState(() => _selectedEmoji = e == _selectedEmoji ? null : e),
                    ),

                    const SizedBox(height: AppSpacing.huge),
                  ],
                ),
              ),
            ),

            // Save button
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          autofocus: true,
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
        ),
      ],
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
                  AppStrings.saveHabitButton,
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
