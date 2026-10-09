import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/habit_schedule.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../../data/services/reminder_service.dart';
import '../widgets/category_picker.dart';
import '../widgets/habit_form_tip_card.dart';
import '../widgets/icon_picker_grid.dart';
import '../widgets/frequency_selector.dart';
import '../widgets/reminder_time_field.dart';

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
  int? _reminderMinute;
  bool _isAlarmReminder = false;
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
      final messenger = ScaffoldMessenger.of(context);
      final habits = ref.read(habitRepositoryProvider);
      String? frequencyConfig;
      if (_frequencyType == 'specific_days' && _specificDays.isNotEmpty) {
        frequencyConfig = '[${_specificDays.join(",")}]';
      }
      final reminder = _reminderMinute;
      // Saved either way — the reminder starts showing once permission is
      // granted, so the row isn't lying.
      if (reminder != null) {
        if (!await ReminderService.requestPermission()) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(AppStrings.notificationsOff),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        if (_isAlarmReminder && !await ReminderService.canScheduleExact()) {
          await ReminderService.requestExactAlarmPermission();
        }
      }

      await habits.createHabit(
        HabitsCompanion.insert(
          name: _nameController.text.trim(),
          emoji: drift.Value(_selectedIcon),
          categoryId: _selectedCategory!.id,
          frequencyType: drift.Value(_frequencyType),
          frequencyConfig: drift.Value(frequencyConfig),
          reminderEnabled: drift.Value(reminder != null),
          reminderTime:
              drift.Value(reminder == null ? null : formatHhMm(reminder)),
          isAlarmReminder: drift.Value(reminder != null && _isAlarmReminder),
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
                    const SizedBox(height: AppSpacing.xxl),

                    _buildSectionLabel(AppStrings.reminderLabel),
                    const SizedBox(height: AppSpacing.sm),
                    ReminderTimeField(
                      minuteOfDay: _reminderMinute,
                      onChanged: (v) => setState(() => _reminderMinute = v),
                    ),
                    if (_reminderMinute != null) ...[  
                      const SizedBox(height: AppSpacing.md),
                      _CallReminderToggle(
                        value: _isAlarmReminder,
                        onChanged: (v) =>
                            setState(() => _isAlarmReminder = v),
                      ),
                    ],
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
              icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
              onPressed: () => context.pop(),
            ),
          ),
          Text('New Habit', style: context.textTheme.headlineMedium),
          TextButton(
            onPressed: _canSave ? _save : null,
            child: _isSaving
                ? SizedBox(
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
            borderSide: BorderSide(color: AppColors.borderOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.borderOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: context.textTheme.titleSmall);
  }
}

/// Inline Call Reminder toggle — shown only when a reminder time is set.
///
/// Appears below the [ReminderTimeField] and slides in with an animated cross-
/// fade so the form doesn't jump. Mirrors the `_SettingsSwitch` look.
class _CallReminderToggle extends StatelessWidget {
  const _CallReminderToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: value ? AppColors.primary : AppColors.borderOutline,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.phone_in_talk_rounded,
              size: AppSizes.iconMd,
              color: value ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.callReminderLabel,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: value
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    AppStrings.callReminderSubtitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _MiniSwitch(value: value),
          ],
        ),
      ),
    );
  }
}

/// Miniature pill switch matching the Stitch design — shared with Edit Habit.
class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? AppColors.primary : AppColors.border,
        borderRadius: AppRadius.fab,
      ),
      child: AnimatedAlign(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: const Color(0x26000000),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
