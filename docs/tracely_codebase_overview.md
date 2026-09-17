# Tracely — Complete Codebase Overview

> **Purpose of this document:** This is a complete, detailed technical walkthrough of the Tracely Flutter habit tracker app. It covers every file, every class, every function, and every design decision implemented so far. Use this to continue development in a new session without losing any context.

---

## 1. Project Identity

- **App Name:** Tracely
- **Package name:** `habit_tracker`
- **Description:** Offline-first habit and task tracker with contextual habit insights.
- **Version:** 1.0.0+1
- **Dart SDK:** `^3.12.2`
- **Flutter SDK:** `^3.x` (uses Material 3)
- **Entry point:** `lib/main.dart`

---

## 2. Tech Stack and Dependencies

### Core Runtime
| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^3.3.2 | State management (providers, notifiers) |
| `go_router` | ^17.3.0 | Declarative routing with shell routes |
| `drift` | ^2.34.2 | Type-safe SQLite ORM (code-generated DAOs) |
| `sqlite3_flutter_libs` | ^0.6.0 | SQLite native binaries |
| `path_provider` | ^2.1.6 | Platform paths for DB file |
| `path` | ^1.9.1 | File path manipulation |
| `google_fonts` | ^8.1.0 | Inter typeface |
| `intl` | ^0.20.3 | Date formatting |
| `collection` | ^1.19.1 | Dart collection utilities |
| `logger` | ^2.7.0 | Debug logging |
| `fl_chart` | ^0.70.2 | Line charts (completion trend) |
| `shared_preferences` | ^2.3.0 | Lightweight key-value storage (reflection gate) |

### Dev Dependencies
| Package | Purpose |
|---|---|
| `drift_dev` + `build_runner` | Code generation for Drift DAOs and generated DB file |
| `riverpod_generator` | (declared, for future use) |
| `flutter_lints` | Lint rules |

---

## 3. Project Directory Structure

```
lib/
├── main.dart                        # App entry point
├── app/
│   ├── app.dart                     # Root widget (TracelyApp)
│   ├── config/
│   │   └── app_config.dart          # App-level config constants
│   ├── design_system/               # Component library (8 categories)
│   ├── router/
│   │   └── app_router.dart          # GoRouter configuration
│   ├── shell/
│   │   └── tracely_shell.dart       # Bottom navigation shell
│   └── theme/
│       ├── app_borders.dart
│       ├── app_colors.dart          # Full color token system
│       ├── app_curves.dart          # Named animation curves
│       ├── app_durations.dart       # Named animation durations
│       ├── app_gradients.dart
│       ├── app_icons.dart
│       ├── app_opacity.dart
│       ├── app_radius.dart          # Named border radii
│       ├── app_shadows.dart
│       ├── app_sizes.dart           # Named size tokens
│       ├── app_spacing.dart         # Named spacing tokens
│       ├── app_theme.dart           # MaterialTheme assembler
│       ├── app_typography.dart      # Google Fonts Inter text theme
│       └── theme.dart               # Barrel export for all theme tokens
├── core/
│   ├── constants/
│   │   ├── app_strings.dart         # ALL user-facing strings
│   │   └── quote_constants.dart     # 20 motivational quotes (day-deterministic)
│   ├── errors/                      # (empty — reserved)
│   ├── extensions/
│   │   ├── context_extensions.dart  # BuildContext shortcuts
│   │   └── date_extensions.dart     # DateTime manipulation utilities
│   ├── utils/
│   │   ├── greeting_utils.dart      # Time-based greeting logic
│   │   └── streak_calculator.dart   # Pure Dart streak math
│   └── widgets/
│       ├── animated_list_item.dart  # Reusable staggered fade+slide wrapper
│       ├── section_header.dart      # Reusable section title row
│       ├── tracely_card.dart        # Base card container
│       ├── tracely_empty_state.dart # Positive empty state widget
│       └── tracely_shimmer.dart     # Shimmer loading placeholder
├── data/
│   ├── database/
│   │   ├── app_database.dart        # Drift DB definition, migration, seeding
│   │   ├── app_database.g.dart      # Code-generated (build_runner)
│   │   ├── daos/
│   │   │   ├── category_dao.dart
│   │   │   ├── completion_dao.dart
│   │   │   ├── habit_dao.dart
│   │   │   └── reflection_dao.dart
│   │   └── tables/
│   │       ├── categories_table.dart
│   │       ├── daily_reflections_table.dart
│   │       ├── habit_completions_table.dart
│   │       ├── habit_reflections_table.dart
│   │       └── habits_table.dart
│   ├── models/
│   │   └── habit_models.dart        # Pure Dart domain models
│   ├── repositories/
│   │   └── habit_repository.dart    # Business logic + ALL Riverpod providers
│   └── services/
│       ├── database_service.dart    # appDatabaseProvider singleton
│       └── reflection_gate_service.dart
└── features/
    ├── analytics/presentation/
    │   ├── screens/statistics_screen.dart
    │   └── widgets/ (8 statistics widgets)
    ├── dashboard/presentation/
    │   ├── screens/dashboard_screen.dart
    │   └── widgets/ (7 dashboard widgets)
    ├── habits/presentation/
    │   ├── screens/ (add, edit, habits list)
    │   └── widgets/ (4 form widgets)
    ├── reflection/presentation/
    │   ├── screens/reflection_screen.dart
    │   └── widgets/ (5 reflection widgets incl. pause_and_reflect_sheet)
    ├── settings/        # empty — reserved
    └── tasks/           # empty — reserved
```

---

## 4. Entry Point and App Shell

### `lib/main.dart`
- Calls `WidgetsFlutterBinding.ensureInitialized()`
- Wraps app in `ProviderScope` (Riverpod requirement)
- Runs `TracelyApp`

### `lib/app/app.dart` — `TracelyApp`
- `StatelessWidget`
- Uses `MaterialApp.router` with `routerConfig: AppRouter.router`, `theme: AppTheme.lightTheme`, `title: 'Tracely'`, `debugShowCheckedModeBanner: false`

---

## 5. Routing — `AppRouter`

Uses `go_router` with a `ShellRoute` for the bottom nav and standalone routes outside it.

### Route Hierarchy
```
/                → ReflectionScreen   (outside shell — no bottom nav)
/dashboard       → DashboardScreen    (inside TracelyShell)
/habits          → HabitsScreen       (inside TracelyShell)
/habits/add      → AddHabitScreen     (outside shell — slides up from bottom)
/habits/edit/:id → EditHabitScreen    (outside shell — slides up from bottom)
/statistics      → StatisticsScreen   (inside TracelyShell)
```

### Path Constants
All `static const String` on `AppRouter`:
`reflection = '/'`, `dashboard = '/dashboard'`, `habits = '/habits'`, `addHabit = '/habits/add'`, `editHabit = '/habits/edit/:id'`, `statistics = '/statistics'`

### Key Behaviours
- **Reflection gate redirect:** `/` uses an `async redirect` calling `ReflectionGateService.shouldShowReflection()`. If `false`, redirects to `/dashboard`.
- **Custom transitions:** Reflection uses `FadeTransition` (280ms). Add/Edit uses `SlideTransition` from bottom (320ms, `easeOutCubic`). Shell routes use `NoTransitionPage`.

### `TracelyShell`
- `StatefulWidget` wrapping `child` in a `Scaffold` with `NavigationBar`.
- Three tabs: Home (Dashboard), Habits, Statistics.
- `activeIndex` derived from `GoRouterState.of(context).uri.toString()` via `_indexFromRoute()`.
- Tab switching calls `context.go(_routes[index])`.
- Content wrapped in `AnimatedSwitcher` with `FadeTransition` (`AppDurations.navigation`).
- `NavigationBar` elevation 0, indicator = `AppColors.primary.withValues(alpha: 0.12)`.

---

## 6. Theme System

All theme tokens in static `final class` singletons — no raw values in widgets.

### `AppColors`
**Stone and Sand** warm palette.
- `background`: `#FAF9F6` (warm off-white)
- `surface`: `#FFFFFF`
- `surfaceVariant`: `#F5F2EC`
- `primary`: `#B45309` (deep amber/brown)
- `primaryLight`: `#D97706`
- `primaryDark`: `#92400E`
- `secondary`: `#78716C`
- `textPrimary`: `#1C1917`
- `textSecondary`: `#78716C`
- `textDisabled`: `#A8A29E`
- `textOnPrimary`: `Colors.white`
- `success`: `#65A30D` (olive green)
- `border`: `#E7E5E4`
- `disabled`: `#D6D3D1`
- `heatmap`: List of 5 colors from empty `#F5F5F4` to full `#B45309`
- `chartPalette`: 5 chart colors
- 7 `category*` constants: Health=olive, Mind=violet, Fitness=orange, Learning=blue, Creativity=rose, Social=teal, SelfCare=amber
- `completedBackground`, `completedBorder`, `uncompletedBackground`, `recoveryDay`
- `streakActive`, `streakRecord`, `insightCard`

### `AppTypography`
Uses **Google Fonts Inter** via `GoogleFonts.interTextTheme()`.
Full Material 3 `TextTheme`: displayLarge(32/700) down to labelSmall(11/500).

### `AppSizes`
Named size tokens:
- Icons: `iconXs(12)` to `iconXxl(40)`
- `buttonHeight: 52`, `buttonSmallHeight: 40`
- `appBarHeight: 64`, `bottomNavigationHeight: 72`
- `chartHeight: 220`
- `progressRingSize: 120`, `progressRingStroke: 8`
- `completionCheckbox: 28`, `completionCheckboxRipple: 44`
- `weeklyHeatmapCellSize: 28`, `streakNumberSize: 48`

### `AppSpacing`
Named spacing + `EdgeInsets` shorthands: `screen`, `card`, `habitTile`, `chip`.

### `AppRadius`
Named `BorderRadius` constants: `small`, `md`, `card`, `chip`, `button`, `dialog`, `input`, `xl`.

### `AppCurves`
Named `Curve` constants: `navigation`, `list`, `shimmer`, `emphasizedDecelerate`, `habitCompletion`, etc.

### `AppDurations`
Named `Duration` constants: `fast`, `medium`, `slow`, `shimmer`, `navigation`, `habitComplete`, `breathe`.

### `AppShadows`
Named `List<BoxShadow>` constants: `sm`, `md`.

### `theme.dart`
Barrel export — one import gives access to all `AppColors.*`, `AppSizes.*`, `AppSpacing.*`, etc.

### `AppTheme`
Assembles `ThemeData.light()` with `useMaterial3: true`, `AppTypography.textTheme`, and all component themes.

---

## 7. Database Layer

### Architecture
Drift ORM. DB lives at `<documents>/tracely.db` opened via `NativeDatabase.createInBackground`.

### `AppDatabase`
- `@DriftDatabase` with all 5 tables + 4 DAOs
- Schema version **2**
- `AppDatabase()` — production; `AppDatabase.forTesting(executor)` — test
- `MigrationStrategy`:
  - `onCreate`: creates all tables + seeds 7 default categories
  - `onUpgrade` (v1→v2): adds `habitReflections` table
- `_seedDefaultCategories()`: Health, Mind, Fitness, Learning, Creativity, Social, Self-Care

### Tables

#### `Categories`
| Column | Type | Notes |
|---|---|---|
| `id` | int PK | auto-increment |
| `name` | text | 1–50 chars |
| `emoji` | text | 1–10 chars |
| `colorValue` | int | ARGB integer |
| `sortOrder` | int | default 0 |
| `isBuiltIn` | bool | default false |
| `isArchived` | bool | default false |
| `createdAt` | datetime | |

#### `Habits`
| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `name` | text | 1–100 chars |
| `emoji` | text? | nullable |
| `categoryId` | int | FK Categories.id |
| `frequencyType` | text | `'daily'` / `'specific_days'` / `'x_per_week'` |
| `frequencyConfig` | text? | JSON: null / `[1,3,5]` / `{"times":3}` |
| `reminderEnabled` | bool | default false |
| `reminderTime` | text? | `"HH:mm"` |
| `sortOrder` | int | default 0 |
| `isArchived` | bool | default false |
| `createdAt` | datetime | |
| `updatedAt` | datetime | |

#### `HabitCompletions`
| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `habitId` | int | FK Habits.id |
| `completedDate` | datetime | Midnight-normalized |
| `completedAt` | datetime | Actual tap timestamp |
| `isRecoveryDay` | bool | default false |
| UNIQUE | | `(habitId, completedDate)` |

#### `DailyReflections`
| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `reflectionDate` | datetime | Midnight-normalized |
| `shownQuote` | text? | Quote text |
| `moodRating` | int? | 1–5 |
| `note` | text? | Free text |
| `createdAt` | datetime | |
| UNIQUE | | `(reflectionDate)` |

#### `HabitReflections`
| Column | Type | Notes |
|---|---|---|
| `id` | int PK | |
| `habitId` | int | FK Habits.id |
| `missedDate` | datetime | Midnight-normalized |
| `reason` | text | e.g. `'low_energy,too_busy'` / `'custom'` / `'skipped'` |
| `followUpAnswer` | text? | Follow-up answer |
| `createdAt` | datetime | |

---

## 8. DAOs

### `HabitDao`
**Streams:**
- `watchActiveHabits()` — non-archived, ordered sortOrder → createdAt
- `watchHabitsByCategory(categoryId)` — filtered by category
- `watchArchivedHabits()` — archived, ordered updatedAt desc

**Futures:**
- `getHabitById(id)` → `Habit?`
- `getActiveHabits()` → `List<Habit>`
- `countActiveHabits()` → `int`

**Writes:**
- `insertHabit(companion)` → `int` (new ID)
- `updateHabit(companion)` → `bool`
- `archiveHabit(id)` — sets `isArchived=true`, updates `updatedAt`
- `restoreHabit(id)` — sets `isArchived=false`
- `reorderHabits(orderedIds)` — updates `sortOrder` in a single transaction

### `CompletionDao`
**Toggle:**
- `toggleCompletion(habitId, date)` — deletes if exists, inserts if not (idempotent)
- `isCompleted(habitId, date)` → `bool`

**Streams:**
- `watchCompletionsForDate(date)` → `Stream<List<HabitCompletion>>`
- `watchWeekCompletions(weekStart)` — 7-day window
- `watchRecentCompletions({limit})` — newest first

**Futures:**
- `getCompletionsForHabit(habitId, {since})` → `List<HabitCompletion>`
- `getAllCompletionsSince(since)` → `List<HabitCompletion>`
- `getCompletionsInRange(start, end)` → `List<HabitCompletion>`

### `CategoryDao`
**Reads:**
- `watchActiveCategories()` → `Stream<List<Category>>`
- `getActiveCategories()` → `Future<List<Category>>`
- `getCategoryById(id)` → `Future<Category?>`

**Writes:**
- `insertCategory(companion)` → `int`
- `updateCategory(companion)` → `bool`
- `archiveCategory(id)` — only for non-built-in categories

### `ReflectionDao`
**DailyReflections:**
- `getTodaysReflection()` → `DailyReflection?`
- `getReflectionForDate(date)` → `DailyReflection?`
- `watchRecentReflections({limit})` → `Stream<List<DailyReflection>>`
- `recordReflection({shownQuote, moodRating, note})` — upsert via `insertOnConflictUpdate`

**HabitReflections:**
- `hasShownPauseAndReflectToday()` → `bool` — any row today = true
- `hasHabitReflection(habitId, date)` → `bool`
- `watchMostCommonReasons({limit})` → `Stream<List<ReasonFrequency>>` — GROUP BY reason ORDER BY COUNT DESC
- `createHabitReflection({habitId, missedDate, reason, followUpAnswer})` — idempotent
- `_normalizeDate(date)` — midnight normalization helper

**`ReasonFrequency`:** `{String reason, int count}`

---

## 9. Domain Models (`habit_models.dart`)

Pure Dart — no Flutter, no Drift. What the repository returns to the UI.

**`HabitWithCompletion`:** habitId, name, emoji (fallback to category emoji), categoryName, categoryEmoji, categoryColorValue, frequencyType, frequencyConfig, isCompletedToday, sortOrder

**`DailyProgress`:** completedCount, totalCount, `percentage` (getter 0.0–1.0), `allDone`, `noneDone`, `isEmpty`, `remaining` getters

**`DayCompletion`:** date, completionPercentage, isRecoveryDay, `heatmapLevel` getter (0–4)

**`CompletionWithHabit`:** completionId, habitId, habitName, habitEmoji, completedAt, completedDate

**`StreakData`:** currentStreak, longestStreak, lastCompletedDate?, `isPersonalBest` getter

**`DailyCompletion`:** date, percentage (trend chart data point)

**`HabitBreakdown`:** habitId, name, emoji, categoryColorValue, completionRate (last 30d), currentStreak, longestStreak, totalCompletions, `isPersonalBest` getter

**`WeeklyInsight`:** message, weeklyCompletionRate, mostConsistentDay?, bestHabitName?

---

## 10. Services

### `DatabaseService`
```dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

### `ReflectionGateService`
Controls morning gate logic.
- `static Future<bool> shouldShowReflection()` — checks `hour < 12` AND SharedPreferences key not set for today
- `static Future<void> markShown()` — stores today as `"YYYY-MM-DD"` in SharedPreferences
- `static String _dateKey(date)` — ISO date key builder

---

## 11. Repository — `HabitRepository`

Single point of contact between UI and database. Constructor: `HabitRepository(this._habitDao, this._completionDao, this._categoryDao)`

### Dashboard Streams

**`watchTodaysHabits()`** — Merges habits + today's completions via `StreamController`. Only emits when both have loaded. Filters by `_isHabitScheduledForDay()`. Maps to `HabitWithCompletion` with category joined.

**`watchTodaysProgress()`** — Same dual-stream pattern. Returns `DailyProgress`.

**`watchWeeklyHeatmap()`** — Async generator. Listens to 7-day completions. Computes `DayCompletion` per day.

**`watchRecentCompletions({limit})`** — Async generator. Joins each completion with habit + category.

**`toggleCompletion(habitId)`** — Delegates to `completionDao.toggleCompletion(habitId, today)`.

### Statistics Streams

**`watchHeatmapData({months})`** — Builds `Map<DateTime, double>`. Re-emits on completion changes. `_buildHeatmapData(since, until)` groups by date and calculates ratio.

**`watchCompletionTrend({days})`** — Re-emits on completion changes. `_buildTrend()` produces one `DailyCompletion` per day.

**`watchHabitBreakdowns()`** — Re-emits on active habit changes. `_buildHabitBreakdowns()` computes last-30d completions, all-time, scheduled days, streak via `StreakCalculator`. Sorted by completionRate desc.

**`watchOverallStreak()`** — All completions since 2020, deduped by date, runs `StreakCalculator`.

**`watchWeeklyInsight()`** — Computes rate, most active day, best habit → `_buildInsightMessage()` → natural language string.

### Other Methods

**`getMissedHabitsForDate(date)`** — Loads all scheduled habits for `date`, filters out completed ones. Used for Pause and Reflect gate.

**`getDaysSinceStart()`** — Oldest habit createdAt → days since then.

**`getHabitStreakData(habitId)`** — Single-habit streak.

**`_isHabitScheduledForDay(habit, day)`** — `'daily'` always true; `'specific_days'` JSON-decodes config and checks weekday; `'x_per_week'` always true.

### All Riverpod Providers

```dart
// Singletons
appDatabaseProvider          // Provider<AppDatabase>
habitRepositoryProvider      // Provider<HabitRepository>
reflectionDaoProvider        // Provider<ReflectionDao>

// Dashboard
todaysHabitsProvider         // StreamProvider<List<HabitWithCompletion>>
todaysProgressProvider       // StreamProvider<DailyProgress>
weeklyHeatmapProvider        // StreamProvider<List<DayCompletion>>
recentCompletionsProvider    // StreamProvider<List<CompletionWithHabit>>
activeHabitsProvider         // StreamProvider<List<Habit>>
categoriesProvider           // StreamProvider<List<Category>>

// Statistics
heatmapDataProvider          // StreamProvider<Map<DateTime, double>>
trendDaysProvider            // NotifierProvider<TrendDaysNotifier, int> (7/30/90)
completionTrendProvider      // StreamProvider<List<DailyCompletion>>
habitBreakdownsProvider      // StreamProvider<List<HabitBreakdown>>
overallStreakProvider        // StreamProvider<StreakData>
weeklyInsightProvider        // StreamProvider<WeeklyInsight>
daysSinceStartProvider       // FutureProvider<int>
mostCommonReasonsProvider    // StreamProvider<List<ReasonFrequency>>
```

**`TrendDaysNotifier extends Notifier<int>`:** Default state 30. `select(int days)` called by chip toggle.

---

## 12. Core Utilities

### `StreakCalculator`
Pure Dart, stateless, fully testable.

- `currentStreak(completionDates)` — sorts/deduplicates; streak alive if last was today or yesterday; walks backwards counting consecutive days.
- `longestStreak(completionDates)` — finds longest run in all-time history.
- `_sortedUniqueDays(dates)` — deduplicates by `"y-m-d"` key, normalizes to midnight, sorts.
- `needsCompletionToday(completionDates)` — true if last was not today.
- `completionRate(completedDays, totalDays)` — ratio clamped 0.0–1.0.

### `GreetingUtils`
- `greeting()` — "Good Morning" / "Good Afternoon" / "Good Evening" by hour
- `dashboardSubtitle({currentStreak})` — streak-aware subtitle
- `motivationFooter(pool)` — deterministic daily rotation by `dayOfYear % pool.length`

### `DateExtensions` (on `DateTime`)
- `isSameDay(other)`, `isToday`, `isYesterday`
- `startOfDay` (midnight), `startOfWeek` (Monday), `endOfWeek` (Sunday), `startOfMonth`, `endOfMonth`
- `relativeLabel` — "Today" / "Yesterday" / "N days ago"
- `weekNumber` — ISO week 1–53

Also `NullableDateExtensions` on `DateTime?` with `isToday`.

### `ContextExtensions` (on `BuildContext`)
- `theme`, `textTheme`, `colorScheme`
- `screenSize`, `screenWidth`, `screenHeight`
- `viewPadding`, `viewInsets`
- `canPop`

### `QuoteConstants`
- 20 motivational quotes (Aristotle, Maxwell, Confucius, Tracely originals, etc.)
- `todaysQuote()` — deterministic by `dayOfYear % quotes.length`

### `AppStrings`
All user-facing strings (never inline in widgets). Covers: app name/tagline, greetings, dashboard section labels, progress copy, 8-item `motivationFooter` list, empty state titles/bodies/CTAs, habits form labels, frequency options, archive dialog strings, statistics labels, day abbreviations, navigation labels.

---

## 13. Core Reusable Widgets

### `AnimatedListItem`
Staggered fade+slide entrance for list items.
- Params: `controller`, `index`, `totalItems`, `child`, `intervalStart`, `intervalEnd`, `slideOffsetY` (default 20)
- Computes per-item `Interval` from `intervalStart..intervalEnd` with 60% overlap.
- `AnimatedBuilder` with cached `child` to avoid subtree rebuilds per frame.

### `TracelyEmptyState`
Centered icon + title + body + optional CTA. Always warm, positive copy — never "No data".

### `TracelyShimmer`
Shimmer loading placeholder. Repeating `AnimationController` drives a moving `LinearGradient` from -2 to +2 across the container.

### `TracelyShimmerLine`
Convenience wrapper over `TracelyShimmer` for text-line placeholders.

### `SectionHeader`
Section title row with optional trailing widget.

### `TracelyCard`
Base card with standard surface color, border, radius, shadow.

---

## 14. Feature: Dashboard

### `DashboardScreen`
`ConsumerStatefulWidget` with `SingleTickerProviderStateMixin`. Single `AnimationController` of 950ms.

**Entrance animation intervals:**
1. Greeting: fade `0.0–0.20`, slide `0.0–0.25` (20px)
2. Progress card: fade `0.10–0.40`, slide `0.10–0.45` (24px)
3. Habits header: fade `0.25–0.45`, slide `0.25–0.50` (20px)
4. Weekly heatmap: fade `0.50–0.75`, slide `0.50–0.78` (20px)
5. Recent activity: fade `0.65–0.85`, slide `0.65–0.88` (16px)
6. Footer: fade `0.80–1.0`
7. Momentum nudge: fade `0.85–1.0`

**`initState`:** forwards controller + calls `_checkPauseAndReflect()` post-first frame.

**`_checkPauseAndReflect()`:** loads missed habits for yesterday, checks `hasShownPauseAndReflectToday()`, shows `PauseAndReflectSheet` if conditions met.

**States:** loading (shimmer placeholders), empty (`TracelyEmptyState` with "Add First Habit" CTA), loaded (`CustomScrollView` with `SliverList`).

**Momentum nudge (§6.7):** Shows `"Almost there — just N left."` italic text when `60% ≤ progress < 100%`.

Watches: `todaysHabitsProvider`, `todaysProgressProvider`, `weeklyHeatmapProvider`, `recentCompletionsProvider`.

### `BreathingBackground`
Ambient `RadialGradient` pulsing opacity 0.03→0.08 on 6-second repeating cycle. Color adapts to `weeklyCompletionRate` (high=amber, medium=primary, low=neutral). Has its own controller (exception to single-controller rule). Wrapped in `IgnorePointer`.

### `DailyProgressCard`
Circular progress ring via `_ProgressRingPainter` (`CustomPainter`). Ring fill animates 0→actual within `Interval(0.20, 0.55)`. Shows completed/total count and motivational copy. Displays "N left" or "All done!".

### `HabitTile`
Most complex widget — two controllers (`TickerProviderStateMixin`):
- `_checkController` (AppDurations.habitComplete) — 4-phase checkbox animation
- `_pressController` (120ms) — tile press scale 1.0→0.97

**Checkbox animation phases:**
1. `checkScaleAnim` — `TweenSequence` bounce: 1.0→0.82→1.12→1.0
2. `fillColorAnim` — `ColorTween` border→success `Interval(0.10, 0.75)`
3. `glowOpacityAnim` + `glowScaleAnim` — glow ring expands + fades `Interval(0.15, 0.70/0.75)`
4. `textColorAnim` — textPrimary→textSecondary `Interval(0.10, 0.85)`
5. `checkmarkOpacityAnim` — checkmark fades in with slight rotation `Interval(0.45, 0.80)`
6. `borderColorAnim` — tile border morphs `Interval(0.15, 0.85)`
7. `bgColorAnim` — background morphs to `completedBackground` `Interval(0.15, 0.85)`
8. `tileScaleAnim` — press feedback 0.97 scale

`_handleTap()` triggers `HapticFeedback.mediumImpact()`, press + check animation, and `widget.onToggle()`. `didUpdateWidget` syncs animation state.

Inner classes: `_AnimatedCheckbox` (concentric glow rings + checkbox circle + checkmark icon), `_CategoryDot` (colored circle).

### Other Dashboard Widgets
- **`DashboardGreetingSection`** — time-based greeting + subtitle, receives `opacity`/`translateY`.
- **`WeeklyHeatmapPreview`** — 7-day colored strip, day labels, tap → Statistics.
- **`RecentActivitySection`** — completions list with emoji + name + relative timestamp.
- **`DashboardMotivationFooter`** — daily rotating motivational phrase.

---

## 15. Feature: Habits Management

### `HabitsScreen`
Filter by category chips + active/archived toggle. FAB navigates to `AddHabitScreen`. `HabitManagementTile` navigates to `EditHabitScreen`.

### `AddHabitScreen`
Full-screen form sliding up from bottom.
- State: `_nameController`, `_selectedCategory`, `_frequencyType`, `_specificDays`, `_selectedEmoji`, `_isSaving`
- `_canSave` getter: name non-empty AND category selected
- `_save()` builds `frequencyConfig` JSON, calls `habitDao.insertHabit()`
- Save button text: **"Start Building"** (warm UX copy, not "Save")

### `EditHabitScreen`
Identical to Add but pre-populated.
- `_isLoaded` guard prevents double-init on rebuilds
- `_save()` calls `habitDao.updateHabit()`
- `_archive()` shows `AlertDialog` confirmation → `habitDao.archiveHabit()`

### Form Widgets
- **`CategoryPicker`** — scrollable grid of category chips, selection highlighted
- **`FrequencySelector`** — toggles daily/specific_days/x_per_week; specific_days shows M-T-W-T-F-S-S chips
- **`EmojiPickerGrid`** — grid of emoji options; tapping selected emoji deselects
- **`HabitManagementTile`** — management list tile showing emoji, name, category, frequency

---

## 16. Feature: Morning Reflection

### `ReflectionScreen`
`ConsumerStatefulWidget` with `SingleTickerProviderStateMixin`. 2000ms controller.

`initState` after first frame:
1. Forwards controller
2. `ReflectionGateService.markShown()` — prevents re-show
3. `QuoteConstants.todaysQuote()` → persists to `DailyReflections` via `db.reflectionDao.recordReflection()`

Stack: `ReflectionBackground` → `AnimatedGreeting` → `AnimatedQuoteCard` → `AnimatedContinueButton`

### Reflection Widgets
- **`ReflectionBackground`** — animated background during 2s entrance
- **`AnimatedGreeting`** — `Interval(0.0, 0.55)` — greeting fades in, moves to top
- **`AnimatedQuoteCard`** — `Interval(0.45, 0.80)` — slides up + glows; shows quote + author
- **`AnimatedContinueButton`** — `Interval(0.80, 1.00)` — appears; on press `context.go(AppRouter.dashboard)`

---

## 17. Feature: Pause and Reflect (Missed Habits)

### `PauseAndReflectSheet`
Modal bottom sheet (82% screen height). Shown from `DashboardScreen._checkPauseAndReflect()`.

**Reason taxonomy (5 categories):**
- Energy (🌱): Low Energy, Poor Sleep, Felt Sick, Burned Out
- Time (⏰): Too Busy, Unexpected Work, Meetings, Family Responsibilities
- Mind (🧠): Lost Motivation, Procrastinated, Forgot, Felt Overwhelmed, Couldn't Focus
- Environment (🌍): Traveling, Weather, No Equipment, Outside Home
- Personal (❤️): Needed Rest, Mental Break, Personal Event, Emergency

**Follow-up questions** (conditional per first matching reason key):
- `low_energy` → "How was your energy?" (Great/Okay/Very Low)
- `poor_sleep` → "How did you sleep?" (Badly/Okay/Well)
- `too_busy` → "What kept you busy?" (Work/College/Family/Other)
- `lost_motivation` → "Has this been going on?" (Just today/A few days/A while)
- `felt_overwhelmed` → "Was it habit-related?" (Yes/No/Not sure)

**Key behaviours:**
- Max 2 selections, **FIFO** (oldest removed when 3rd added)
- "My Reason" free-text field for custom input
- "Not now" dismiss — zero friction
- Staggered entrance: 700ms controller distributed across 5 categories
- `_submit()` builds reason string (`'low_energy,too_busy'` / `'custom'` / `'skipped'`), calls `createHabitReflection()` per missed habit, non-fatal error handling
- `_CategorySection` inner widget; `_ReasonChip` as `AnimatedContainer` chip

---

## 18. Feature: Analytics / Statistics

### `StatisticsScreen`
`ConsumerStatefulWidget` with `SingleTickerProviderStateMixin`. 1200ms controller.

**8 animated sections:**
1. `StatisticsHeader` — `0.00–0.15`
2. `OverallHeatmapCard` — `0.08–0.40` + wave fill `0.15–0.40`
3. `StreakDisplayCard` — `0.25–0.50` + count-up `0.30–0.50`
4. `WeeklyInsightsCard` — `0.35–0.55`
5. `MostCommonReasonsCard` — `0.40–0.57` (hidden if fewer than 3 entries)
6. `CompletionTrendChart` — `0.45–0.75` + line draw `0.52–0.75`
7. `HabitBreakdownList` — `0.60–0.82` (per-item stagger)
8. `MonthlyCalendarView` — `0.72–0.95` + scale `0.97→1.0`

Empty state shown if `heatmapData.isEmpty`.

### Statistics Widgets
- **`StatisticsHeader`** — "Your Journey" + days since start
- **`OverallHeatmapCard`** — 3-month grid, `AppColors.heatmap[level]` cells, `waveProgress` animation
- **`StreakDisplayCard`** — currentStreak (count-up), longestStreak, personal best badge
- **`WeeklyInsightsCard`** — `WeeklyInsight.message` on `AppColors.insightCard` background
- **`MostCommonReasonsCard`** — hidden < 3 entries; top N reasons with bars/chips
- **`CompletionTrendChart`** — `fl_chart` line chart, `drawProgress` clipping mask for left-to-right draw; 7/30/90 day toggle
- **`HabitBreakdownList`** — sorted per-habit list with completion rate bars + streak info, staggered
- **`MonthlyCalendarView`** — current month calendar grid, day cells colored from heatmap

---

## 19. Animation Architecture

Rules followed across the entire codebase:

1. **Single `AnimationController` per screen** — only `BreathingBackground` and `TracelyShimmer` have independent controllers (for ambient/looping).
2. **`Interval` slices** — each section gets its own `Interval` within the parent 0.0–1.0 range.
3. **`AnimatedBuilder` with cached child** — `child` param prevents subtree rebuilds per frame.
4. **`WidgetsBinding.instance.addPostFrameCallback`** — controllers forward after first frame.
5. **Staggered lists** — `AnimatedListItem` distributes items with 60% overlap for natural feel.

---

## 20. State Management Pattern (Riverpod)

- **`StreamProvider`** — reactive DB data; auto-updates UI on Drift stream emission.
- **`FutureProvider`** — one-shot reads (`daysSinceStartProvider`).
- **`Provider`** — synchronous singletons (`appDatabaseProvider`, `habitRepositoryProvider`).
- **`NotifierProvider`** — mutable state (`TrendDaysNotifier`).
- `ref.watch()` in `build()` for subscriptions; `ref.read()` in callbacks for writes.

---

## 21. Data Flow Summary

```
SQLite (tracely.db)
  → Drift ORM (type-safe queries)
  → DAOs (HabitDao, CompletionDao, CategoryDao, ReflectionDao)
  → HabitRepository (stream merging, business logic, domain mapping)
  → Riverpod Providers (StreamProvider / FutureProvider)
  → ConsumerWidget / ConsumerStatefulWidget
  → Feature Screens and Widgets
```

---

## 22. Key Design Principles in Code

1. **Offline-first** — zero network calls; all data is local SQLite.
2. **Soft deletes** — habits archived via `isArchived`, never hard-deleted.
3. **Unique constraints** — one completion per habit per day; one reflection per day.
4. **Idempotent operations** — `toggleCompletion` safe to call twice; `createHabitReflection` skips duplicates.
5. **Non-fatal reflection errors** — wrapped in try/catch; never blocks the user.
6. **Warm, positive UX copy** — all strings in `AppStrings`, never punishing language.
7. **Deterministic daily content** — quotes/footer rotate by `dayOfYear % pool.length`, not random.
8. **No raw colors/sizes in widgets** — always `AppColors.*`, `AppSizes.*`, `AppSpacing.*`, `AppRadius.*`.
9. **No inline strings** — always `AppStrings.*`.

---

## 23. What Is Not Yet Built (Placeholders)

- `lib/features/settings/` — empty, settings screen not implemented
- `lib/features/tasks/` — empty, tasks feature not started
- `welcome_screen.dart` — stub returning `SizedBox.shrink()`
- `lib/core/errors/` — empty, custom error types not defined
- `reminderEnabled` / `reminderTime` — schema exists but no notification logic
- `moodRating` / `note` in DailyReflections — schema exists, no UI for manual entry
- `isRecoveryDay` in HabitCompletions — schema exists, recovery logic not implemented

---

## 24. Build and Run

```bash
# After changing tables/DAOs — regenerate Drift code
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

Database file: `<documents directory>/tracely.db` — created automatically on first launch.

---

*Every class, method, widget, provider, table, and design decision documented here reflects the actual current source code in the `lib/` directory.*
