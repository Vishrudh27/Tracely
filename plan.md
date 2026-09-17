# Tracely — Master Build Plan

**Tagline:** "Build habits. Build yourself."

> This document is the single source of truth for building Tracely from Phase 2 onward.  
> It is fully self-contained. The coding agent reading this has zero prior context beyond this file.  
> Every decision, every widget name, every animation Interval, every database table is specified here.

---

## Table of Contents

1. [Project Summary & Philosophy](#1-project-summary--philosophy)
   - 1.1 [The Why Philosophy](#11-the-why-philosophy)
2. [Golden Rules for the Agent](#2-golden-rules-for-the-agent)
3. [Architecture Continuation Plan](#3-architecture-continuation-plan)
4. [Screen-by-Screen Build Specs](#4-screen-by-screen-build-specs)
   - 4.1 [Dashboard Screen](#41-dashboard-screen)
   - 4.2 [Habits Screen](#42-habits-screen)
   - 4.3 [Statistics Screen](#43-statistics-screen)
   - 4.4 [Shell & Navigation](#44-shell--navigation)
   - 4.5 [Pause & Reflect (Missed Habit Reflection)](#45-pause--reflect-missed-habit-reflection)
5. [Animation System Specification](#5-animation-system-specification)
   - 5.0 [Motion Philosophy](#50-motion-philosophy)
   - 5.1 [The Parent-Controller + Interval Pattern](#51-the-parent-controller--interval-pattern)
   - 5.2 [Existing Reflection Screen Intervals (Reference)](#52-existing-reflection-screen-intervals-reference)
   - 5.3 [Dashboard Entrance Animation](#53-dashboard-entrance-animation)
   - 5.4 [Habit Completion Micro-Interaction](#54-habit-completion-micro-interaction)
   - 5.5 [Statistics Screen Entrance Animation](#55-statistics-screen-entrance-animation)
   - 5.6 [Page Transition Between Reflection → Dashboard](#56-page-transition-between-reflection--dashboard)
   - 5.7 [Bottom Navigation Tab Switching](#57-bottom-navigation-tab-switching)
6. [Innovative Ideas Section](#6-innovative-ideas-section)
7. [Theming Extension Notes](#7-theming-extension-notes)
8. [Data Model Draft (Drift Schema)](#8-data-model-draft-drift-schema)
9. [Definition of Done per Phase](#9-definition-of-done-per-phase)
10. [Explicit Non-Goals](#10-explicit-non-goals)

---

## 1. Project Summary & Philosophy

### What Tracely Is

Tracely is an offline-first habit tracker built in Flutter that prioritizes **reflection, emotional connection, and calm consistency** over statistics and productivity pressure. It is a daily companion, not a scorecard.

### Core Question Every Feature Must Pass

> "Will this make the user genuinely enjoy opening Tracely tomorrow?"

If the answer is no — or even "maybe" — the feature does not belong.

### 1.1 The Why Philosophy

Every habit tracker on the App Store can tell you **what** happened. You completed 4 of 6 habits. Your streak is 12 days. Your Wednesday consistency is 73%. Numbers. Charts. Percentages. None of them tell you **why**.

Tracely's actual differentiator — the thing that separates it from every other app in this category — is that it tries to understand **why consistency happens or breaks down**. Statistics are the map; reflection is the compass. The map shows where you've been. The compass tells you where to go and, more importantly, what keeps pulling you off course.

When a user misses a habit, Tracely never says "You failed." It asks "What got in the way?" There is no judgment — only understanding. A user who missed three habits because they were sick is having a fundamentally different experience from a user who missed three habits because they're burned out. The numbers are identical. The response should not be.

This is the philosophical layer that governs every feature in this document. The Dashboard answers what happened today. The Statistics screen answers what happened over time. The Pause & Reflect flow (§4.5) answers why it happened. Together, they form a complete picture — not just of behavior, but of the human behind the behavior.

**Long-term vision** (explicitly future, not current scope): Tracely will eventually understand energy patterns, mood trends, environmental factors, distractions, sleep quality, and motivation cycles — not to score the user, not to generate a "wellness grade," but to help them recognize their own patterns. "You tend to skip workouts on days after poor sleep" is infinitely more useful than "You completed 71% of workouts this month." That intelligence layer is where Tracely is headed. The schema and data collection in this plan are designed to support it when the time comes.

**The governing rule:** Every feature must answer two questions: **(1) Does this improve consistency? (2) Does this improve emotional connection?** If neither — don't build it. (See Golden Rule #31 in §2.)

### Emotional Design Pillars

| Pillar | Meaning |
|--------|---------|
| **Calm** | No urgency, no red badges, no guilt. Missed a day? That's okay. |
| **Premium** | Every animation intentional. Every pixel considered. No Flutter "demo app" feel. |
| **Smooth** | Buttery 60fps transitions. No jank, no sudden movements, no layout jumps. |
| **Intentional** | Every element on screen has a clear purpose. No visual clutter. |
| **Beautiful** | Stone & Sand palette — warm, natural, professional. Soft backgrounds, gentle shadows. |
| **Personal** | The app talks *to* you, not *at* you. Positive framing always. |

### What Tracely Is NOT

- Not a productivity tool with KPIs and dashboards full of numbers.
- Not a gamification engine with points, badges, or leaderboards.
- Not a social platform — no sharing, no comparison.
- Not an app that punishes missed habits with red indicators, broken streaks, or guilt-inducing copy.

### Design Inspiration

Headspace (calm onboarding), Calm (breathing space), Apple Health (clean data), Notion (minimal power), Claude mobile app (buttery transitions, premium feel).

### User Journey

```
App Opens → Daily Opening Ritual → Dashboard → Daily Habits → Statistics → Daily Opening Ritual again tomorrow
```

The app **intentionally begins with the Daily Opening Ritual** (the Reflection screen), not productivity. The app deliberately delays productivity for approximately 2.5 seconds. This is not a loading screen and not a splash screen — it is a designed emotional reset. The sequence — stillness, then a warm welcome, then a quote to sit with, then the invitation to continue — teaches consistency and calm *before* asking for productivity. The user should take a breath before they start checking things off. This sequence is intentional and must never be shortened or bypassed for "efficiency" in future iterations. The route stays `/` and the feature folder stays `reflection/`.

---

## 2. Golden Rules for the Agent

These rules are **non-negotiable**. Violating any of them means the code must be rewritten.

### Architecture Rules

1. **Feature-first folder structure** — Every new feature goes inside `lib/features/<feature_name>/` with subdirectories for `presentation/screens/`, `presentation/widgets/`, `data/models/`, `data/repositories/`, and `domain/` as needed. Mirror the existing `reflection/` structure exactly.
2. **Riverpod for all state** — No `setState` for business logic. `setState` is only acceptable for local animation state within a `StatefulWidget` that owns an `AnimationController`. All data flows through Riverpod providers.
3. **go_router for all navigation** — No `Navigator.push`. All routes defined centrally in `lib/app/router/app_router.dart`. Use named routes.
4. **Drift for all persistent data** — No raw SQLite, no `sqflite`. Everything goes through Drift tables and DAOs.
5. **Offline-first, always** — Every feature must work with zero network connectivity. Internet is never required. Do not add any `http` calls in Phase 2 or Phase 3.

### Theming Rules

6. **Never hardcode colors** — Always use `AppColors.*`. No `Color(0xFF...)` or `Colors.blue` in any widget file.
7. **Never hardcode spacing** — Always use `AppSpacing.*`. No raw `16.0` or `SizedBox(height: 8)` with literal values.
8. **Never hardcode radii** — Always use `AppRadius.*`.
9. **Never hardcode durations** — Always use `AppDurations.*`.
10. **Never hardcode curves** — Always use `AppCurves.*`.
11. **Never hardcode text styles** — Always use `AppTypography.textTheme.*` or `Theme.of(context).textTheme.*`.
12. **Never hardcode shadows** — Always use `AppShadows.*`.
13. **Never hardcode sizes** — Always use `AppSizes.*` for heights, widths, and icon sizes.

### Animation Rules

14. **Single AnimationController per screen** — Each screen that has entrance animations owns exactly one `AnimationController`. Child widgets receive the controller and define their own `Interval` within the 0.0–1.0 timeline. This is the pattern used in `ReflectionScreen` — replicate it everywhere.
15. **No independent AnimationControllers per widget** — Unless the widget has its own independent micro-interaction (e.g., a checkbox tap animation). In that case, the widget owns a **separate, short** controller for that specific interaction only.
16. **Use `CurvedAnimation` + `Interval`** — Not `Tween.animate()` with raw controllers. Always wrap in `CurvedAnimation` with a named `Interval`.
17. **Stagger, don't slam** — Elements should enter sequentially with overlapping intervals, not all at once. Minimum 50ms stagger between adjacent elements.
18. **Use `AnimatedBuilder`** — Not `addListener` + `setState`. The reflection widgets already use `AnimatedBuilder` — continue this pattern.

### Widget Rules

19. **Small, single-responsibility widgets** — No widget file over ~150 lines. If it's getting longer, decompose. The `ReflectionScreen` decomposition into `AnimatedGreeting`, `AnimatedQuoteCard`, `AnimatedContinueButton`, `ReflectionBackground` is the reference pattern.
20. **Meaningful names** — `DashboardGreetingCard`, not `Card1`. `HabitCompletionCheckbox`, not `MyCheckbox`.
21. **No magic strings** — Motivational quotes, greeting text, section labels — all should be in constants files or provider-driven, not inline strings scattered across widgets.

### Emotional Design Rules

22. **Never use red for "missed" or "failed"** — Missed habits get `AppColors.textDisabled` or `AppColors.surfaceVariant`. They fade into the background, they don't scream.
23. **No hard delete** — Habits are archived, never destroyed. Users should never feel like they lost something.
24. **No punishment language** — Never say "You missed 4 habits." Say "You completed 3 habits this week — nice consistency!" Always frame positively.
25. **No pressure mechanics** — No daily login rewards, no "you'll lose your streak!" warnings. Streaks exist but are celebrated when maintained, not weaponized when broken.
26. **Encourage on empty states** — An empty dashboard doesn't say "No habits yet." It says "Ready when you are — add your first habit and start building."

### Code Quality Rules

27. **Barrel exports per feature** — Each feature directory should have an `index.dart` or barrel file exporting public API.
28. **Document non-obvious decisions** — Use `///` doc comments on classes and public methods explaining *why*, not just *what*.
29. **No `print()` calls** — Use the `logger` package already in pubspec for any debug output.
30. **Keep imports organized** — Dart imports, package imports, project imports — separated by blank lines, alphabetically sorted within each group.

### Philosophy Rule

31. **The Why Philosophy gate** — Every feature must answer two questions: **(1) Does this improve consistency? (2) Does this improve emotional connection?** If neither — don't build it. This is the architectural expression of the Why Philosophy (§1.1). A feature that surfaces interesting data but doesn't help the user understand their patterns or feel emotionally supported by the app has no place in Tracely.

---

## 3. Architecture Continuation Plan

### Existing Structure (Phase 1 — DO NOT MODIFY)

```
lib/
├── main.dart                          # Entry point — ProviderScope wraps TracelyApp
├── app/
│   ├── app.dart                       # TracelyApp — MaterialApp.router
│   ├── config/
│   │   └── app_config.dart            # App name, version constants
│   ├── design_system/                 # Reusable design system components
│   │   ├── app_bar/
│   │   ├── bottom_sheets/
│   │   ├── buttons/
│   │   ├── cards/
│   │   ├── chips/
│   │   ├── dialogs/
│   │   ├── navigation/
│   │   └── text_fields/
│   ├── router/
│   │   └── app_router.dart            # GoRouter config — currently only '/' → ReflectionScreen
│   └── theme/
│       ├── theme.dart                 # Barrel export for all tokens
│       ├── app_colors.dart            # Stone & Sand palette
│       ├── app_curves.dart            # Animation curves
│       ├── app_durations.dart         # Animation durations
│       ├── app_radius.dart            # Border radius tokens
│       ├── app_shadows.dart           # BoxShadow presets
│       ├── app_sizes.dart             # Component size tokens
│       ├── app_spacing.dart           # Spacing tokens
│       ├── app_theme.dart             # ThemeData construction
│       └── app_typography.dart        # TextTheme (Inter via Google Fonts)
├── core/
│   ├── constants/                     # (empty — to be populated)
│   ├── errors/                        # (empty — to be populated)
│   ├── extensions/                    # (empty — to be populated)
│   ├── utils/                         # (empty — to be populated)
│   └── widgets/                       # (empty — to be populated)
├── data/
│   ├── database/                      # (empty — Drift DB to be created here)
│   ├── repositories/                  # (empty — to be populated)
│   └── services/                      # (empty — to be populated)
└── features/
    ├── reflection/
    │   └── presentation/
    │       ├── screens/
    │       │   └── reflection_screen.dart
    │       └── widgets/
    │           ├── animated_greeting.dart
    │           ├── animated_quote_card.dart
    │           ├── animated_continue_button.dart
    │           └── reflection_background.dart
    ├── dashboard/                     # (empty — Phase 2)
    ├── habits/                        # (empty — Phase 2)
    ├── analytics/                     # (empty — Phase 3, was "statistics" in spec)
    ├── onboarding/                    # (has presentation/ skeleton)
    ├── settings/                      # (empty — Phase 5)
    └── tasks/                         # (empty — future)
```

### New Structure to Build (Phase 2 & Phase 3)

Every new feature follows this internal structure:

```
features/<feature_name>/
├── data/
│   ├── models/              # Drift table classes & data classes
│   ├── repositories/        # Repository implementations (Drift queries)
│   └── providers.dart       # Riverpod providers for data layer
├── domain/
│   ├── entities/            # Pure Dart domain objects (if different from DB models)
│   └── enums/               # Feature-specific enums
├── presentation/
│   ├── screens/             # Full-screen widgets (one per route)
│   ├── widgets/             # Decomposed UI components
│   ├── controllers/         # Riverpod StateNotifier / AsyncNotifier if needed
│   └── providers.dart       # Riverpod providers for presentation layer
└── index.dart               # Barrel export
```

### Shared Data Layer (lib/data/)

```
data/
├── database/
│   ├── app_database.dart         # The single Drift @DriftDatabase class
│   ├── app_database.g.dart       # Generated
│   ├── tables/                   # All Drift table definitions
│   │   ├── habits_table.dart
│   │   ├── habit_completions_table.dart
│   │   ├── categories_table.dart
│   │   ├── daily_reflections_table.dart
│   │   └── habit_reflections_table.dart
│   └── daos/                     # Drift DAOs grouped by domain
│       ├── habit_dao.dart
│       ├── completion_dao.dart
│       ├── category_dao.dart
│       └── reflection_dao.dart
├── repositories/
│   ├── habit_repository.dart
│   ├── completion_repository.dart
│   ├── category_repository.dart
│   └── reflection_repository.dart
└── services/
    └── database_service.dart     # Provider that initializes the DB singleton
```

### Shared Core Layer (lib/core/)

```
core/
├── constants/
│   ├── app_strings.dart          # All user-facing strings (greeting templates, empty states, etc.)
│   ├── quote_constants.dart      # Pool of motivational quotes
│   └── habit_constants.dart      # Default habit suggestions, category presets
├── errors/
│   └── app_exceptions.dart       # Custom exception classes
├── extensions/
│   ├── date_extensions.dart      # DateTime helpers (isToday, startOfWeek, etc.)
│   ├── string_extensions.dart    # Capitalize, truncate, etc.
│   └── context_extensions.dart   # BuildContext shortcuts for theme access
├── utils/
│   ├── date_utils.dart           # Date calculation helpers
│   ├── greeting_utils.dart       # Time-based greeting logic (extract from AnimatedGreeting)
│   └── streak_calculator.dart    # Streak computation logic (pure Dart, testable)
└── widgets/
    ├── tracely_card.dart          # Standard card with AppRadius, AppShadows, AppSpacing
    ├── tracely_empty_state.dart   # Reusable empty state with icon + message + optional CTA
    ├── tracely_shimmer.dart       # Shimmer loading placeholder
    ├── section_header.dart        # Section title + optional trailing action
    └── animated_list_item.dart    # Reusable staggered-entry list item wrapper
```

### Router Extension

`lib/app/router/app_router.dart` must be extended with these routes:

```dart
// Route paths
static const String reflection = '/';
static const String dashboard  = '/dashboard';
static const String habits     = '/habits';
static const String addHabit   = '/habits/add';
static const String editHabit  = '/habits/edit/:id';
static const String statistics = '/statistics';
static const String settings   = '/settings';

// Shell route for bottom navigation (Dashboard, Habits, Statistics)
// The bottom navigation bar wraps these three tabs.
// Reflection is OUTSIDE the shell — it's the entry point, no bottom nav.
```

Use a `ShellRoute` with a `ScaffoldWithNavBar` widget to hold the bottom navigation. The three tabs are: **Dashboard** (home icon), **Habits** (check-circle icon), **Statistics** (bar-chart icon). The navigation bar itself should use `AppColors`, `AppRadius.navigation`, `AppSizes.bottomNavigationHeight`, and `AppDurations.navigation`.

### Provider Architecture

All Riverpod providers follow this pattern:

```dart
// Database provider (singleton)
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// DAO providers
final habitDaoProvider = Provider<HabitDao>((ref) {
  return ref.watch(appDatabaseProvider).habitDao;
});

// Repository providers
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(ref.watch(habitDaoProvider));
});

// Data providers (async, reactive)
final todaysHabitsProvider = StreamProvider<List<HabitWithCompletion>>((ref) {
  return ref.watch(habitRepositoryProvider).watchTodaysHabits();
});
```

Use `StreamProvider` for any data that should react to database changes (Drift's `watch*` methods return `Stream`s). Use `FutureProvider` only for one-shot reads.

---

## 4. Screen-by-Screen Build Specs

### 4.1 Dashboard Screen

**Purpose:** The daily companion. The Dashboard exists to answer exactly three questions: **"What should I do today?"**, **"How am I doing?"**, and **"What should I focus on next?"** — everything else on this screen is secondary to these three.

**Route:** `/dashboard`

**Emotional Tone:** Warm, encouraging, grounding. Like opening a journal, not a task manager.

**Layout (top to bottom, scrollable Column inside SingleChildScrollView):**

| # | Widget Name | Description |
|---|-------------|-------------|
| 1 | `DashboardGreetingSection` | Time-based greeting ("Good Morning") + today's date. Reuses greeting logic from reflection but simpler — no animation controller, just a static warm welcome. Uses `AppTypography.textTheme.headlineMedium`. |
| 2 | `DailyProgressCard` | A single card showing today's completion as a circular progress indicator. "3 of 5 complete" with a warm ring around a centered fraction. Ring color: `AppColors.primary` for filled, `AppColors.border` for unfilled. Animation: ring fills on screen entrance. |
| 3 | `TodaysHabitsSection` | Section header "Today's Habits" + a list of `HabitTile` widgets. Each tile shows: habit icon (emoji or category icon), habit name, optional note, and a completion checkbox on the right. Tapping the checkbox triggers the completion micro-interaction (see §5). |
| 4 | `WeeklyHeatmapPreview` | A compact 7-day heatmap strip (Mon–Sun) showing completion intensity for the current week. Each cell is a small rounded square colored from `AppColors.heatmap[0]` (empty) to `AppColors.heatmap[4]` (full). Tapping navigates to full Statistics. |
| 5 | `RecentActivitySection` | "Recent Activity" header + last 3 completions as small, minimal cards: "[habit name] completed [relative time]". Uses `AppTypography.textTheme.bodySmall`. |
| 6 | `DashboardMotivationFooter` | A subtle motivational one-liner at the bottom of the scroll, rotated daily. Styled in `AppColors.textDisabled`, italic, small. Not a card — just floating text with generous top margin. Breathing room. |

**Data Requirements (from Drift):**

- `watchTodaysHabits()` → `Stream<List<HabitWithCompletion>>` — all active habits with today's completion status.
- `watchTodaysProgress()` → `Stream<DailyProgress>` — completed count, total count, percentage.
- `watchWeeklyHeatmapData()` → `Stream<List<DayCompletion>>` — 7 entries for current week.
- `watchRecentCompletions(limit: 3)` → `Stream<List<CompletionWithHabit>>` — most recent completions.

**States:**

| State | Behavior |
|-------|----------|
| **Loading** | Show `TracelyShimmer` placeholders matching the layout shapes. No spinners. |
| **Empty (no habits created)** | Show `TracelyEmptyState` with a warm illustration-placeholder area, text: "Ready when you are — add your first habit and start building." and a primary CTA button: "Add First Habit" → navigates to `/habits/add`. |
| **Loaded (habits exist, none completed today)** | Show all sections normally. Progress ring at 0%. Habit tiles all unchecked. Copy in progress card: "A fresh start — take it one at a time." |
| **Loaded (some completed)** | Progress ring partially filled. Completed habits show a subtle checkmark with a soft glow. Uncompleted habits remain neutral — never red or warning-colored. |
| **Loaded (all completed)** | Progress ring fully filled with a gentle pulse animation. Copy changes to: "All done — beautifully consistent." The ring glows softly with `AppColors.primaryLight`. |

---

### 4.2 Habits Screen

**Purpose:** Manage your habits. Add, edit, reorder, archive. This is the "settings" for your daily routine, not a daily-use screen.

**Route:** `/habits`

**Emotional Tone:** Organized but not sterile. Like arranging items on a beautiful shelf.

**Layout:**

| # | Widget Name | Description |
|---|-------------|-------------|
| 1 | `HabitsScreenAppBar` | Custom app bar with title "Your Habits" and an optional filter chip row (All / Active / Archived). Clean, no heavy toolbar. |
| 2 | `HabitCategoryFilter` | Horizontal scrollable chip row to filter by category. "All" chip is selected by default. Each chip shows category emoji + name. Uses `AppRadius.chip`, `AppSpacing.chip`. |
| 3 | `HabitListView` | Animated list of `HabitManagementTile` widgets. Each tile shows: category color dot, emoji, habit name, frequency label ("Daily", "Weekdays", "3x/week"), and a trailing chevron for edit. Long-press to reorder (with haptic if available). |
| 4 | `AddHabitFAB` | Floating action button at bottom-right. Uses `AppRadius.fab`, `AppSizes.fab`, `AppColors.primary`. Gentle scale-up entrance animation on screen load. |

**Sub-screens:**

#### 4.2.1 Add Habit Bottom Sheet / Screen

**Route:** `/habits/add` (full screen, not a bottom sheet — gives room to breathe)

**Layout:**

| # | Widget Name | Description |
|---|-------------|-------------|
| 1 | `HabitNameInput` | Text field with hint "What do you want to build?" — not "Enter habit name". Warm, inviting copy. Uses `AppRadius.input`, `AppSizes.inputHeight`. |
| 2 | `CategoryPicker` | Grid of category options (Health, Mind, Fitness, Learning, Creativity, Social, Self-Care, Custom). Each is a soft card with emoji + label. Selected state: `AppColors.primary` border + subtle background tint. |
| 3 | `FrequencySelector` | Choose: Daily, Specific Days (show day-of-week toggles), X times per week (stepper). Default: Daily. |
| 4 | `ReminderToggle` | Simple switch + time picker. Optional. Off by default. Label: "Gentle reminder" — not "Set notification". |
| 5 | `EmojiPicker` | Optional: pick a custom emoji for the habit. Show a small grid of ~30 common emojis relevant to self-improvement. |
| 6 | `SaveHabitButton` | Full-width primary button: "Start Building". Not "Save" or "Create". Disabled until name is non-empty. |

**Data on Save:**
Insert into `habits` table: name, emoji, category_id, frequency_type, frequency_days (JSON list of weekday indices or null), reminder_enabled, reminder_time, created_at, sort_order, is_archived=false.

#### 4.2.2 Edit Habit Screen

**Route:** `/habits/edit/:id`

Same layout as Add, but pre-populated. Additional option at the bottom:

| Widget | Description |
|--------|-------------|
| `ArchiveHabitButton` | Text button: "Archive this habit". Not "Delete". Confirms with a gentle dialog: "Archive '[habit name]'? You can bring it back anytime." Uses `AppColors.textSecondary`, not red. |

---

### 4.3 Statistics Screen

**Purpose:** Understand your consistency over time. Not a performance review — a reflection tool. **Any statistic that requires more than 5 seconds to understand is too complicated and must be redesigned or removed.**

**Route:** `/statistics`

**Emotional Tone:** Insightful, calm, encouraging. Like reading a personal wellness report, not a quarterly business review.

**Layout (scrollable):**

| # | Widget Name | Description |
|---|-------------|-------------|
| 1 | `StatisticsHeader` | "Your Journey" title + a subtitle that adapts: e.g. "12 weeks of building" (based on days since first habit creation). Uses `AppTypography.textTheme.headlineMedium`. |
| 2 | `OverallHeatmapCard` | GitHub-style heatmap showing last 3 months. Cells colored from `AppColors.heatmap[0..4]` based on completion percentage that day. Uses `AppSizes.heatmapCell` and `AppSizes.heatmapSpacing`. The heatmap is not a chart to be studied. It is a visual memory the user should recognize at a glance, without reading a single number. |
| 3 | `StreakDisplayCard` | Shows current streak and longest streak side by side. Two soft columns inside one card. Current streak prominently sized, longest streak smaller. If current = longest, show a subtle "Personal best!" badge. No "streak broken" messaging — if streak is 0, show "Start a new streak today" with a seedling emoji 🌱. |
| 4 | `WeeklyInsightsCard` | Auto-generated 2–3 sentence insight, always positive. Examples: "You were most consistent on Wednesdays — maybe that's your power day?" / "You completed 85% of your habits this week. Steady and strong." Never: "You missed 15% of habits." |
| 5 | `MostCommonReasonsCard` | Shows a simple ranked breakdown of why habits were missed, computed from `HabitReflections` category frequency over the last 30 days. E.g.: 🧠 Focus 42% / ⏰ Time 30% / 💤 Energy 20% / 🌍 Environment 8%. **Empty state:** if fewer than 3 reflection entries exist, hide this card entirely — not enough data to be meaningful, and a near-empty stat is worse than no stat. Data source: `watchMostCommonReasons(days: 30)` DAO method. |
| 6 | `CompletionTrendChart` | Line chart (via `fl_chart`) showing daily completion percentage over the last 30 days. Smooth bezier curves. Line color: `AppColors.primary`. Fill: `AppColors.primary.withOpacity(0.08)`. Axis labels minimal — just first/last date and percentage marks at 0/50/100. Toggle between 7d / 30d / 90d with chips. Animate on entrance using `AppDurations.chart`. |
| 7 | `HabitBreakdownList` | Per-habit statistics cards. Each shows: habit emoji + name, completion rate as a thin horizontal bar, current streak. Tapping expands to show that habit's individual heatmap. |
| 8 | `MonthlyCalendarView` | A clean monthly calendar. Days with completions have a dot below the date number. Color intensity based on that day's completion percentage. Swipe to change months. Today is circled with `AppColors.primary` ring. |

**Data Requirements:**

- `watchStreaks()` → current + longest streak per habit and overall.
- `watchHeatmapData(months: 3)` → `Map<DateTime, double>` (date → completion %).
- `watchCompletionTrend(days: 30)` → `List<DailyCompletion>` for charting.
- `watchWeeklyInsight()` → computed insight text based on this week's data.
- `watchHabitBreakdowns()` → per-habit stats (completion rate, streak, last completed).
- `watchMostCommonReasons(days: 30)` → `List<ReasonFrequency>` — ranked breakdown of reflection categories.

**States:**

| State | Behavior |
|-------|----------|
| **Loading** | Shimmer placeholders matching card shapes. |
| **Empty (no completion data)** | Warm message: "Your journey starts with the first check. Once you complete a habit, your story will appear here." No empty charts — hide chart widgets entirely when there's no data. |
| **Loaded** | All sections visible with animated entrances. Charts animate their curves/fills on first appearance. |

---

### 4.4 Shell & Navigation

**Widget:** `TracelyShell`

A `Scaffold` wrapping the bottom navigation bar and the current tab's content.

**Bottom Navigation Bar Spec:**

- 3 tabs: Dashboard (home), Habits (check-circle), Statistics (bar-chart-2)
- Use `NavigationBar` (Material 3) with custom theming:
  - Background: `AppColors.surface`
  - Indicator: `AppColors.primary.withOpacity(0.12)` with `AppRadius.navigation`
  - Selected icon/label: `AppColors.primary`
  - Unselected icon/label: `AppColors.textDisabled`
  - Height: `AppSizes.bottomNavigationHeight`
  - Elevation: 0, with a top `Divider` of `AppColors.border`
  - Label behavior: `NavigationDestinationLabelBehavior.alwaysShow`
- Animate tab switches with a subtle cross-fade (no slide), duration: `AppDurations.navigation`.

**Navigation flow:**

```
ReflectionScreen (no bottom nav, route '/')
       │
       ▼  (user taps Continue)
TracelyShell (bottom nav visible)
  ├── /dashboard   (default tab)
  ├── /habits
  └── /statistics
```

---

### 4.5 Pause & Reflect (Missed Habit Reflection)

**Purpose & Tone**

This is the emotional counterpart to habit completion. Where the Dashboard celebrates what was done, Pause & Reflect gently explores what wasn't — and more importantly, *why*. The question is never "Why did you fail?" — it is always **"What got in the way today?"** or **"Anything you'd like to remember about today?"** No red, no warning icons, no guilt framing anywhere in this flow.

**Trigger Logic**

- Triggered **once per day**, aggregated across all habits missed that day — NOT once per individual missed habit. Asking per-habit would feel like an interrogation; a single daily check-in is calmer and matches the emotional design pillars.
- Fires **at next app open** — evaluated when the user opens the app on a day after one where habits were missed. The trigger checks `HabitCompletions` for the prior day against active habits scheduled for that day.
- Only fires if **at least one habit was missed** the prior day AND the user hasn't already answered for that date (checked against `HabitReflections.reflectionDate`).
- **Always skippable** — a visible "Not now" dismiss affordance with zero friction. If dismissed, the prompt does not reappear that day. No repeated nagging, no passive-aggressive re-prompting, no badge or indicator that "you haven't reflected yet."

**UI Spec**

**Component name:** `PauseAndReflectSheet` — a `DraggableScrollableSheet` / large `showModalBottomSheet`, approximately 75% screen height, heavily rounded top corners (`AppRadius.sheet` or the largest existing radius token), generous internal spacing (`AppSpacing.xl` / `AppSpacing.xxl`).

**Header:** A small leaf/plant icon (🌿 or similar soft glyph), then three short lines of text, generous line spacing, centered:
- "Today didn't go exactly as planned." — `AppTypography.textTheme.titleLarge`
- "That's okay." — `AppTypography.textTheme.bodyMedium`, `AppColors.textSecondary`
- "What got in the way today?" — `AppTypography.textTheme.titleLarge`

**Reason Selection:** NOT a flat chip list. Group into 6 categories, each rendered as its own small labeled cluster of soft, rounded "reason cards" (not checkboxes — cards with a small emoji + label, selected state = `AppColors.primary` border + faint tint background, same visual language as `CategoryPicker` in §4.2.1):

| Category | Emoji | Reason Labels |
|----------|-------|---------------|
| **Energy** | 🌱 | Low Energy, Poor Sleep, Felt Sick, Burned Out |
| **Time** | ⏰ | Too Busy, Unexpected Work, Meetings, Family Responsibilities |
| **Mind** | 🧠 | Lost Motivation, Procrastinated, Forgot, Felt Overwhelmed, Couldn't Focus |
| **Environment** | 🌍 | Traveling, Weather, No Equipment, Outside Home |
| **Personal** | ❤️ | Needed Rest, Mental Break, Personal Event, Emergency |
| **My Reason** | ✍️ | Free-text custom input (single line, optional) |

**Multi-select allowed, capped at 2 selections maximum.** Specify this cap explicitly in code comments so it isn't silently removed later. If the user attempts a third selection, the earliest selection deselects (FIFO behavior).

**Follow-up question:** Optional single follow-up question, shown ONLY if certain categories are picked. Maximum one follow-up ever — never stack multiple. This is a simple lookup table, not a complex branching tree:

| Trigger Reason | Follow-up Question | Answer Options |
|---------------|-------------------|----------------|
| Low Energy | "How was your energy?" | 🙂 Great / 😐 Okay / 😴 Very Low |
| Poor Sleep | "How did you sleep?" | 😴 Badly / 😐 Okay / 😊 Well |
| Too Busy | "What kept you busy?" | Work / College / Family / Other |
| Lost Motivation | "Has this been going on?" | Just today / A few days / A while |
| Felt Overwhelmed | "Was it habit-related?" | Yes / No / Not sure |

If multiple triggering reasons are selected, show the follow-up for the **first** triggering reason only (ordered by the table above).

**Footer:** No "Save" or "Submit" button — only **"Continue"** (or "Done" if no selections made). Below the button, a small closing line: **"🌱 Tomorrow, we'll try again."** — styled the same as the existing `DashboardMotivationFooter` treatment (`AppColors.textDisabled`, italic, `AppTypography.textTheme.bodySmall`).

**Dismiss affordance:** A clear "Not now" text button in the top-right corner of the sheet header, or a visible drag-down handle. Tapping "Not now" dismisses the sheet immediately with no confirmation dialog.

**Entrance animation:** Sheet slides up with a gentle decelerate curve (reuse `AppCurves.emphasizedDecelerate`). Reason cards fade and stagger in similar to the dashboard habit-tile stagger pattern already spec'd in §5.3 — overlapping `Interval`s, not sequential blocking.

**Data Model**

See §8.4a for the `HabitReflections` Drift table. This is a **separate table** from `DailyReflections` (§8.4). `DailyReflections` captures the morning mood/quote check-in from the Daily Opening Ritual — the user's emotional state as they begin their day. `HabitReflections` captures the end-of-day (or next-morning) "what got in the way" check-in — a reflection on what happened after the day played out. Different moments, different purpose, different data shape. Merging them would conflate two distinct emotional touchpoints and make queries unnecessarily complex.

**Statistics Integration**

See `MostCommonReasonsCard` in §4.3 (position 5 in the layout table, between `WeeklyInsightsCard` and `CompletionTrendChart`).

**Phase Placement**

- Data layer (table + DAO) + trigger logic + `PauseAndReflectSheet` UI: **Phase 2** (depends on habit completion data, which is Phase 2 scope). See §9 Phase 2 DoD.
- `MostCommonReasonsCard` statistics display: **Phase 3** (inherently a statistics feature). See §9 Phase 3 DoD.

**Future Vision**

The reason categories and follow-up answers are stored as structured data (JSON arrays of known keys, not free text dumped into a single column) specifically so that a future pattern-recognition or ML layer could surface deeper correlations — e.g. "Workouts are most often missed on low-energy days following poor sleep" or "Your motivation dips correlate with weeks where meetings exceed 4 hours." This intelligence layer is explicitly NOT being built now. The schema is designed to support it later without migration. See §10 Non-Goals: "AI/ML pattern analysis on reflection data."

---

## 5. Animation System Specification

Small, tiny moments of delight — the checkbox bounce, the heatmap cell filling, the quote card's reveal glow, the completion ripple, a subtle haptic — are not decorative extras. They are core to making Tracely feel alive, feel premium, feel like something worth opening every morning. These micro-interactions are already specified throughout this document (§5.4 Habit Completion Micro-Interaction, §6.3 Haptic & Sound Micro-Feedback) and are not repeated here. What follows is the system that makes them possible and consistent.

### 5.0 Motion Philosophy

Motion in Tracely exists for three reasons: to **reduce cognitive load**, to **guide attention**, and to **create emotional comfort**. It never exists to impress, to demonstrate technical capability, or to "look cool." If removing an animation would make the app feel jarring or confusing, the animation is justified. If removing it would make no perceptible difference, the animation is waste — delete it.

**Quality target:** Claude's mobile app, Apple Health, Headspace, Calm. These are the benchmarks. Not typical Flutter/Material demo animations. Not Material's default `Curves.fastOutSlowIn` on everything. Tracely's motion should feel handcrafted, not framework-default.

**Required characteristics:**

- **Slow acceleration into motion, smooth deceleration out of it.** Elements should feel like they're easing into existence, not snapping on. Decelerate curves are preferred over symmetric ease-in-out for entrances.
- **No abrupt fades.** Opacity transitions always span at least 150ms. An element appearing in under 100ms reads as a glitch, not an animation.
- **No bouncy or aggressive springs.** Tracely is calm. Spring simulations, elastic curves, and aggressive overshoots have no place here. **The one deliberate exception:** the `easeOutBack` overshoot on habit completion (§5.4, phase 1: scale bounce 1.0→0.85→1.1→1.0). That single, isolated overshoot is an intentional celebration — it communicates "something satisfying just happened." It must not be "fixed," normalized, or flattened by future agents. It is the only place in the entire app where overshoot is appropriate.
- **Overlapping timelines, not sequential blocking.** Elements should begin entering before the previous element has finished. This creates a flowing, cascading feel rather than a slide-deck-like step-through.
- **Generous breathing space between elements.** Stagger gaps should feel unhurried. When in doubt, add 30ms more gap, not less.
- **Subtle rather than dramatic opacity and scale changes.** A slide-up of 20px with a fade feels elegant. A slide-up of 60px with a scale from 0.5→1.0 feels like a PowerPoint transition. Keep transforms small and understated.

**The explicit rule:** If an animation would work fine as a hard cut, it doesn't need to exist. If it needs to exist, it should never be sudden.

### 5.1 The Parent-Controller + Interval Pattern

This is the **canonical animation architecture** for Tracely, already established in `ReflectionScreen`. Every screen with entrance animations must replicate it.

**Pattern:**

```dart
class SomeScreen extends StatefulWidget { ... }

class _SomeScreenState extends State<SomeScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: TOTAL_DURATION),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WidgetA(controller: _controller), // Uses Interval(0.0, 0.25)
        WidgetB(controller: _controller), // Uses Interval(0.15, 0.45)
        WidgetC(controller: _controller), // Uses Interval(0.35, 0.65)
        // ... overlapping intervals for smooth stagger
      ],
    );
  }
}
```

**Inside each child widget:**

```dart
class WidgetA extends StatelessWidget {
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    final slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic),
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Opacity(
          opacity: opacity.value,
          child: Transform.translate(
            offset: Offset(0, slideUp.value),
            child: ... // actual content
          ),
        );
      },
    );
  }
}
```

### 5.2 Existing Reflection Screen Intervals (Reference)

Total duration: **2500ms**

| Widget | Interval | Effect |
|--------|----------|--------|
| `ReflectionBackground` | 0.0–0.6 | Radial glow fade-in |
| `AnimatedGreeting` fade | 0.0–0.25 | Opacity 0→1 |
| `AnimatedGreeting` scale | 0.0–0.30 | Scale 0.95→1.0 |
| `AnimatedGreeting` move | 0.20–0.55 | Alignment.y 0.0→-0.82 |
| `AnimatedQuoteCard` opacity | 0.45–0.75 | Opacity 0→1 |
| `AnimatedQuoteCard` slide | 0.45–0.80 | TranslateY 40→0 |
| `AnimatedQuoteCard` glow | 0.55–0.90 | Glow intensity 0→1 |
| `AnimatedContinueButton` opacity | 0.80–1.0 | Opacity 0→1 |
| `AnimatedContinueButton` slide | 0.80–1.0 | TranslateY 40→0 |

### 5.3 Dashboard Entrance Animation

Total duration: **1200ms** (shorter than reflection — users visit this screen repeatedly, so entrance should be swift but not jarring).

Use `AppDurations.slow` (400ms) as base reference — the total orchestrated entrance is 1200ms to give room for the stagger across 5 elements.

| Widget | Interval | Effect | Curve |
|--------|----------|--------|-------|
| `DashboardGreetingSection` | 0.0–0.20 | Opacity 0→1, TranslateY 20→0 | `AppCurves.emphasizedDecelerate` |
| `DailyProgressCard` | 0.10–0.40 | Opacity 0→1, TranslateY 24→0, progress ring fill starts | `AppCurves.standard` |
| `DailyProgressCard` ring | 0.20–0.55 | Ring sweep 0→actual% | `AppCurves.progress` |
| `TodaysHabitsSection` header | 0.25–0.45 | Opacity 0→1, TranslateY 20→0 | `AppCurves.emphasizedDecelerate` |
| `TodaysHabitsSection` items | 0.30–0.70 | Staggered per item: each habit tile fades in with 40ms gap between them (first at 0.30, second at 0.30 + Δ, etc.) | `AppCurves.list` |
| `WeeklyHeatmapPreview` | 0.50–0.75 | Opacity 0→1, TranslateY 20→0, cells fill sequentially left→right | `AppCurves.heatmap` |
| `RecentActivitySection` | 0.65–0.85 | Opacity 0→1, TranslateY 16→0 | `AppCurves.emphasizedDecelerate` |
| `DashboardMotivationFooter` | 0.80–1.0 | Opacity 0→0.6 (stays semi-transparent, ethereal) | `AppCurves.standard` |

**Implementation note:** Because the dashboard has a variable number of habit tiles, the stagger for `TodaysHabitsSection` items should be computed dynamically:

```dart
// Inside TodaysHabitsSection
final int itemCount = habits.length;
final double staggerStart = 0.30;
final double staggerEnd = 0.70;
final double perItemDuration = (staggerEnd - staggerStart) / (itemCount + 1);

for (int i = 0; i < itemCount; i++) {
  final start = staggerStart + (i * perItemDuration * 0.6); // overlapping
  final end = (start + perItemDuration * 1.5).clamp(0.0, staggerEnd);
  // Use Interval(start, end) for item i
}
```

### 5.4 Habit Completion Micro-Interaction

This is a **self-contained** animation — the `HabitCompletionCheckbox` widget owns its own `AnimationController` because it's triggered by user tap, not by screen entrance.

**Duration:** `AppDurations.habitComplete` (220ms)

**Tap → Complete sequence:**

| Phase | Time | Effect |
|-------|------|--------|
| 1. Scale bounce | 0–120ms | Checkbox scales 1.0→0.85→1.1→1.0 (overshoot spring). Curve: `AppCurves.habitCompletion` (easeOutBack). |
| 2. Fill morph | 40–180ms | Empty circle morphs into filled circle with checkmark. Color transitions from `AppColors.border` to `AppColors.success`. |
| 3. Ripple glow | 80–220ms | A soft radial glow expands from the checkbox center, `AppColors.success.withOpacity(0.15)`, radiating outward and fading. Max radius: 32px. |
| 4. Text crossfade | 60–220ms | Habit name text gets a subtle strikethrough (very thin, `AppColors.textDisabled`) and color shifts from `AppColors.textPrimary` to `AppColors.textSecondary`. This is gentle — the text doesn't "grey out harshly"; it simply recedes. |

**Tap → Uncomplete sequence (reversal):**

| Phase | Time | Effect |
|-------|------|--------|
| 1. Scale tap | 0–100ms | Quick scale 1.0→0.92→1.0. |
| 2. Fill reverse | 0–150ms | Filled circle reverts to empty circle. Color: `AppColors.success` → `AppColors.border`. |
| 3. Text restore | 0–150ms | Name text returns to `AppColors.textPrimary`, strikethrough removed. |

No glow on uncomplete — removing a completion should feel neutral, not punishing.

**Implementation:**

```dart
class HabitCompletionCheckbox extends StatefulWidget {
  final bool isCompleted;
  final VoidCallback onToggle;
  // ...
}

class _HabitCompletionCheckboxState extends State<HabitCompletionCheckbox>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.habitComplete,
    );
  }

  void _handleTap() {
    if (widget.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    widget.onToggle();
  }
  // ... build with AnimatedBuilder, scale/fill/glow animations
}
```

### 5.5 Statistics Screen Entrance Animation

Total duration: **1500ms** (slightly longer — this screen is visited less often, and the chart animations benefit from more breathing room).

| Widget | Interval | Effect |
|--------|----------|--------|
| `StatisticsHeader` | 0.0–0.15 | Opacity + TranslateY 20→0 |
| `OverallHeatmapCard` | 0.08–0.40 | Opacity, then cells fill in a wave pattern left→right, top→bottom with 15ms stagger per cell |
| `StreakDisplayCard` | 0.25–0.50 | Opacity + TranslateY, then streak numbers count up from 0 to actual value |
| `WeeklyInsightsCard` | 0.35–0.55 | Opacity + TranslateY |
| `MostCommonReasonsCard` | 0.40–0.57 | Opacity + TranslateY (only if card is visible — skipped when fewer than 3 reflections exist) |
| `CompletionTrendChart` | 0.45–0.75 | Opacity, then line draws from left to right (path animation) |
| `HabitBreakdownList` | 0.55–0.80 | Staggered item entrance (same dynamic stagger as dashboard habits) |
| `MonthlyCalendarView` | 0.70–0.95 | Opacity + scale 0.97→1.0 |

### 5.6 Page Transition Between Reflection → Dashboard

When the user taps "Continue" on the Reflection screen:

- Use `GoRouter`'s custom transition: `CustomTransitionPage` with a `FadeTransition`.
- Duration: `AppDurations.pageTransition` (280ms).
- Curve: `AppCurves.pageTransition`.
- The reflection screen fades out while the dashboard shell fades in. No slide — a calm dissolve.

### 5.7 Bottom Navigation Tab Switching

- Use `AnimatedSwitcher` or `FadeTransition` for tab content.
- Duration: `AppDurations.navigation` (250ms).
- Curve: `AppCurves.navigation`.
- Content fades, it does not slide. Sliding between tabs feels utilitarian; fading feels calm.

---

## 6. Innovative Ideas Section

> **⚠️ IMPORTANT: These are suggestions — not yet approved for building.**
> **Evaluate each before implementing. Build ONLY if explicitly approved by the user.**
> **Each idea passes the filter: "Does this reduce pressure and increase warmth?"**

### 6.1 Streak Forgiveness — "Recovery Days"

**Concept:** Instead of harsh streak resets (miss one day → streak goes to zero), Tracely offers a "recovery day" system. Each week, the user gets **one automatic grace day**. If they miss a single day in a week, their streak continues unbroken. The missed day appears in the heatmap as a faintly colored cell (not empty, not full — a gentle amber) with a small heart icon.

**Why it matters:** Streaks are the #1 reason users abandon habit apps. One missed day destroys weeks of progress, which feels disproportionately punishing. Recovery days preserve the psychological momentum while acknowledging that life happens.

**Implementation notes:**
- `StreakCalculator` checks: if days_missed_this_week ≤ 1 AND at least one completion exists that week → streak continues.
- Recovery days are not "banked" — you can't save them up. It's 1 per calendar week.
- UI: In the heatmap, recovery days show as `AppColors.heatmap[1]` (lightest warm) with a tiny ♡ overlay.
- Copy: "Recovery day used — your streak continues 💛"

### 6.2 Adaptive Micro-Copy

**Concept:** The greeting, empty states, and motivational footer text adapt based on:
- **Time of day:** Morning → energizing ("Fresh start ahead"), Evening → reflective ("How did today feel?"), Late night → gentle ("Still here? Take it easy tonight.").
- **Recent consistency:** 7+ day streak → celebratory ("You're on a roll — 12 days strong."), Returned after a gap → welcoming ("Welcome back. Every restart counts."), First day → encouraging ("Day one — the hardest and most important.").

**Why it matters:** Static copy becomes invisible after day 3. Adaptive copy creates a sense that the app *notices* you and responds to your behavior, which builds emotional attachment.

**Implementation notes:**
- Create a `MicroCopyProvider` (Riverpod) that takes current time + streak data and returns a `MicroCopy` object with `.greeting`, `.dashboardSubtitle`, `.motivationFooter`, `.emptyStateMessage`.
- Keep a pool of ~20 variants per slot in `core/constants/app_strings.dart`.
- Rotate deterministically (hash of date + streak length) so the user doesn't see the same copy two days in a row, but it's not random either (reproducible for testing).

### 6.3 Haptic & Sound Micro-Feedback

**Concept:** Ultra-subtle haptic feedback on habit completion (iOS `UIImpactFeedbackGenerator.medium`, Android equivalent). Optionally, a very short, premium completion sound — think iOS keyboard click or the Apple Pay success chime, not a game sound effect.

**Why it matters:** Tactile feedback converts a visual event into a physical one, which is proven to increase satisfaction and perceived quality. The Claude mobile app, Apple Health, and iOS system interactions all use this to great effect.

**Implementation notes:**
- Use `HapticFeedback.mediumImpact()` from `flutter/services.dart` on habit completion. No package needed.
- Sound: Optional future addition. If implemented, use a single .wav file (~0.3s, soft click/chime), loaded via `AudioPlayer`. Off by default, toggleable in Settings.
- Never play sound on uncomplete — only on positive actions.
- Never play haptic on scroll, navigation, or other non-intentional touches.

### 6.4 Weekly Reflection Letter

**Concept:** Every Sunday (or configurable day), the Statistics screen shows a special card at the top: a "Weekly Letter" — a short, warm summary written in first-person as if from a caring friend.

Example:
> "This week you showed up 5 out of 7 days. Your strongest habit was 'Morning Walk' — you didn't miss it once. Wednesday was your most consistent day. You're building something real. See you next week. 💛"

**Why it matters:** Data without narrative is forgettable. A letter format transforms statistics into a personal story. Users screenshot and share these — free organic marketing that also reinforces the habit.

**Implementation notes:**
- Computed from: weekly completions, per-habit completion rates, most/least consistent day, streak data.
- Template engine in `core/utils/weekly_letter_generator.dart` with ~5 template variants.
- Letter card appears only on Sunday (or the day after the user's configured week-start).
- If the user had 0 completions that week, the letter is extra gentle: "Quiet weeks happen. The app will be here whenever you're ready."
- Card style: Slightly different from standard cards — maybe a very faint `AppColors.primaryLight` border and a handwriting-style font for the letter body (optional — evaluate if it fits the Inter-based typography system).

### 6.5 Gesture-Based Habit Completion (Swipe-to-Complete)

**Concept:** Instead of (or in addition to) tapping a checkbox, the user can **swipe right** on a habit tile to complete it. The swipe reveals a warm gradient background (`AppColors.primaryLight` → `AppColors.success`) that progressively expands as the finger drags. At ~60% threshold, the habit "snaps" to complete with a satisfying settle animation (slight bounce-back).

**Why it matters:** Swipe gestures feel more physical and intentional than taps. They create a sense of "pulling" progress into being, which is more emotionally engaging. Think iOS "slide to unlock" satisfaction.

**Implementation notes:**
- Use `Dismissible` or custom `GestureDetector` + `AnimationController`.
- Swipe right = complete. Do NOT implement swipe left for delete/archive — negative actions should never be this easy.
- Settle animation: `AppCurves.habitCompletion` (easeOutBack), duration 200ms.
- If already completed, swiping does nothing (or swipe left to uncomplete — but evaluate if this adds confusion).
- The tap checkbox should ALSO still work — swipe is an alternative, not a replacement.

### 6.6 Breathing Background — "Consistency Pulse"

**Concept:** The dashboard background has an extremely subtle radial gradient (like the existing `ReflectionBackground`) that "breathes" — slowly pulsing its opacity between 0.04 and 0.08 on a ~6-second cycle. The color of the gradient shifts very slightly based on overall consistency:

- High consistency (>80% this week): Warm amber glow (`AppColors.primaryLight`)
- Medium consistency (40–80%): Neutral warm (`AppColors.primary.withOpacity(0.06)`)
- Low consistency (<40%): Soft, barely-there (`AppColors.surfaceVariant`)

**Why it matters:** A living, breathing background makes the app feel alive without being distracting. It subconsciously communicates "things are going well" through warmth, not numbers. Crucially, low consistency doesn't turn the background cold or grey — it just becomes more neutral. There is no punishment, only degrees of warmth.

**Implementation notes:**
- Separate infinite `AnimationController` with `repeat(reverse: true)`.
- Duration: 6000ms per cycle.
- Curve: `Curves.easeInOut` (sinusoidal feel).
- Gradient opacity range: 0.03–0.08 (extremely subtle — if someone isn't looking for it, they shouldn't notice it).
- This is the ONE exception to "no independent controllers per widget" — the breathing background is an ambient loop, not an entrance animation.

### 6.7 "Momentum Nudge" — Gentle Progress Awareness

**Concept:** When the user opens the dashboard and has completed 60%+ of their habits for the day, a very subtle line of text appears below the progress card: "Almost there — just 2 left." When they complete the last one, this transforms into "All done 🌟" with a gentle fade.

**Why it matters:** It creates a soft pull toward completion without urgency. "Almost there" feels encouraging, not pressuring. It taps into the Zeigarnik effect (incomplete tasks stay in mind) without weaponizing it.

**Implementation notes:**
- Show only when completion is >60% and <100%.
- Style: `AppTypography.textTheme.bodySmall`, `AppColors.textSecondary`, italic.
- Transition between "Almost there" and "All done" uses a crossfade with `AppDurations.medium`.
- Never show this at 0% or low % — it would feel like nagging.

---

## 7. Theming Extension Notes

### Color Voice

Colors in Tracely read as **warm, organic, paper-like, natural, earthy, and comfortable**. The Stone & Sand palette is inspired by aged paper, natural stone, dried clay, morning sunlight, and forest floors — not screens. Every color should feel like it could exist in a physical journal or a well-lit study.

**Explicitly forbidden:** Neon colors, gaming-style saturation, cyberpunk/synthwave palettes, and glass/blur effects used decoratively. Glassmorphism and backdrop blur are only acceptable when they demonstrably improve visual hierarchy — e.g., a modal bottom sheet over scrollable content where the blur communicates "this content is behind you, focus here." Blur is never a default aesthetic layer, never used on cards, never used on navigation bars, and never used as a background treatment just because it "looks modern."

### Principle: Extend, Never Replace

All new theme tokens are **added** to existing files. Never modify existing token values — only add new ones. The Stone & Sand palette is the foundation; new screens add surface within that palette.

### AppColors Extensions

```dart
// Add to app_colors.dart — DO NOT modify existing values

// ---------------------------------------------------------------------------
// Category Colors (muted, warm variants — never harsh)
// ---------------------------------------------------------------------------

static const Color categoryHealth    = Color(0xFF65A30D); // Olive green
static const Color categoryMind      = Color(0xFF7C3AED); // Soft violet
static const Color categoryFitness   = Color(0xFFEA580C); // Warm orange
static const Color categoryLearning  = Color(0xFF2563EB); // Calm blue
static const Color categoryCreativity= Color(0xFFDB2777); // Soft rose
static const Color categorySocial    = Color(0xFF0891B2); // Teal
static const Color categorySelfCare  = Color(0xFFD97706); // Amber (= primaryLight)
static const Color categoryCustom    = Color(0xFF78716C); // Stone (= secondary)

// ---------------------------------------------------------------------------
// Completion States (gentle, never alarming)
// ---------------------------------------------------------------------------

static const Color completedBackground   = Color(0xFFF0FDF4); // Very faint green
static const Color completedBorder       = Color(0xFFBBF7D0); // Light green border
static const Color uncompletedBackground = Color(0xFFFAFAF9); // Near-white warm
static const Color recoveryDay           = Color(0xFFFEF3C7); // Lightest amber

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

static const Color streakActive    = Color(0xFFD97706); // Amber
static const Color streakRecord    = Color(0xFFB45309); // Deep amber (= primary)
static const Color insightCard     = Color(0xFFFFFBEB); // Warm cream background
```

### AppTypography Extensions

No new text styles needed — the existing M3 text theme covers all cases. Use these mappings:

| UI Element | TextTheme Style | Notes |
|-----------|----------------|-------|
| Screen title (Dashboard, Statistics) | `headlineMedium` | Weight w600 |
| Section header ("Today's Habits") | `titleMedium` | Weight w600 |
| Habit name in tile | `bodyLarge` | Weight w400 |
| Habit frequency label | `labelMedium` | Color: textSecondary |
| Streak number | `displaySmall` | Weight w700 |
| Streak label ("Current Streak") | `labelSmall` | Color: textSecondary |
| Weekly insight body | `bodyMedium` | Height 1.6, italic |
| Motivation footer | `bodySmall` | Color: textDisabled, italic |
| Empty state title | `titleLarge` | Weight w600 |
| Empty state body | `bodyMedium` | Color: textSecondary |

### AppSpacing Extensions

```dart
// Add to app_spacing.dart

// Habit Tile
static const EdgeInsets habitTile = EdgeInsets.symmetric(
  horizontal: lg,
  vertical: md,
);

// Statistics Card
static const EdgeInsets statisticsCard = EdgeInsets.all(xl);

// Section spacing (vertical gap between dashboard sections)
static const double sectionGap = xxl; // 24px between sections
```

### AppSizes Extensions

```dart
// Add to app_sizes.dart

// Completion checkbox
static const double completionCheckbox = 28;
static const double completionCheckboxRipple = 44; // Touch target

// Category dot
static const double categoryDot = 10;

// Streak display
static const double streakNumberSize = 48; // Large streak number

// Progress ring
static const double progressRingSize = 120;
static const double progressRingStroke = 8;

// Heatmap (already exists — ensure these are used)
// static const double heatmapCell = 16;    ← already defined
// static const double heatmapSpacing = 4;  ← already defined

// Weekly heatmap strip (compact, 7-day)
static const double weeklyHeatmapCellSize = 28;
```

### AppDurations Extensions

The existing `AppDurations` already has `habitComplete`, `streak`, `chart`, `heatmap`, `progress` — all correctly valued. No additions needed.

### AppCurves Extensions

The existing `AppCurves` already has `habitCompletion`, `streak`, `chart`, `heatmap`, `progress` — all correctly valued. No additions needed.

### AppShadows Extensions

No new shadows needed. Use `AppShadows.sm` for habit tiles, `AppShadows.md` for cards, `AppShadows.lg` for elevated elements (FAB).

---

## 8. Data Model Draft (Drift Schema)

### 8.1 Categories Table

```dart
// lib/data/database/tables/categories_table.dart

import 'package:drift/drift.dart';

class Categories extends Table {
  /// Auto-incrementing primary key
  IntColumn get id => integer().autoIncrement()();

  /// Display name: "Health", "Mind", "Fitness", etc.
  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// Emoji for the category: "💪", "🧠", "📚", etc.
  TextColumn get emoji => text().withLength(min: 1, max: 10)();

  /// Hex color code (stored as int for AppColors mapping)
  /// Maps to one of AppColors.category* constants.
  IntColumn get colorValue => integer()();

  /// Sort order for display
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Whether this is a built-in category (cannot be deleted)
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();

  /// Soft delete
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// When this category was created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
```

### 8.2 Habits Table

```dart
// lib/data/database/tables/habits_table.dart

import 'package:drift/drift.dart';

class Habits extends Table {
  /// Auto-incrementing primary key
  IntColumn get id => integer().autoIncrement()();

  /// Habit display name: "Morning Walk", "Read 20 pages", etc.
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Optional emoji override (if null, use category emoji)
  TextColumn get emoji => text().nullable().withLength(min: 1, max: 10)();

  /// Foreign key to Categories table
  IntColumn get categoryId => integer().references(Categories, #id)();

  /// Frequency type: 'daily', 'specific_days', 'x_per_week'
  TextColumn get frequencyType => text().withDefault(const Constant('daily'))();

  /// For 'specific_days': JSON array of weekday indices [1,2,3,4,5] (Mon=1, Sun=7)
  /// For 'x_per_week': JSON with {"times": 3}
  /// For 'daily': null
  TextColumn get frequencyConfig => text().nullable()();

  /// Whether reminder is enabled
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();

  /// Reminder time stored as "HH:mm" string (e.g. "08:30")
  TextColumn get reminderTime => text().nullable()();

  /// Display sort order within the habits list
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Archived habits are hidden from daily view but data is preserved
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// When this habit was first created
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Last time this habit was modified
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```

### 8.3 Habit Completions Table

```dart
// lib/data/database/tables/habit_completions_table.dart

import 'package:drift/drift.dart';

class HabitCompletions extends Table {
  /// Auto-incrementing primary key
  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to Habits table
  IntColumn get habitId => integer().references(Habits, #id)();

  /// The date this completion is for (stored as date only, no time component)
  /// Always normalized to midnight UTC of the target day.
  DateTimeColumn get completedDate => dateTime()();

  /// When the user actually tapped "complete" (full timestamp)
  DateTimeColumn get completedAt => dateTime().withDefault(currentDateAndTime)();

  /// Optional: was this a recovery day completion (streak forgiveness)?
  BoolColumn get isRecoveryDay => boolean().withDefault(const Constant(false))();

  /// Unique constraint: one completion per habit per day
  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, completedDate},
  ];
}
```

### 8.4 Daily Reflections Table

```dart
// lib/data/database/tables/daily_reflections_table.dart

import 'package:drift/drift.dart';

class DailyReflections extends Table {
  /// Auto-incrementing primary key
  IntColumn get id => integer().autoIncrement()();

  /// The date this reflection is for (normalized to midnight)
  DateTimeColumn get reflectionDate => dateTime()();

  /// The quote that was shown on the reflection screen
  TextColumn get shownQuote => text().nullable()();

  /// Overall mood/feeling for the day (optional, future use)
  /// Stored as int: 1=rough, 2=okay, 3=good, 4=great, 5=amazing
  IntColumn get moodRating => integer().nullable()();

  /// Optional free-text note
  TextColumn get note => text().nullable()();

  /// When this reflection was recorded
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// One reflection per day
  @override
  List<Set<Column>> get uniqueKeys => [
    {reflectionDate},
  ];
}
```

### 8.4a Habit Reflections Table (Pause & Reflect)

This table stores the user's response to the Pause & Reflect flow (§4.5). It is **intentionally separate** from `DailyReflections` (§8.4). `DailyReflections` captures the morning mood/quote check-in from the Daily Opening Ritual — the user's emotional state as they begin their day. `HabitReflections` captures the end-of-day (or next-morning) "what got in the way" check-in — a reflection on what happened after the day played out. These are two distinct emotional touchpoints occurring at different moments with different data shapes. Merging them would conflate purpose and complicate queries for both features.

```dart
// lib/data/database/tables/habit_reflections_table.dart

import 'package:drift/drift.dart';

class HabitReflections extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The calendar day being reflected on (normalized to midnight).
  DateTimeColumn get reflectionDate => dateTime()();

  /// JSON array of selected category keys, e.g. ["energy","mind"].
  /// Capped at 2 entries at the application layer.
  TextColumn get reasonCategories => text()();

  /// JSON array of the specific selected labels within those categories,
  /// e.g. ["Low Energy","Procrastinated"].
  TextColumn get reasonLabels => text()();

  /// Optional custom free-text reason ("My Reason").
  TextColumn get customReason => text().nullable()();

  /// Optional single follow-up answer, if a follow-up was shown.
  TextColumn get followUpAnswer => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// One reflection entry per day.
  @override
  List<Set<Column>> get uniqueKeys => [{reflectionDate}];
}
```

### 8.5 Database Class

```dart
// lib/data/database/app_database.dart

import 'package:drift/drift.dart';
// Platform-specific imports for native/web

import 'tables/categories_table.dart';
import 'tables/habits_table.dart';
import 'tables/habit_completions_table.dart';
import 'tables/daily_reflections_table.dart';
import 'tables/habit_reflections_table.dart';
import 'daos/habit_dao.dart';
import 'daos/completion_dao.dart';
import 'daos/category_dao.dart';
import 'daos/reflection_dao.dart';

@DriftDatabase(
  tables: [Categories, Habits, HabitCompletions, DailyReflections, HabitReflections],
  daos: [HabitDao, CompletionDao, CategoryDao, ReflectionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      // Seed default categories
      await _seedCategories();
    },
  );

  Future<void> _seedCategories() async {
    final defaults = [
      CategoriesCompanion.insert(name: 'Health',     emoji: '💚', colorValue: 0xFF65A30D, sortOrder: const Value(0), isBuiltIn: const Value(true)),
      CategoriesCompanion.insert(name: 'Mind',       emoji: '🧠', colorValue: 0xFF7C3AED, sortOrder: const Value(1), isBuiltIn: const Value(true)),
      CategoriesCompanion.insert(name: 'Fitness',    emoji: '💪', colorValue: 0xFFEA580C, sortOrder: const Value(2), isBuiltIn: const Value(true)),
      CategoriesCompanion.insert(name: 'Learning',   emoji: '📚', colorValue: 0xFF2563EB, sortOrder: const Value(3), isBuiltIn: const Value(true)),
      CategoriesCompanion.insert(name: 'Creativity', emoji: '🎨', colorValue: 0xFFDB2777, sortOrder: const Value(4), isBuiltIn: const Value(true)),
      CategoriesCompanion.insert(name: 'Social',     emoji: '🤝', colorValue: 0xFF0891B2, sortOrder: const Value(5), isBuiltIn: const Value(true)),
      CategoriesCompanion.insert(name: 'Self-Care',  emoji: '🧘', colorValue: 0xFFD97706, sortOrder: const Value(6), isBuiltIn: const Value(true)),
    ];
    for (final cat in defaults) {
      await into(categories).insert(cat);
    }
  }
}
```

### 8.6 Key DAO Methods

```dart
// HabitDao — essential methods to implement:

/// Watch all active (non-archived) habits with today's completion status
Stream<List<HabitWithCompletion>> watchTodaysHabits(DateTime today);

/// Watch completion count for today
Stream<DailyProgress> watchTodaysProgress(DateTime today);

/// Insert a new habit
Future<int> createHabit(HabitsCompanion habit);

/// Update a habit
Future<bool> updateHabit(HabitsCompanion habit);

/// Archive a habit (soft delete)
Future<void> archiveHabit(int habitId);

/// Restore an archived habit
Future<void> restoreHabit(int habitId);

/// Reorder habits
Future<void> reorderHabits(List<int> orderedIds);


// CompletionDao — essential methods:

/// Toggle completion for a habit on a date
Future<void> toggleCompletion(int habitId, DateTime date);

/// Watch weekly heatmap data (7 days)
Stream<List<DayCompletion>> watchWeeklyHeatmap(DateTime weekStart);

/// Watch full heatmap data (N months back)
Stream<Map<DateTime, double>> watchHeatmapData({required int months});

/// Watch completion trend (daily % over N days)
Stream<List<DailyCompletion>> watchCompletionTrend({required int days});

/// Watch recent completions
Stream<List<CompletionWithHabit>> watchRecentCompletions({required int limit});

/// Get streak data for a specific habit
Future<StreakData> getStreakData(int habitId);

/// Get overall streak data (across all habits)
Future<StreakData> getOverallStreakData();


// ReflectionDao — Pause & Reflect methods:

/// Check if a habit reflection exists for a given date
Future<bool> hasHabitReflection(DateTime date);

/// Insert a habit reflection entry
Future<int> createHabitReflection(HabitReflectionsCompanion reflection);

/// Watch most common reflection reason categories over N days,
/// returned as a ranked list of (category, percentage) pairs.
Stream<List<ReasonFrequency>> watchMostCommonReasons({required int days});
```

### 8.7 Data Classes (not Drift tables — pure Dart)

```dart
// Used as return types from DAOs, combining data from multiple tables

class HabitWithCompletion {
  final Habit habit;
  final Category category;
  final bool isCompletedToday;
  // ...
}

class DailyProgress {
  final int completedCount;
  final int totalCount;
  double get percentage => totalCount == 0 ? 0 : completedCount / totalCount;
}

class DayCompletion {
  final DateTime date;
  final double completionPercentage; // 0.0 to 1.0
  final bool isRecoveryDay;
}

class DailyCompletion {
  final DateTime date;
  final double percentage;
}

class CompletionWithHabit {
  final HabitCompletion completion;
  final Habit habit;
}

class StreakData {
  final int currentStreak;
  final int longestStreak;
  final bool isCurrentLongest; // currentStreak >= longestStreak
  final DateTime? lastCompletedDate;
}

class WeeklyInsight {
  final String message;
  final String? mostConsistentDay; // "Wednesday"
  final double weeklyCompletionRate;
}

class ReasonFrequency {
  final String category;    // "energy", "time", "mind", "environment", "personal"
  final String emoji;        // "🌱", "⏰", "🧠", "🌍", "❤️"
  final int count;
  final double percentage;   // 0.0 to 1.0, relative to total reflections in period
}
```

---

## 9. Definition of Done per Phase

### Phase 2: Dashboard + Habits + Navigation + Pause & Reflect

**Scope:** Build the daily experience — the user can create habits, see them on a dashboard, complete them, navigate between screens, and reflect on missed habits.

**Completion Criteria (ALL must be true):**

- [ ] **Database operational** — `AppDatabase` with all five tables (Categories, Habits, HabitCompletions, DailyReflections, HabitReflections) created, migrated, and seeded with default categories. `build_runner` has been run successfully. The app launches without DB errors.
- [ ] **Categories seeded** — 7 default categories exist in DB on first launch.
- [ ] **Create habit flow** — User can navigate to Add Habit screen, enter a name, pick a category, select frequency, and save. Habit persists in DB across app restarts.
- [ ] **Edit habit flow** — User can navigate to Edit Habit screen, modify any field, and save changes.
- [ ] **Archive habit flow** — User can archive a habit via Edit screen. Archived habits disappear from dashboard and habits list (unless "Archived" filter is active).
- [ ] **Dashboard renders** — All 6 sections render correctly: Greeting, Progress Ring, Today's Habits, Weekly Heatmap Preview, Recent Activity, Motivation Footer.
- [ ] **Habit completion works** — Tapping a habit checkbox on the dashboard toggles completion in DB. UI updates reactively (Riverpod stream).
- [ ] **Completion micro-interaction** — Checkbox tap triggers scale bounce + fill morph + ripple glow animation (per §5.4).
- [ ] **Dashboard entrance animation** — All sections animate in with staggered intervals (per §5.3).
- [ ] **Progress ring animates** — Ring fills from 0 to actual percentage on screen entrance.
- [ ] **Navigation shell works** — Bottom nav with 3 tabs (Dashboard, Habits, Statistics). Tab switching uses fade transition. Statistics tab can show a placeholder for now.
- [ ] **Reflection → Dashboard** — "Continue" button on Reflection screen navigates to Dashboard with fade transition.
- [ ] **Routing complete** — All routes defined in `app_router.dart`. Deep linking works (e.g. `/habits/edit/3`).
- [ ] **Empty states** — Dashboard shows warm empty state when no habits exist. Habits list shows warm empty state when no habits exist.
- [ ] **HabitReflections table operational** — `HabitReflections` Drift table created and included in `AppDatabase`. DAO methods for creating and querying reflections work correctly.
- [ ] **Pause & Reflect trigger logic** — On app open, the app checks if the prior day had missed habits and no existing `HabitReflections` entry for that date. If conditions met, `PauseAndReflectSheet` is presented.
- [ ] **PauseAndReflectSheet UI** — Bottom sheet renders correctly with header, 6 reason categories, multi-select (capped at 2), conditional follow-up question, "Continue" / "Done" footer, and "Not now" dismiss. Entrance animation uses staggered reason-card fade-in.
- [ ] **Pause & Reflect data persistence** — Selected reasons, custom text, and follow-up answer persist to `HabitReflections` table. Dismissing via "Not now" records nothing and does not re-prompt that day.
- [ ] **All theme tokens used** — Zero hardcoded colors, spacing, radii, durations, curves, or sizes in any widget file.
- [ ] **Offline works** — Everything functions with airplane mode on. No network calls.
- [ ] **No lint warnings** — `dart analyze` produces zero warnings.
- [ ] **Performance** — Dashboard scrolls at 60fps with 10+ habits. No frame drops on animations.

**STOP here and request user review before proceeding to Phase 3.**

---

### Phase 3: Statistics + Insights

**Scope:** Build the reflection/insights experience — the user can see their consistency over time through beautiful, calm visualizations, including patterns from their Pause & Reflect responses.

**Completion Criteria (ALL must be true):**

- [ ] **Overall heatmap renders** — GitHub-style heatmap showing last 3 months of data. Cells colored from `AppColors.heatmap[0..4]`. Animated entrance with wave fill pattern.
- [ ] **Streak display works** — Current and longest streaks shown. "Personal best!" badge appears when current ≥ longest. Zero-streak copy is encouraging, not punishing.
- [ ] **Weekly insights generate** — Auto-generated 2–3 sentence positive insight based on this week's data. Changes weekly.
- [ ] **Most common reasons card renders** — `MostCommonReasonsCard` displays ranked breakdown of reflection categories from last 30 days. Hidden when fewer than 3 reflection entries exist.
- [ ] **Completion trend chart** — Line chart via `fl_chart` showing last 30 days. Toggle between 7d/30d/90d. Bezier curves, smooth, minimal axes. Line draws from left to right on entrance.
- [ ] **Habit breakdown list** — Per-habit cards showing completion rate bar + streak. Tapping expands to show individual heatmap.
- [ ] **Monthly calendar view** — Clean calendar with completion dots. Swipe to change months. Today circled.
- [ ] **Statistics entrance animation** — All sections animate with staggered intervals (per §5.5).
- [ ] **Empty state** — Statistics shows warm message when no completion data exists. No empty charts rendered.
- [ ] **Streak calculation correct** — Unit tests verify streak counting, including edge cases: consecutive days, skipped days, recovery days (if implemented), month boundaries.
- [ ] **fl_chart dependency added** — Added to `pubspec.yaml`, imported only in statistics feature files.
- [ ] **No lint warnings** — `dart analyze` produces zero warnings.
- [ ] **Performance** — Statistics screen with 3 months of data renders without jank. Charts animate smoothly.

**STOP here and request user review before proceeding to Phase 4.**

---

## 10. Explicit Non-Goals

**Do NOT build any of the following in Phase 2 or Phase 3. They are future work.**

| Non-Goal | Reason |
|----------|--------|
| **Cloud sync / backup** | Phase 5. Requires auth, server, conflict resolution. Way too early. |
| **User accounts / authentication** | Phase 5+. No login, no signup, no Firebase. |
| **Social features** | Never planned. Tracely is a personal app. |
| **Gamification badges / points / levels** | Contradicts the emotional design philosophy. No pressure mechanics. |
| **Push notifications / reminders** | Phase 4. Requires platform-specific setup. |
| **Settings screen** | Phase 5. No theme customization, no data export yet. |
| **Onboarding flow** | Phase 4+. The reflection screen IS the onboarding for now. |
| **Dark mode** | Phase 5. The Stone & Sand palette is light-mode first. Dark mode is a full palette redesign. |
| **Habit templates / suggestions** | Phase 4+. For now, users type their own habit names. |
| **Widgets (iOS/Android home screen)** | Phase 5+. Requires native code. |
| **Analytics / telemetry** | Not planned. No tracking. Respect privacy. |
| **Multi-language / localization** | Phase 5+. English only for now. |
| **Habit grouping / sub-habits** | Adds complexity. Categories are sufficient grouping. |
| **Import from other apps** | Phase 5. |
| **Sound effects** | Phase 4+ (if §6.3 is approved). |
| **AI/ML pattern analysis on reflection data** | Collect first, analyze later. No AI until sufficient data exists across real usage. Schema is designed to support this later without migration. |

---

## Appendix A: File Creation Order

When building Phase 2, create files in this order to avoid import errors:

1. `lib/core/constants/app_strings.dart`
2. `lib/core/constants/quote_constants.dart`
3. `lib/core/extensions/date_extensions.dart`
4. `lib/core/extensions/context_extensions.dart`
5. `lib/data/database/tables/categories_table.dart`
6. `lib/data/database/tables/habits_table.dart`
7. `lib/data/database/tables/habit_completions_table.dart`
8. `lib/data/database/tables/daily_reflections_table.dart`
9. `lib/data/database/tables/habit_reflections_table.dart`
10. `lib/data/database/app_database.dart`
11. Run `dart run build_runner build --delete-conflicting-outputs`
12. `lib/data/database/daos/category_dao.dart`
13. `lib/data/database/daos/habit_dao.dart`
14. `lib/data/database/daos/completion_dao.dart`
15. `lib/data/database/daos/reflection_dao.dart`
16. `lib/data/services/database_service.dart` (Riverpod provider for DB singleton)
17. `lib/data/repositories/habit_repository.dart`
18. `lib/data/repositories/completion_repository.dart`
19. `lib/data/repositories/category_repository.dart`
20. `lib/core/utils/greeting_utils.dart`
21. `lib/core/utils/streak_calculator.dart`
22. `lib/core/widgets/tracely_card.dart`
23. `lib/core/widgets/tracely_empty_state.dart`
24. `lib/core/widgets/tracely_shimmer.dart`
25. `lib/core/widgets/section_header.dart`
26. `lib/core/widgets/animated_list_item.dart`
27. **Shell & Navigation:**
28. `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
29. `lib/features/dashboard/presentation/widgets/` (all 6 section widgets)
30. `lib/features/habits/presentation/screens/habits_screen.dart`
31. `lib/features/habits/presentation/screens/add_habit_screen.dart`
32. `lib/features/habits/presentation/screens/edit_habit_screen.dart`
33. `lib/features/habits/presentation/widgets/` (HabitTile, HabitCompletionCheckbox, CategoryPicker, FrequencySelector, etc.)
34. `lib/features/dashboard/presentation/widgets/pause_and_reflect_sheet.dart`
35. Update `lib/app/router/app_router.dart` with all new routes + ShellRoute
36. Update `lib/features/reflection/presentation/widgets/animated_continue_button.dart` to navigate to `/dashboard`
37. Theme extensions (add new tokens to existing files)
38. Run `dart analyze` — fix all issues
39. Manual testing of all flows

## Appendix B: Package Dependencies to Add

Add to `pubspec.yaml` for Phase 2:

```yaml
# No new packages needed for Phase 2 — all deps already in pubspec.yaml
```

Add to `pubspec.yaml` for Phase 3:

```yaml
dependencies:
  fl_chart: ^0.70.2           # Line charts for completion trends
  # flutter_heatmap_calendar — evaluate if needed or build custom
  # The heatmap may be simpler to build custom with a GridView + AppColors.heatmap
  # since the existing heatmap packages are often inflexible in styling.
  # Recommendation: Build a custom TracelyHeatmap widget using Wrap/GridView.
```

**Note on heatmap:** The `flutter_heatmap_calendar` package mentioned in the original spec may not offer sufficient styling control for the Stone & Sand palette. Recommend building a custom `TracelyHeatmap` widget using a `Wrap` or `GridView.builder` with `Container` cells colored from `AppColors.heatmap`. This gives full control over cell radius, spacing, animation, and the recovery-day overlay. Total implementation: ~100–150 lines for the widget + ~50 lines for the data mapping. Well worth the control it provides.

---

*End of plan. This document is the complete, self-contained specification for building Tracely from Phase 2 onward. Every widget, every animation, every database table, every emotional design decision is specified. Build beautifully.*
