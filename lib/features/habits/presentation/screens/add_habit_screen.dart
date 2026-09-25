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
import '../widgets/habit_form_tip_card.dart';
import '../widgets/icon_picker_grid.dart';
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
  String? _selectedIcon;
  bool _isSaving = false;

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
          emoji: drift.Value(_selectedIcon),
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  top: AppSpacing.sm,
                  bottom: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name field
                    _buildSectionLabel(AppStrings.habitNameLabel),
                    const SizedBox(height: AppSpacing.sm),
                    _buildNameField(),
                    const SizedBox(height: AppSpacing.xxl),

                    // Icon picker
                    _buildSectionLabel(AppStrings.iconLabel),
                    const SizedBox(height: AppSpacing.sm),
                    IconPickerGrid(
                      selected: _selectedIcon,
                      onSelected: (e) =>
                          setState(() => _selectedIcon = e == _selectedIcon ? null : e),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Category picker
                    _buildSectionLabel(AppStrings.categoryLabel),
                    const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.xxl),

                    // Frequency selector
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
                    const SizedBox(height: AppSpacing.huge),
                  ],
                ),
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
          Text('New Habit', style: context.textTheme.headlineMedium),
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
                    AppStrings.saveHabitButton,
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
        autofocus: true,
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
