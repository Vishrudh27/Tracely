import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_icon_registry.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../core/widgets/tracely_shimmer.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/models/habit_models.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../widgets/habit_management_tile.dart';

/// Habits list sort order — the "tune" icon's menu. [manual] is the DB's
/// own `sortOrder` column (already the query's default ordering).
enum _HabitSort { manual, nameAsc, streakDesc, newest }

/// The Habits screen — manage your habits.
///
/// Shows all active habits with category filter chips.
/// FAB navigates to AddHabitScreen.
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _selectedCategoryId; // null = show all
  bool _showArchived = false;
  _HabitSort _sort = _HabitSort.manual;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.custom(800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    // Only computed when actually needed — it's a per-habit DB query loop,
    // not worth running on every build when sorting some other way.
    final breakdownsAsync = _sort == _HabitSort.streakDesc
        ? ref.watch(habitBreakdownsProvider)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            categoriesAsync.when(
              data: (cats) => _buildCategoryFilter(
                cats,
                habitsAsync.asData?.value ?? const [],
              ),
              loading: () => const SizedBox(height: AppSpacing.xl),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            Expanded(
              child: habitsAsync.when(
                loading: () => _buildLoadingState(),
                error: (err, stack) => _buildLoadingState(),
                data: (habits) {
                  final filtered = _showArchived
                      ? habits.where((h) => h.isArchived).toList()
                      : habits
                            .where((h) => !h.isArchived)
                            .where(
                              (h) =>
                                  _selectedCategoryId == null ||
                                  h.categoryId == _selectedCategoryId,
                            )
                            .toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }
                  final sorted = _applySort(
                    filtered,
                    breakdownsAsync?.asData?.value,
                  );
                  return _buildHabitList(
                    sorted,
                    categoriesAsync.asData?.value ?? [],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: AppSizes.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppStrings.habitsScreenTitle,
            style: context.textTheme.displaySmall,
          ),
          // Stitch's header shows this "tune" icon with no defined behavior —
          // wired to a sort menu (own addition, not from Stitch).
          PopupMenuButton<_HabitSort>(
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
            icon: const Icon(
              Icons.tune_rounded,
              size: AppSizes.iconLg,
              color: AppColors.textSecondary,
            ),
            itemBuilder: (context) => [
              _sortMenuItem(_HabitSort.manual, 'Default order'),
              _sortMenuItem(_HabitSort.nameAsc, 'Name (A–Z)'),
              _sortMenuItem(_HabitSort.streakDesc, 'Streak (high to low)'),
              _sortMenuItem(_HabitSort.newest, 'Recently added'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_HabitSort> _sortMenuItem(_HabitSort value, String label) {
    final selected = _sort == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            size: AppSizes.iconSm,
            color: selected ? AppColors.primary : AppColors.textDisabled,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: context.textTheme.bodyMedium),
        ],
      ),
    );
  }

  /// [breakdowns] is only non-null (and only needed) for [_HabitSort.streakDesc].
  List<Habit> _applySort(List<Habit> habits, List<HabitBreakdown>? breakdowns) {
    final sorted = [...habits];
    switch (_sort) {
      case _HabitSort.manual:
        break; // Already sortOrder-ascending, straight from the DB query.
      case _HabitSort.nameAsc:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _HabitSort.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _HabitSort.streakDesc:
        final streaks = {
          for (final b in breakdowns ?? const <HabitBreakdown>[])
            b.habitId: b.currentStreak,
        };
        sorted.sort(
          (a, b) => (streaks[b.id] ?? 0).compareTo(streaks[a.id] ?? 0),
        );
    }
    return sorted;
  }

  /// Pins "All" + the 3 categories with the most active habits as one-row
  /// chips; everything else (plus Archived, which was never a category to
  /// begin with) lives behind "More", opened in [_openMoreCategoriesSheet].
  /// One fixed-height row, always — never 2-3 pages of chips, never a
  /// crammed 9-across strip.
  static const _pinnedCount = 3;

  Widget _buildCategoryFilter(List<Category> categories, List<Habit> habits) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final counts = <int, int>{};
    for (final h in habits) {
      if (h.isArchived) continue;
      counts[h.categoryId] = (counts[h.categoryId] ?? 0) + 1;
    }
    final byUsage = [...categories]
      ..sort((a, b) {
        final byCount = (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0);
        return byCount != 0 ? byCount : a.sortOrder.compareTo(b.sortOrder);
      });
    final pinned = byUsage.take(_pinnedCount).toList();
    final pinnedIds = pinned.map((c) => c.id).toSet();
    final overflow = categories.where((c) => !pinnedIds.contains(c.id)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // "More" reads as selected whenever the active filter isn't visible in
    // this row — an overflow category or Archived — so the state is never
    // silently invisible.
    final isMoreSelected =
        _showArchived ||
        (_selectedCategoryId != null &&
            !pinnedIds.contains(_selectedCategoryId));

    // Chip shows what's actually picked, not a static "More" — otherwise
    // the active filter is invisible once its category scrolls out of the
    // pinned row.
    final moreLabel = _showArchived
        ? '${AppStrings.filterArchived} ▾'
        : isMoreSelected
            ? '${overflow.firstWhere((c) => c.id == _selectedCategoryId).name} ▾'
            : 'More ▾';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: AppSizes.chipHeight,
        child: Row(
          children: [
            Expanded(
              child: _CategoryChip(
                label: AppStrings.filterAll,
                isSelected: !_showArchived && _selectedCategoryId == null,
                onTap: () => setState(() {
                  _showArchived = false;
                  _selectedCategoryId = null;
                }),
              ),
            ),
            for (final cat in pinned) ...[
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _CategoryChip(
                  label: cat.name,
                  isSelected: !_showArchived && _selectedCategoryId == cat.id,
                  onTap: () => setState(() {
                    _showArchived = false;
                    _selectedCategoryId = cat.id;
                  }),
                ),
              ),
            ],
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _CategoryChip(
                label: moreLabel,
                isSelected: isMoreSelected,
                onTap: () => _openMoreCategoriesSheet(overflow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [overflow] excludes the 3 pinned categories; Archived is always
  /// appended since it was never part of `categories` to begin with.
  Future<void> _openMoreCategoriesSheet(List<Category> overflow) async {
    final picked = await showDialog<(bool isArchived, int? categoryId)>(
      context: context,
      // Near-transparent barrier — the BackdropFilter below does the actual
      // dimming via blur, so a solid barrier would double up on top of it.
      barrierColor: Colors.black.withValues(alpha: 0.1),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: AppRadius.dialog,
              boxShadow: AppShadows.lg,
            ),
            // ListTile needs a Material ancestor to paint/ink-respond — the
            // plain Container above only gives it a shadow, not that.
            child: ClipRRect(
              borderRadius: AppRadius.dialog,
              child: Material(
                color: AppColors.surface,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        for (final cat in overflow)
                          _MoreOptionRow(
                            icon: AppIconRegistry.resolve(cat.emoji),
                            iconColor: Color(cat.colorValue),
                            label: cat.name,
                            selected:
                                !_showArchived &&
                                _selectedCategoryId == cat.id,
                            onTap: () =>
                                Navigator.pop(context, (false, cat.id)),
                          ),
                        _MoreOptionRow(
                          icon: Icons.archive_outlined,
                          iconColor: AppColors.textSecondary,
                          label: AppStrings.filterArchived,
                          selected: _showArchived,
                          onTap: () => Navigator.pop(context, (true, null)),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _showArchived = picked.$1;
      _selectedCategoryId = picked.$1 ? null : picked.$2;
    });
  }

  Widget _buildHabitList(List<Habit> habits, List<Category> categories) {
    final catMap = {for (final c in categories) c.id: c};
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 96),
      itemCount: habits.length,
      itemBuilder: (context, i) {
        final habit = habits[i];
        final cat = catMap[habit.categoryId];
        return HabitManagementTile(
          habit: habit,
          category: cat,
          onTap: () => context.push('/habits/detail/${habit.id}'),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return TracelyEmptyState(
      icon: Icons.add_circle_outline_rounded,
      title: AppStrings.emptyHabitsTitle,
      body: AppStrings.emptyHabitsBody,
      ctaLabel: AppStrings.emptyHabitsCta,
      onCta: () => context.push(AppRouter.addHabit),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: 4,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: TracelyShimmer(
          width: double.infinity,
          height: AppSizes.cardMinHeight,
          borderRadius: AppRadius.card,
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: () => context.push(AppRouter.addHabit),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnPrimary,
      elevation: 2,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: AppSizes.iconLg),
    );
  }
}

/// One row in the "More categories" dialog — same InkWell+Row+bodyLarge
/// structure as Settings' `_SettingsRow`, not a ListTile, so the label
/// renders with the identical font/weight instead of ListTile's own
/// title-text defaults.
class _MoreOptionRow extends StatelessWidget {
  const _MoreOptionRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category filter chip.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
        height: AppSizes.chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: AppRadius.small,
        ),
        // Equal-width slots get tight with 7+ categories — shrink the text
        // to fit rather than clip it with an ellipsis.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: context.textTheme.titleSmall?.copyWith(
              color: isSelected
                  ? AppColors.textOnPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
