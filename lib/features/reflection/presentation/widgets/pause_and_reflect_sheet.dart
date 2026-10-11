import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../data/models/habit_models.dart';
import '../../../../data/services/database_service.dart';
import '../../../../data/services/reflection_gate_service.dart';
import 'my_reason_card.dart';
import 'reason_category_card.dart';
import 'reflection_orb.dart';
import 'reflection_taxonomy.dart';
import 'stones_strip.dart';

/// Modal bottom sheet orchestrating Pause & Reflect v2.
///
/// Features:
/// - One reflection row per day (upsert on [targetDate]).
/// - Max 2 reasons; choosing a 3rd removes the oldest FIFO.
/// - Inline contextual follow-up block within triggering category.
/// - Optional "My Reason" free-text field.
/// - Pre-fills existing reflection if already saved for [targetDate].
/// - Pinned header, scrolling staggered categories, and pinned footer.
class PauseAndReflectSheet extends ConsumerStatefulWidget {
  const PauseAndReflectSheet._({
    required this.targetDate,
    required this.missedHabits,
  });

  final DateTime targetDate;
  final List<HabitWithCompletion> missedHabits;

  /// Show the bottom sheet for [targetDate].
  static Future<void> show({
    required BuildContext context,
    required DateTime targetDate,
    required List<HabitWithCompletion> missedHabits,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => PauseAndReflectSheet._(
        targetDate: targetDate,
        missedHabits: missedHabits,
      ),
    );
  }

  @override
  ConsumerState<PauseAndReflectSheet> createState() =>
      _PauseAndReflectSheetState();
}

class _PauseAndReflectSheetState extends ConsumerState<PauseAndReflectSheet>
    with SingleTickerProviderStateMixin {
  final List<String> _selectedKeys = [];
  String? _activeFollowUpReasonKey;
  String? _selectedFollowUpAnswer;
  final TextEditingController _customTextController = TextEditingController();

  late final AnimationController _staggerController;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<double>> _cardSlides;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasExistingReflection = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: AppDurations.custom(700),
    );

    // 5 staggered intervals for the 5 category cards
    _cardFades = List.generate(5, (i) {
      final start = (i * 0.12).clamp(0.0, 0.70);
      final end = (start + 0.30).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: AppCurves.easeOut),
      );
    });

    _cardSlides = List.generate(5, (i) {
      final start = (i * 0.12).clamp(0.0, 0.70);
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 16, end: 0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start, end, curve: AppCurves.easeOutCubic),
        ),
      );
    });

    _loadExistingReflection();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _customTextController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingReflection() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final existing =
          await db.reflectionDao.getReflectionForDate(widget.targetDate);

      if (mounted && existing != null) {
        _hasExistingReflection = true;
        try {
          final keys =
              (jsonDecode(existing.reasonKeys) as List).cast<String>();
          _selectedKeys.addAll(keys.take(2));
        } catch (_) {}

        if (existing.customText != null) {
          _customTextController.text = existing.customText!;
        }

        final resolved = resolveFollowUp(_selectedKeys);
        if (resolved != null &&
            existing.followUpReasonKey == resolved.triggerReasonKey) {
          _activeFollowUpReasonKey = existing.followUpReasonKey;
          _selectedFollowUpAnswer = existing.followUpAnswer;
        } else if (resolved != null) {
          _activeFollowUpReasonKey = resolved.triggerReasonKey;
          _selectedFollowUpAnswer = null;
        }
      }
    } catch (_) {
      // If load fails, sheet still functions cleanly in empty state
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _staggerController.forward();
      }
    }
  }

  void _onPebbleTapped(String reasonKey) {
    setState(() {
      if (_selectedKeys.contains(reasonKey)) {
        _selectedKeys.remove(reasonKey);
      } else {
        // Enforce max 2: choosing a 3rd drops oldest FIFO
        if (_selectedKeys.length >= 2) {
          _selectedKeys.removeAt(0);
        }
        _selectedKeys.add(reasonKey);
      }
      _syncFollowUp();
    });
  }

  void _removeKey(String key) {
    setState(() {
      _selectedKeys.remove(key);
      _syncFollowUp();
    });
  }

  void _syncFollowUp() {
    final resolved = resolveFollowUp(_selectedKeys);
    if (resolved == null) {
      _activeFollowUpReasonKey = null;
      _selectedFollowUpAnswer = null;
      return;
    }

    // Keep answer only if the trigger key remains unchanged
    if (resolved.triggerReasonKey == _activeFollowUpReasonKey) {
      // Keep _selectedFollowUpAnswer
    } else {
      _activeFollowUpReasonKey = resolved.triggerReasonKey;
      _selectedFollowUpAnswer = null;
    }
  }

  bool get _canContinue {
    return _selectedKeys.isNotEmpty ||
        _customTextController.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (_isSaving || !_canContinue) return;
    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final db = ref.read(appDatabaseProvider);
      final customText = _customTextController.text.trim();

      await db.reflectionDao.upsertReflection(
        reflectionDate: widget.targetDate,
        reasonKeys: _selectedKeys,
        customText: customText.isNotEmpty ? customText : null,
        followUpReasonKey:
            _selectedFollowUpAnswer != null ? _activeFollowUpReasonKey : null,
        followUpAnswer: _selectedFollowUpAnswer,
        missedHabitIds: widget.missedHabits.map((h) => h.habitId).toList(),
      );

      // Clear skipped registry on successful save
      await ReflectionGateService.clearDateSkipped(widget.targetDate);

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Noted. Tomorrow starts fresh.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not save reflection. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearReflection() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final db = ref.read(appDatabaseProvider);
      await db.reflectionDao.deleteReflectionForDate(widget.targetDate);

      if (mounted) {
        navigator.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Reflection cleared.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not clear reflection. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    final sheetHeight =
        (mediaQuery.size.height * 0.85).clamp(0.0, availableHeight);

    final today = ref.watch(currentDateProvider);
    final isTargetToday = widget.targetDate.isSameDay(today);

    final activeFollowUp = resolveFollowUp(_selectedKeys);
    final isClearing = _hasExistingReflection && !_canContinue;
    final isActionEnabled = _canContinue || isClearing;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
          // -------------------------------------------------------------------
          // ZONE 1: PINNED HEADER
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.md),
                // Drag handle
                Center(
                  child: Container(
                    width: AppSizes.bottomSheetHandleWidth,
                    height: AppSizes.bottomSheetHandleHeight,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ),
                // Top header actions: "Clear reflection" (if pre-existing) and "Not now"
                Row(
                  mainAxisAlignment: _hasExistingReflection
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.end,
                  children: [
                    if (_hasExistingReflection)
                      TextButton(
                        onPressed: _isSaving ? null : _clearReflection,
                        child: Text(
                          'Clear reflection',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Not now',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                // Centered Orb (progress = selectedCount / 2)
                ReflectionOrb(
                  progress: _selectedKeys.length / 2,
                  size: AppSizes.orbSize,
                ),
                const SizedBox(height: AppSpacing.md),
                // Title
                Text(
                  isTargetToday
                      ? 'What got in the way today?'
                      : 'What got in the way yesterday?',
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Subtitle
                Text(
                  'No judgment. Just noticing.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                // Optional context chips for missed habits
                if (widget.missedHabits.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'Left for another day: ',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        for (final habit in widget.missedHabits) ...[
                          Container(
                            margin: const EdgeInsets.only(right: AppSpacing.xs),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.chip,
                              border: Border.all(
                                color: AppColors.border,
                                width: AppSizes.divider,
                              ),
                            ),
                            child: Text(
                              habit.name,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                // Stones Strip
                StonesStrip(
                  selectedKeys: _selectedKeys,
                  onRemove: _removeKey,
                ),
              ],
            ),
          ),

          // -------------------------------------------------------------------
          // ZONE 2: SCROLLING MIDDLE
          // -------------------------------------------------------------------
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0;
                            i < kReflectionCategories.length;
                            i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.lg),
                          AnimatedBuilder(
                            animation: _staggerController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _cardFades[i].value,
                                child: Transform.translate(
                                  offset: Offset(0, _cardSlides[i].value),
                                  child: child,
                                ),
                              );
                            },
                            child: ReasonCategoryCard(
                              category: kReflectionCategories[i],
                              selectedKeys: _selectedKeys,
                              onPebbleTapped: _onPebbleTapped,
                              activeFollowUp: activeFollowUp,
                              selectedFollowUpAnswer: _selectedFollowUpAnswer,
                              onFollowUpAnswerChanged: (ans) {
                                setState(() => _selectedFollowUpAnswer = ans);
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        MyReasonCard(
                          controller: _customTextController,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
          ),

          // -------------------------------------------------------------------
          // ZONE 3: PINNED FOOTER
          // -------------------------------------------------------------------
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.border,
                    width: AppSizes.divider,
                  ),
                ),
              ),
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
                      onPressed: isActionEnabled && !_isSaving
                          ? (isClearing ? _clearReflection : _submit)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canContinue
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        foregroundColor: _canContinue
                            ? AppColors.textOnPrimary
                            : (isClearing
                                ? AppColors.error
                                : AppColors.textDisabled),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.button,
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: AppSizes.iconMd,
                              height: AppSizes.iconMd,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _canContinue
                                    ? AppColors.textOnPrimary
                                    : AppColors.error,
                              ),
                            )
                          : Text(
                              isClearing ? 'Clear reflection' : 'Continue',
                              style: context.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _canContinue
                                    ? AppColors.textOnPrimary
                                    : (isClearing
                                        ? AppColors.error
                                        : AppColors.textDisabled),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    "Tomorrow, we'll try again.",
                    style: context.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
