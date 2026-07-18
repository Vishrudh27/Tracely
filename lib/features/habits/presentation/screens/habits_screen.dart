import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/tracely_empty_state.dart';
import '../../../../core/widgets/tracely_shimmer.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../widgets/habit_management_tile.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            categoriesAsync.when(
              data: (cats) => _buildCategoryFilter(cats),
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
                          .where((h) =>
                              _selectedCategoryId == null ||
                              h.categoryId == _selectedCategoryId)
                          .toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildHabitList(filtered, categoriesAsync.asData?.value ?? []);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppStrings.habitsScreenTitle,
            style: context.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          // Archive toggle
          GestureDetector(
            onTap: () => setState(() => _showArchived = !_showArchived),
            child: Container(
              padding: AppSpacing.chip,
              decoration: BoxDecoration(
                color: _showArchived
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppColors.surfaceVariant,
                borderRadius: AppRadius.chip,
                border: Border.all(
                  color: _showArchived ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                _showArchived ? AppStrings.filterArchived : AppStrings.filterActive,
                style: context.textTheme.labelSmall?.copyWith(
                  color: _showArchived ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(List<Category> categories) {
    if (categories.isEmpty || _showArchived) return const SizedBox.shrink();

    return SizedBox(
      height: AppSizes.chipHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1, // +1 for "All"
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _CategoryChip(
              label: AppStrings.filterAll,
              emoji: null,
              isSelected: _selectedCategoryId == null,
              onTap: () => setState(() => _selectedCategoryId = null),
            );
          }
          final cat = categories[i - 1];
          return _CategoryChip(
            label: cat.name,
            emoji: cat.emoji,
            isSelected: _selectedCategoryId == cat.id,
            onTap: () => setState(() => _selectedCategoryId = cat.id),
          );
        },
      ),
    );
  }

  Widget _buildHabitList(List<Habit> habits, List<Category> categories) {
    final catMap = {for (final c in categories) c.id: c};
    return ListView.builder(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.massive,
      ),
      itemCount: habits.length,
      itemBuilder: (context, i) {
        final habit = habits[i];
        final cat = catMap[habit.categoryId];
        return HabitManagementTile(
          habit: habit,
          category: cat,
          onTap: () => context.push('/habits/edit/${habit.id}'),
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

/// Category filter chip.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.emoji,
  });

  final String label;
  final String? emoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: AppSpacing.chip,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: AppRadius.chip,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: AppSpacing.xxs),
            ],
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
