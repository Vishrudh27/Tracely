import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../data/services/database_service.dart';
import '../../../../data/models/habit_models.dart';

// ---------------------------------------------------------------------------
// Data types
// ---------------------------------------------------------------------------

/// A single selectable reason card within a category.
class _ReasonItem {
  const _ReasonItem({required this.label, required this.key});
  final String label;
  final String key;
}

/// A top-level reason category.
class _ReasonCategory {
  const _ReasonCategory({
    required this.key,
    required this.icon,
    required this.label,
    required this.reasons,
  });
  final String key;
  final IconData icon;
  final String label;
  final List<_ReasonItem> reasons;
}

// ---------------------------------------------------------------------------
// Static data (reason taxonomy — per §4.5)
// ---------------------------------------------------------------------------

const _kCategories = <_ReasonCategory>[
  _ReasonCategory(
    key: 'energy',
    icon: Icons.bedtime_outlined,
    label: 'Energy',
    reasons: [
      _ReasonItem(label: 'Low Energy', key: 'low_energy'),
      _ReasonItem(label: 'Poor Sleep', key: 'poor_sleep'),
      _ReasonItem(label: 'Felt Sick', key: 'felt_sick'),
      _ReasonItem(label: 'Burned Out', key: 'burned_out'),
    ],
  ),
  _ReasonCategory(
    key: 'time',
    icon: Icons.schedule_outlined,
    label: 'Time',
    reasons: [
      _ReasonItem(label: 'Too Busy', key: 'too_busy'),
      _ReasonItem(label: 'Unexpected Work', key: 'unexpected_work'),
      _ReasonItem(label: 'Meetings', key: 'meetings'),
      _ReasonItem(label: 'Family Responsibilities', key: 'family'),
    ],
  ),
  _ReasonCategory(
    key: 'mind',
    icon: Icons.psychology_outlined,
    label: 'Mind',
    reasons: [
      _ReasonItem(label: 'Lost Motivation', key: 'lost_motivation'),
      _ReasonItem(label: 'Procrastinated', key: 'procrastinated'),
      _ReasonItem(label: 'Forgot', key: 'forgot'),
      _ReasonItem(label: 'Felt Overwhelmed', key: 'felt_overwhelmed'),
      _ReasonItem(label: "Couldn't Focus", key: 'couldnt_focus'),
    ],
  ),
  _ReasonCategory(
    key: 'environment',
    icon: Icons.public_outlined,
    label: 'Environment',
    reasons: [
      _ReasonItem(label: 'Traveling', key: 'traveling'),
      _ReasonItem(label: 'Weather', key: 'weather'),
      _ReasonItem(label: 'No Equipment', key: 'no_equipment'),
      _ReasonItem(label: 'Outside Home', key: 'outside_home'),
    ],
  ),
  _ReasonCategory(
    key: 'personal',
    icon: Icons.favorite_outline,
    label: 'Personal',
    reasons: [
      _ReasonItem(label: 'Needed Rest', key: 'needed_rest'),
      _ReasonItem(label: 'Mental Break', key: 'mental_break'),
      _ReasonItem(label: 'Personal Event', key: 'personal_event'),
      _ReasonItem(label: 'Emergency', key: 'emergency'),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Follow-up question lookup (per §4.5 table)
// ---------------------------------------------------------------------------

class _FollowUp {
  const _FollowUp({required this.question, required this.options});
  final String question;
  final List<String> options;
}

const _kFollowUpMap = <String, _FollowUp>{
  'low_energy': _FollowUp(
    question: 'How was your energy?',
    options: ['Great', 'Okay', 'Very Low'],
  ),
  'poor_sleep': _FollowUp(
    question: 'How did you sleep?',
    options: ['Badly', 'Okay', 'Well'],
  ),
  'too_busy': _FollowUp(
    question: 'What kept you busy?',
    options: ['Work', 'College', 'Family', 'Other'],
  ),
  'lost_motivation': _FollowUp(
    question: 'Has this been going on?',
    options: ['Just today', 'A few days', 'A while'],
  ),
  'felt_overwhelmed': _FollowUp(
    question: 'Was it habit-related?',
    options: ['Yes', 'No', 'Not sure'],
  ),
};

/// Returns the first follow-up question for any trigger key in [selectedKeys],
/// or null if none of the selected keys have a follow-up.
_FollowUp? _resolveFollowUp(List<String> selectedKeys) {
  for (final key in selectedKeys) {
    if (_kFollowUpMap.containsKey(key)) return _kFollowUpMap[key];
  }
  return null;
}

// ---------------------------------------------------------------------------
// PauseAndReflectSheet
// ---------------------------------------------------------------------------

/// The Pause & Reflect modal bottom sheet (§4.5).
///
/// Triggered from DashboardScreen when the user opens the app the morning
/// after missing habits. Presented at most once per day.
///
/// Features:
/// - 5 reason categories with soft card chips
/// - 2-selection max (FIFO deselect when a 3rd is chosen)
/// - Conditional follow-up question based on the first trigger reason
/// - Custom free-text "My Reason" input
/// - Staggered card entrance animation
/// - "Not now" dismiss with zero friction
///
/// Data is persisted to HabitReflections table via ReflectionDao.
class PauseAndReflectSheet extends ConsumerStatefulWidget {
  const PauseAndReflectSheet._({required this.missedHabits});

  final List<HabitWithCompletion> missedHabits;

  /// Show the sheet. Returns when the user dismisses or submits.
  static Future<void> show({
    required BuildContext context,
    required List<HabitWithCompletion> missedHabits,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => PauseAndReflectSheet._(missedHabits: missedHabits),
    );
  }

  @override
  ConsumerState<PauseAndReflectSheet> createState() =>
      _PauseAndReflectSheetState();
}

class _PauseAndReflectSheetState extends ConsumerState<PauseAndReflectSheet>
    with SingleTickerProviderStateMixin {
  // ----- Animation ----------------------------------------------------------

  late final AnimationController _controller;

  // ----- Selection state ----------------------------------------------------

  /// Selected reason item keys (max 2, FIFO: first in, first out).
  final List<String> _selectedKeys = [];

  /// Custom free-text reason entered by the user.
  final TextEditingController _customTextController = TextEditingController();

  /// Currently selected follow-up answer (if a follow-up is shown).
  String? _selectedFollowUp;

  bool _isSaving = false;

  /// Mirrors whether the free-text field has content, so the footer button can
  /// react to typing. A TextField does not rebuild its ancestors on its own.
  bool _hasCustomText = false;

  // ----- Derived state ------------------------------------------------------

  /// Follow-up question to display, or null if none apply.
  _FollowUp? get _activeFollowUp => _resolveFollowUp(_selectedKeys);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _customTextController.addListener(_onCustomTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  void _onCustomTextChanged() {
    final hasText = _customTextController.text.trim().isNotEmpty;
    if (hasText != _hasCustomText) {
      setState(() => _hasCustomText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _customTextController
      ..removeListener(_onCustomTextChanged)
      ..dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Selection logic
  // ---------------------------------------------------------------------------

  void _toggleReason(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        // Max 2 selections — FIFO: remove oldest if at capacity
        if (_selectedKeys.length >= 2) {
          _selectedKeys.removeAt(0); // remove the first (oldest) selection
        }
        _selectedKeys.add(key);
      }
      // Reset follow-up answer if selection changes
      _selectedFollowUp = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      final today = ref.read(currentDateProvider);
      final yesterday = today.addDays(-1);

      final customText = _customTextController.text.trim();

      // One row per reason so Statistics can group on an atomic key. A joined
      // string made every distinct combination read as its own reason.
      final reasons = <({String key, String? answer})>[
        for (final key in _selectedKeys) (key: key, answer: _selectedFollowUp),
        if (customText.isNotEmpty) (key: 'custom', answer: customText),
      ];

      if (reasons.isEmpty) return;

      for (final habit in widget.missedHabits) {
        for (final reason in reasons) {
          await db.reflectionDao.createHabitReflection(
            habitId: habit.habitId,
            missedDate: yesterday,
            reason: reason.key,
            followUpAnswer: reason.answer,
          );
        }
      }
    } catch (_) {
      // Non-fatal — reflection failure never blocks the user
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _dismiss() => Navigator.of(context).pop();

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;

    // Shrink to whatever the keyboard leaves behind, otherwise the free-text
    // field sits underneath it with no way to scroll into view.
    final preferred = media.size.height * 0.82;
    final available = media.size.height - keyboardInset - media.padding.top;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        height: preferred < available ? preferred : available,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row with "Not now" dismiss
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _dismiss,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Leaf icon + header text
                    const Icon(
                      Icons.eco_outlined,
                      size: 32,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      "Today didn't go exactly as planned.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "That's okay.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'What got in the way today?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    // Reason categories — staggered fade in
                    ..._buildCategoryList(),

                    // Custom "My Reason" text input
                    _buildMyReasonInput(),

                    // Follow-up question (conditional)
                    if (_activeFollowUp != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _buildFollowUp(_activeFollowUp!),
                    ],

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),

            // Footer: Continue/Done + closing line
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  List<Widget> _buildCategoryList() {
    final widgets = <Widget>[];
    for (int i = 0; i < _kCategories.length; i++) {
      final category = _kCategories[i];

      // Stagger per category: distribute across 0.0–0.85 of 700ms
      final itemCount = _kCategories.length;
      final step = 0.85 / itemCount;
      final start = (i * step * 0.65).clamp(0.0, 0.84);
      final end = (start + step * 1.4).clamp(start + 0.05, 1.0);

      final opacity = CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
      final slide = Tween<double>(begin: 16, end: 0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );

      widgets.add(
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Opacity(
            opacity: opacity.value,
            child: Transform.translate(
              offset: Offset(0, slide.value),
              child: _CategorySection(
                category: category,
                selectedKeys: _selectedKeys,
                onToggle: _toggleReason,
              ),
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: AppSpacing.lg));
    }
    return widgets;
  }

  Widget _buildMyReasonInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_outlined, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'My Reason',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _customTextController,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Something else on your mind...',
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.input,
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUp(_FollowUp followUp) {
    return AnimatedSize(
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            followUp.question,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: followUp.options.map((option) {
              final isSelected = _selectedFollowUp == option;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedFollowUp = isSelected ? null : option;
                }),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surfaceVariant,
                    borderRadius: AppRadius.chip,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    option,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final hasSelection = _selectedKeys.isNotEmpty || _hasCustomText;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
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
                    : Text(hasSelection ? 'Continue' : 'Done'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Tomorrow, we'll try again.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CategorySection — one collapsible reason category
// ---------------------------------------------------------------------------

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.selectedKeys,
    required this.onToggle,
  });

  final _ReasonCategory category;
  final List<String> selectedKeys;
  final void Function(String key) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category label
        Row(
          children: [
            Icon(category.icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(
              category.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Reason chips
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: category.reasons.map((reason) {
            final isSelected = selectedKeys.contains(reason.key);
            return _ReasonChip(
              label: reason.label,
              isSelected: isSelected,
              onTap: () => onToggle(reason.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ReasonChip — individual selectable reason card
// ---------------------------------------------------------------------------

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceVariant,
          borderRadius: AppRadius.chip,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
