import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/theme/theme.dart';
import '../../core/constants/app_strings.dart';

/// Shell scaffold providing the bottom navigation bar for the three main tabs.
///
/// Wraps Dashboard, Habits, and Statistics. The Reflection screen is OUTSIDE
/// this shell — it has its own full-screen route with no navigation bar.
///
/// Tab switching uses a FadeTransition (via AnimatedSwitcher) — never a slide,
/// which would feel too utilitarian for Tracely's calm aesthetic.
class TracelyShell extends StatefulWidget {
  const TracelyShell({super.key, required this.child});

  final Widget child;

  @override
  State<TracelyShell> createState() => _TracelyShellState();
}

class _TracelyShellState extends State<TracelyShell> {
  int _currentIndex = 0;

  static const List<String> _routes = [
    AppRouter.dashboard,
    AppRouter.habits,
    AppRouter.statistics,
  ];

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  /// Derive the current index from the active route.
  int _indexFromRoute(String location) {
    if (location.startsWith(AppRouter.habits)) return 1;
    if (location.startsWith(AppRouter.statistics)) return 2;
    return 0; // default: dashboard
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final activeIndex = _indexFromRoute(location);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedSwitcher(
        duration: AppDurations.navigation,
        switchInCurve: AppCurves.navigation,
        switchOutCurve: AppCurves.emphasizedAccelerate,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: KeyedSubtree(
          key: ValueKey(activeIndex),
          child: widget.child,
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top divider — subtle separation without elevation shadow
          Container(
            height: AppSizes.divider,
            color: AppColors.border,
          ),
          NavigationBar(
            height: AppSizes.bottomNavigationHeight,
            backgroundColor: AppColors.surface,
            elevation: 0,
            shadowColor: Colors.transparent,
            indicatorColor: AppColors.primary.withValues(alpha: 0.12),
            selectedIndex: activeIndex,
            onDestinationSelected: _onNavTap,
            labelBehavior:
                NavigationDestinationLabelBehavior.alwaysShow,
            animationDuration: AppDurations.navigation,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.home_outlined,
                  color: AppColors.textDisabled,
                  size: AppSizes.iconLg,
                ),
                selectedIcon: Icon(
                  Icons.home_rounded,
                  color: AppColors.primary,
                  size: AppSizes.iconLg,
                ),
                label: AppStrings.navDashboard,
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.textDisabled,
                  size: AppSizes.iconLg,
                ),
                selectedIcon: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: AppSizes.iconLg,
                ),
                label: AppStrings.navHabits,
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.bar_chart_outlined,
                  color: AppColors.textDisabled,
                  size: AppSizes.iconLg,
                ),
                selectedIcon: Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                  size: AppSizes.iconLg,
                ),
                label: AppStrings.navStatistics,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
