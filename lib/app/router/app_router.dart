import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/analytics/presentation/screens/statistics_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/habits/presentation/screens/add_habit_screen.dart';
import '../../features/habits/presentation/screens/edit_habit_screen.dart';
import '../../features/habits/presentation/screens/habits_screen.dart';
import '../../features/reflection/presentation/screens/reflection_screen.dart';
import '../shell/tracely_shell.dart';

/// Central GoRouter configuration for Tracely.
///
/// Route hierarchy:
/// /                → ReflectionScreen (no bottom nav)
/// /dashboard       → DashboardScreen  (inside TracelyShell)
/// /habits          → HabitsScreen     (inside TracelyShell)
/// /habits/add      → AddHabitScreen   (full screen, no shell)
/// /habits/edit/:id → EditHabitScreen  (full screen, no shell)
/// /statistics      → StatisticsScreen (inside TracelyShell)
final class AppRouter {
  AppRouter._();

  // ---------------------------------------------------------------------------
  // Route path constants
  // ---------------------------------------------------------------------------

  static const String reflection = '/';
  static const String dashboard = '/dashboard';
  static const String habits = '/habits';
  static const String addHabit = '/habits/add';
  static const String editHabit = '/habits/edit/:id';
  static const String statistics = '/statistics';

  // ---------------------------------------------------------------------------
  // Router
  // ---------------------------------------------------------------------------

  static final GoRouter router = GoRouter(
    initialLocation: reflection,
    routes: [
      // Reflection screen — outside the shell (no bottom navigation)
      GoRoute(
        path: reflection,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ReflectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 280),
        ),
      ),

      // Add Habit — full screen outside the shell
      GoRoute(
        path: addHabit,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AddHabitScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 320),
        ),
      ),

      // Edit Habit — full screen outside the shell
      GoRoute(
        path: editHabit,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return CustomTransitionPage(
            key: state.pageKey,
            child: EditHabitScreen(habitId: id),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 320),
          );
        },
      ),

      // Shell route wraps Dashboard, Habits, Statistics with bottom nav
      ShellRoute(
        pageBuilder: (context, state, child) => CustomTransitionPage(
          key: state.pageKey,
          child: TracelyShell(child: child),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 280),
        ),
        routes: [
          GoRoute(
            path: dashboard,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DashboardScreen(),
            ),
          ),
          GoRoute(
            path: habits,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HabitsScreen(),
            ),
          ),
          GoRoute(
            path: statistics,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const StatisticsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
