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
    return Container(
      height: AppSizes.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(AppStrings.habitsScreenTitle, style: context.textTheme.displaySmall),
          // Stitch's header shows this "tune" icon with no defined behavior
          // — kept visible, inert, so it doesn't duplicate the Archived chip.
          SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              Icons.tune_rounded,
              size: AppSizes.iconLg,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(List<Category> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();

    // +1 for "All", +1 for "Archived"
    final itemCount = categories.length + 2;

    return SizedBox(
      height: AppSizes.chipHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _CategoryChip(
              label: AppStrings.filterAll,
              isSelected: !_showArchived && _selectedCategoryId == null,
              onTap: () => setState(() {
                _showArchived = false;
                _selectedCategoryId = null;
              }),
            );
          }
          if (i == itemCount - 1) {
            return _CategoryChip(
              label: AppStrings.filterArchived,
              isSelected: _showArchived,
              onTap: () => setState(() => _showArchived = true),
            );
          }
          final cat = categories[i - 1];
          return _CategoryChip(
            label: cat.name,
            isSelected: !_showArchived && _selectedCategoryId == cat.id,
            onTap: () => setState(() {
              _showArchived = false;
              _selectedCategoryId = cat.id;
            }),
          );
        },
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: AppRadius.small,
        ),
        child: Text(
          label,
          style: context.textTheme.titleSmall?.copyWith(
            color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
