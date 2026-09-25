import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/reflection_gate_service.dart';
import '../../features/analytics/presentation/screens/statistics_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/habits/presentation/screens/add_habit_screen.dart';
import '../../features/habits/presentation/screens/edit_habit_screen.dart';
import '../../features/habits/presentation/screens/habit_detail_screen.dart';
import '../../features/habits/presentation/screens/habits_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/reflection/presentation/screens/reflection_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/tasks/presentation/screens/add_task_screen.dart';
import '../../features/tasks/presentation/screens/tasks_screen.dart';
import '../../data/services/onboarding_gate_service.dart';
import '../shell/tracely_shell.dart';

/// Central GoRouter configuration for Tracely.
///
/// Route hierarchy:
/// /splash          → SplashScreen     (no bottom nav) — every cold start
/// /                → ReflectionScreen (no bottom nav) — morning only, once/day
/// /onboarding      → OnboardingScreen (no bottom nav) — first launch only, once ever
/// /dashboard       → DashboardScreen  (inside TracelyShell)
/// /habits          → HabitsScreen     (inside TracelyShell)
/// /habits/add      → AddHabitScreen   (full screen, no shell)
/// /habits/edit/:id → EditHabitScreen  (full screen, no shell)
/// /tasks           → TasksScreen      (inside TracelyShell)
/// /tasks/add       → AddTaskScreen    (full screen, no shell)
/// /statistics      → StatisticsScreen (inside TracelyShell)
final class AppRouter {
  AppRouter._();

  // ---------------------------------------------------------------------------
  // Route path constants
  // ---------------------------------------------------------------------------

  static const String splash = '/splash';
  static const String reflection = '/';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String habits = '/habits';
  static const String addHabit = '/habits/add';
  static const String editHabit = '/habits/edit/:id';
  static const String habitDetail = '/habits/detail/:id';
  static const String settings = '/settings';
  static const String tasks = '/tasks';
  static const String addTask = '/tasks/add';
  static const String statistics = '/statistics';

  // ---------------------------------------------------------------------------
  // Router
  // ---------------------------------------------------------------------------

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      // Splash — the app's first frame. Decides nothing; it hands off to
      // '/', whose redirect owns the onboarding and ritual gates.
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Reflection screen — outside the shell (no bottom navigation).
      // The redirect enforces the morning gate: only shown before noon,
      // and only once per calendar day. All other opens go to /dashboard.
      GoRoute(
        path: reflection,
        redirect: (context, state) async {
          final onboarded = await OnboardingGateService.hasCompletedOnboarding();
          if (!onboarded) return onboarding;
          final show = await ReflectionGateService.shouldShowReflection();
          return show ? null : dashboard;
        },
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ReflectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 280),
        ),
      ),

      // Onboarding — outside the shell, shown once on first launch ever.
      GoRoute(
        path: onboarding,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
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

      // Habit Detail — full screen outside the shell
      GoRoute(
        path: habitDetail,
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return CustomTransitionPage(
            key: state.pageKey,
            child: HabitDetailScreen(habitId: id),
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

      // Settings — full screen outside the shell. No Stitch mockup shows an
      // entry point to it (no avatar/bell header anywhere, no 5th nav tab),
      // so this route is currently unreachable from the UI. Left as-is per
      // the user's own call — see tracely_implementation_progress.md.
      GoRoute(
        path: settings,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
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

      // Add Task — full screen outside the shell
      GoRoute(
        path: addTask,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AddTaskScreen(),
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

      // Shell route wraps Dashboard, Habits, Tasks, Statistics with bottom nav
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
            path: tasks,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const TasksScreen(),
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
