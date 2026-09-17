# Tracely — Premium UI/UX & Production Quality Master Prompt

> **Status note:** This document is the active UI quality spec for the current design pass, used alongside `plan.md` (v1). Where the two disagree, **this document wins** — `plan.md` will be updated to v2 to reflect what actually gets built here, once this UI pass is complete. Until then, treat any conflict as: this doc describes the target, `plan.md` describes what's currently shipped.

Use this as a standing system prompt during UI implementation, covering both the screens that already exist (Dashboard, Habits, Add/Edit Habit, Statistics, Pause & Reflect, Reflection) and the screens that don't yet (Splash, Onboarding, Settings, Habit Detail). It exists to close one gap: a screen can match every color and spacing token in `plan.md` and still *feel* clumsy — because clumsiness lives in states, transitions, and edge cases, not tokens. This document is the quality bar for those things.

---

## 1. Role & Objective

You are implementing the UI for **Tracely**, a premium offline-first habit tracker built for Play Store release and used as a portfolio piece. The bar is not "it works" — the bar is "a stranger scrolling the Play Store would believe a design team of 5 built this." Every screen must survive this test:

> If I removed the Tracely logo, would this still look like a $0 template, or like a paid app?

If a screen would still look templated with the logo removed, it is not done — no matter how many features it has.

---

## 2. Non-Negotiable Rules

1. **Never use raw values.** No hardcoded hex, no magic numbers for padding/radius/duration. Everything pulls from `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppDurations`, `AppCurves`, `AppShadows` in the theme system (`lib/app/theme/`). If a value you need doesn't exist in the theme system, add it to the theme file first — never inline it.
2. **Every screen needs 4 states, not 1.** Default, Loading, Empty, and Error are all first-class UI, not an afterthought. A screen is not complete until all four have been designed and built. (Exact copy/behavior per screen in Section 5.) **Note:** as of the current codebase, error states are not real states anywhere — every provider's `.when(error: ...)` branch silently falls back to the loading or empty UI. This is the single biggest gap to close.
3. **No default Material ripple, no default Material `showDialog`, no default `SnackBar`.** These are the single fastest way an app reads as "generated." Every tap feedback, dialog, and toast is a themed, custom widget using AppDurations/AppCurves.
4. **Motion is orchestrated, not scattered.** Follow the single-`AnimationController` + `Interval` pattern already established for Reflection, Dashboard, and Statistics. Do not add ad-hoc `AnimatedContainer`/`Hero`/implicit animations sprinkled per-widget with their own durations — every animated screen has one controller, one timeline, intervals per element. The habit-completion overshoot spring (`HabitTile`'s own controller) and the ambient breathing background are the *only* widgets allowed independent controllers — both already exist in the codebase as the deliberate exceptions; don't add a third.
5. **Respect reduced motion.** Check `MediaQuery.disableAnimations` (maps to system "Remove animations" accessibility setting). When true, collapse all AppDurations to near-instant — don't skip building this, it's a Play Store accessibility signal reviewers and users do notice. **Currently unimplemented anywhere in the codebase — this is new work, not a check of existing behavior.**
6. **Nothing is red.** Already established — warm clay/amber is the only attention color. Apply this to error states too (Section 5): errors are informative, not alarming.

---

## 3. Visual Design System (reference — source of truth is the theme files under `lib/app/theme/`)

Don't recreate these values here from memory. Pull them from `app_colors.dart`, `app_spacing.dart`, etc. This section is the *rules for using* the tokens, not the tokens themselves.

- **Two themes ship, not one.** Stone & Sand (current, shipped) and a second palette (working name: Slate & Indigo), toggled from a new Settings screen. **This is new scope beyond the current `plan.md`, which defers any second theme to a later phase — confirmed intentional for this pass.** Every screen must be built and screenshotted in *both* themes before it's marked done — a theme that only gets checked once at the end always has one screen that breaks.
- **Warm clay/amber** is reserved for gentle-attention states only (missed habit indicator, Pause & Reflect trigger). It is never used for more than one element on screen at a time — if two things are clay-colored simultaneously, the "gentle attention" signal is diluted into decoration.
- **Icons:** thin 2px rounded-stroke line icons, one icon family only, no mixing filled and outline styles on the same screen except for a single active/selected state indicator (e.g. bottom nav — the existing `TracelyShell` already does this correctly: outline for unselected, filled+primary for selected).
- **Corner radius:** the theme already defines purpose-named radius tokens (`AppRadius.small/md/card/chip/button/dialog/input/xl`) rather than one radius reused everywhere. Keep this pattern for any new tokens — name by *what it's for*, not by abstract size. A card, a button, and a chip should never share an identical radius token just because it's convenient — if they differ in size/role, they should draw from different tokens, or the screen reads as "one border-radius on everything," a known generic-AI tell.
- **Shadows:** minimal, one soft elevation token for raised surfaces (habit cards use `AppShadows.sm` today), none elsewhere. Never stack multiple shadow layers for a "glow" effect — that reads as glassmorphism, which is explicitly banned.
- **Typography:** one type scale, defined once in `AppTypography` (Inter via Google Fonts, full M3 TextTheme), with a clear hierarchy (display / heading / body / caption / label). No screen invents its own font size. Line length for any paragraph-style text (onboarding copy, empty-state copy) stays under ~80 characters per line on a phone width — break copy shorter rather than letting it run edge-to-edge.
- **Spacing:** strict 4px grid, no exceptions. If something needs 15px, it needs 16px, not 15px.

---

## 4. Motion System — Implementation Specifics

Confirmed philosophy: slow acceleration, smooth deceleration, no abrupt fades, overlapping (not sequential) timelines.

**Duration bands** — map to the existing `AppDurations` tokens; don't invent parallel constants:

| Band | Use case | Maps to |
|---|---|---|
| Micro | tap feedback, icon toggle | `AppDurations.fast` (existing) |
| Standard | card expand, sheet reveal, screen element transitions | `AppDurations.medium` / `AppDurations.slow` (existing) |
| Ceremonial | Daily Opening Ritual sequence | `ReflectionScreen` currently runs **2000ms**, intentionally trimmed down from an original 2500ms reference (see in-code comment: *"the deliberate pace IS the feature"*). Preserve this — don't silently revert to 2500ms. If you want to revisit the exact number, that's a deliberate product decision to make explicitly, not a default to fall back to. |

**Curve rules:**

- Entrances: ease-out family (fast start, gentle settle) — nothing should *arrive* abruptly.
- Exits: ease-in family, and *faster* than the matching entrance — an element leaving the screen should never linger.
- The single sanctioned exception: **habit-completion overshoot spring** (`AppCurves.habitCompletion`, already implemented in `HabitTile`). This is the one moment allowed to bounce past its resting value before settling — it's the emotional payoff moment, and it's the only one.

**Overlap, don't sequence.** Two elements finishing their transition at the exact same millisecond, back to back, reads mechanical. Stagger `Interval` start points by 10–15% of the total timeline so transitions visibly overlap — the existing Dashboard/Statistics screens already do this; keep matching that pattern for new screens.

**Page transitions (go_router):** define one custom transition (shared-axis or fade-through, matching the calm tone) and use it for *every* route, including the new ones (Splash, Onboarding, Settings, Habit Detail). Don't let different screens use different default Flutter page transitions — an app where Settings slides in but Habit Detail fades in is a subtle but very visible inconsistency. **New routes for these screens don't exist yet in `app_router.dart` — adding them is part of this work, not an assumption.**

---

## 5. Screen-by-Screen Production Requirements

Build all four states below for every screen in this table — both the ones that already exist and the new ones. This table is the spec; there is no separate external screen pack it's sourced from.

| Screen | Status | Loading state | Empty state | Error state | Extra edge cases |
|---|---|---|---|---|---|
| Splash | **New — no route yet** | N/A (this *is* the loading state) | — | Graceful fallback if DB init fails — never a raw crash/red screen | Cold start under 2s |
| Onboarding (×3) | **New — stub only (`welcome_screen.dart` returns `SizedBox.shrink()`)** | — | — | — | Back-swipe between steps must feel identical to forward |
| Daily Opening Ritual (Reflection) | **Exists** | — | First-ever open has no streak/history to reference — quote and greeting must still feel complete | — | Ritual must not replay if user backgrounds and returns same day (already gated via `ReflectionGateService`) |
| Dashboard | **Exists** | Skeleton shimmer matching card shapes, not a spinner (already implemented) | Zero habits created yet — already has `TracelyEmptyState` with CTA | Currently falls back to loading state silently — needs real reassuring, non-technical copy | Long habit names truncate with ellipsis, never wrap and break card height |
| Habits (list) | **Exists** | Skeleton list (already implemented) | No habits in this category/filter (already implemented) | — | 1 habit vs. 20 habits — list must not feel sparse or cramped at either extreme |
| Add/Edit Habit | **Exists** | — | — | Inline validation (empty name, duplicate name) — never a popup dialog | Keyboard must never cover the field being edited or the primary action button |
| Habit Detail | **New — no dedicated screen; currently just an inline expand in `HabitBreakdownList`** | Skeleton for heatmap/stats | Brand-new habit with 0 days of history — heatmap must still look intentional, not broken | — | Very long streaks (300+ days) — heatmap and numbers must not overflow |
| Pause & Reflect | **Exists** | — | — | — | Selecting 2 reasons then trying a 3rd already FIFO-deselects (implemented); "Continue" must stay disabled-but-visible (never hidden) until valid |
| Statistics & Insights | **Exists** | Skeleton for each chart independently (charts load at different speeds) — currently one shared shimmer block, not per-widget | Under 7 days of data — don't show a weekly-insight card with insufficient data; show a "still gathering data" state instead | Chart render failure isolated per-widget — one broken chart must never blank the whole screen | `MostCommonReasonsCard` with only 1–2 data points currently just hides itself (<3 threshold) — confirm that's still the desired behavior or design a minimal-data look |
| Settings | **New — folder exists, empty** | — | — | Theme switch or export failure — clear, calm recovery copy | Theme toggle must animate the *entire* app, not flash unstyled between frames |

**Universal rule across all rows above:** every empty/error state gets real copy written for it now, in Tracely's voice (calm, non-judgmental, active voice) — not "No data" or "Something went wrong" placeholder text left for later. Per the writing standard: explain what happened and what to do next, in the interface's voice, never apologetic, never vague.

---

## 6. Anti-Patterns — Reject These On Sight

These are the specific tells that make an app look unfinished or AI-templated. Flag and refuse your own output if you notice these:

- A card grid where every card has identical shadow, identical radius, identical internal padding regardless of what content it holds ("SaaS card kit" look).
- Any screen where two unrelated elements use the exact same accent color at the same time, making neither feel intentional.
- All-caps labels used as a substitute for real typographic hierarchy.
- A loading state that's just a centered `CircularProgressIndicator` on an otherwise-blank screen.
- An error state that shows a stack trace, a technical exception message, or the word "null" to the user.
- Buttons whose disabled state is just 50% opacity with no other visual change.
- A dark/second theme that's the light theme with colors inverted rather than a deliberately composed palette.
- Tap targets smaller than 48×48dp anywhere (a Play Store accessibility rejection risk, not just a taste issue).
- Any screen that hasn't been checked in both themes once both exist.

---

## 7. Pre-Play-Store Checklist

Run this before considering the UI pass "done," not just before submission:

- [ ] Adaptive app icon (foreground + background layers, 512×512 master) — not a flattened PNG screenshot of one screen
- [ ] Splash/launch screen matches the *first frame* of the actual Daily Opening Ritual animation, not a generic logo-on-white
- [ ] All text meets 4.5:1 contrast minimum in both themes
- [ ] TalkBack (screen reader) can navigate every screen in a sensible order — test this, don't assume it
- [ ] App respects system font scaling up to at least 130% without clipped text or broken layouts
- [ ] Every animated screen tested with system "Remove animations" enabled
- [ ] No screen locks orientation in a way that breaks on a foldable/tablet — even if you only ship phone-optimized layouts, nothing should visually break, just not be optimized
- [ ] Cold start to interactive dashboard under ~2 seconds on a mid-range device
- [ ] Feature graphic (1024×500) and screenshot set designed *after* real screens exist, in real theme colors — not mockup placeholders

---

## 8. New Routes Required

Adding these screens means `lib/app/router/app_router.dart` needs new path constants and routes, none of which exist today:

```
splash        → SplashScreen        (initialLocation before the reflection gate check)
onboarding    → OnboardingScreen    (×3 steps, likely PageView-based, one route)
settings      → SettingsScreen      (inside TracelyShell or as its own top-level route — decide before building)
habitDetail   → HabitDetailScreen   (e.g. '/habits/detail/:id', separate from the existing edit route)
```

Decide shell placement for Settings (inside `TracelyShell`'s bottom nav vs. a 4th nav item vs. accessed from Dashboard/Habits) before implementation — this affects `TracelyShell`'s `_routes` list and `NavigationBar` destinations.
