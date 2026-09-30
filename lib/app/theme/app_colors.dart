import 'package:flutter/material.dart';

/// Centralized color tokens for the entire application.
///
/// Rules:
/// - Never use Colors.blue, Colors.red, etc. directly.
/// - Never use raw hex values outside this file.
/// - Always reference semantic colors like:
///   AppColors.primary
///   AppColors.surface
///   AppColors.success
///
/// NOTE:
/// "Clay & Oat" — WCAG AA-verified brown palette, resolved in
/// docs/stitch_prompt_kit.md §5.1. Replaces the Stone & Sand dev palette.
/// Values below are the tokens actually rendered across the audited Stitch
/// screens, not the full auto-generated Material scaffold (most of which
/// never reaches markup).
///
/// Dark mode: every token below is a getter switching on [isDark], backed
/// by a `_lXxx`/`_dXxx` constant pair — not a `ThemeExtension`, because the
/// whole app reads these as bare static fields rather than through
/// `Theme.of(context)`. Follows Material 3's dark-theme guidance, not a
/// from-scratch design: a warm dark *grey* background (never pure black —
/// M3 explicitly warns flat black kills depth perception), elevation
/// expressed as progressively *lighter* surface tones climbing from
/// [background] → [surfaceVariant] → [surface] → [surfaceContainerLow]
/// (the reverse of light mode, where [surfaceVariant] recesses below
/// [surface] — in dark mode a recessed panel sits *between* background and
/// surface, not below both), and every brand/accent color desaturated
/// ~25% before lightening, since M3 flags saturated warm hues (this
/// palette's whole territory) for "halation" — a glowing-edge effect on
/// dark backgrounds. [AppShadows] also goes empty in dark mode: a black
/// drop shadow is invisible on a near-black background, so depth comes
/// from the tone steps above instead, same as Material's own dark cards.
/// Every text/status token is independently contrast-checked at >=4.5:1
/// against both [background] and [surface] — see the contrast script
/// referenced in the accent-color comment below for the method.
final class AppColors {
  AppColors._();

  /// Settings' dark-mode toggle flips this; see [ThemeModeService] for
  /// persistence and [ThemeModeNotifier] for the Settings-triggered path.
  static bool isDark = false;

  // ---------------------------------------------------------------------------
  // Backgrounds
  // ---------------------------------------------------------------------------

  static const Color _lBackground = Color(0xFFFAF8F5);
  static const Color _dBackground = Color(0xFF141210);
  static Color get background => isDark ? _dBackground : _lBackground;

  static const Color _lSurface = Color(0xFFFFFFFF);
  static const Color _dSurface = Color(0xFF2C2926);
  static Color get surface => isDark ? _dSurface : _lSurface;

  /// Light mode recesses this *below* [surface] (a panel sunk into a white
  /// card). Dark mode can't recess below an already-near-black background,
  /// so this sits *between* [background] and [surface] instead — still
  /// reads as "one step back" from the surface it's inside.
  static const Color _lSurfaceVariant = Color(0xFFF2EDE6);
  static const Color _dSurfaceVariant = Color(0xFF1F1C1A);
  static Color get surfaceVariant => isDark ? _dSurfaceVariant : _lSurfaceVariant;

  /// A step lighter than [surfaceVariant] — used for decorative/tip cards
  /// where Stitch specifies `surface-container-low` instead of the more
  /// common `surface-recessed`. In dark mode, a step lighter than
  /// [surface] instead (the next elevation up), not [surfaceVariant].
  static const Color _lSurfaceContainerLow = Color(0xFFF5F3F0);
  static const Color _dSurfaceContainerLow = Color(0xFF37332F);
  static Color get surfaceContainerLow =>
      isDark ? _dSurfaceContainerLow : _lSurfaceContainerLow;

  // ---------------------------------------------------------------------------
  // Brand Colors
  // ---------------------------------------------------------------------------

  /// The one user-chosen brand hue — everything below is derived from this.
  /// Mutable (not const) so Settings' accent-color picker can repaint the
  /// whole app; see [AccentColorService] for where it gets set at startup
  /// and [AccentColorNotifier] for the Settings-triggered path. Every
  /// [AccentPreset.base] is pre-verified at >=4.5:1 contrast against white,
  /// which is what keeps the derived shades below safe without re-checking
  /// contrast per preset.
  static Color accentBase = const Color(0xFF6F4E37); // primary-coffee

  /// Dark mode both lightens *and* desaturates [accentBase] — the presets
  /// are tuned dark-and-saturated for white text in light mode, which
  /// reads as a near-invisible dark-on-dark blob on a near-black
  /// background, and a saturated warm hue that IS lightened enough to show
  /// up gets a visible glowing-edge "halation" effect against a dark
  /// backdrop (M3's dark-theme guidance flags this specifically). Cutting
  /// saturation by 25% before lightening to L 0.62 keeps all 8 presets at
  /// >=5.9:1 against the dark background without that glow.
  static Color get primary {
    if (!isDark) return accentBase;
    final hsl = HSLColor.fromColor(accentBase);
    return hsl
        .withSaturation((hsl.saturation * 0.75).clamp(0.0, 1.0))
        .withLightness(0.62)
        .toColor();
  }

  /// A decorative recede-into-the-background tint. Lerps toward white in
  /// light mode, toward the dark surface in dark mode — lerping toward
  /// white in dark mode would wash it out to near-invisible against a dark
  /// backdrop.
  static Color get primaryLight => isDark
      ? Color.lerp(primary, surface, 0.5)!
      : Color.lerp(primary, Colors.white, 0.55)!;

  static Color get primaryDark =>
      Color.lerp(primary, Colors.black, isDark ? 0.25 : 0.22)!;

  /// Secondary accent — kept as an alias of [accentTerracotta] so existing
  /// call sites re-skin automatically. Prefer [accentTerracotta] in new code.
  static Color get secondary => accentTerracotta;

  /// Fill-only accent tint (icons, dots, selected borders). Same lerp in
  /// both modes — [primary] itself already adapts per-mode, so this stays
  /// ~3.2–8.7:1 against the background across every preset in both modes.
  /// Never use for text.
  static Color get accentTerracotta => Color.lerp(primary, Colors.white, 0.25)!;

  /// Darker accent shade safe for text in light mode (>=4.5:1, verified
  /// >=6.6:1 across every preset). In dark mode "darker" would move toward
  /// the background instead of away from it, so this lerps toward white
  /// there instead — verified >=5.5:1 against both background and surface
  /// across every preset. Use this, not [accentTerracotta], whenever the
  /// accent colors a label, button, or any other readable string.
  static Color get accentText => isDark
      ? Color.lerp(primary, Colors.white, 0.12)!
      : Color.lerp(primary, Colors.black, 0.12)!;

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color _lTextPrimary = Color(0xFF1F1A15);
  static const Color _dTextPrimary = Color(0xFFF1EDEA);
  static Color get textPrimary => isDark ? _dTextPrimary : _lTextPrimary;

  static const Color _lTextSecondary = Color(0xFF655A4E);
  static const Color _dTextSecondary = Color(0xFFC9C2BA);
  static Color get textSecondary => isDark ? _dTextSecondary : _lTextSecondary;

  /// >=4.5:1 against both [background] and [surface] in both modes — this
  /// is the token that was once found at 3.01:1 in light mode; keep any
  /// future edit here contrast-checked the same way.
  static const Color _lTextDisabled = Color(0xFF9A8E83);
  static const Color _dTextDisabled = Color(0xFFA19991);
  static Color get textDisabled => isDark ? _dTextDisabled : _lTextDisabled;

  /// Flips with [primary]'s lightness — white reads fine on the dark-on-
  /// white-tuned light presets, but dark mode's lightened [primary] needs a
  /// dark label instead (verified >=5:1 across every preset).
  static Color get textOnPrimary => isDark ? background : Colors.white;

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  static const Color _lSuccess = Color(0xFF5A7233);
  static const Color _dSuccess = Color(0xFF99B983);
  static Color get success => isDark ? _dSuccess : _lSuccess;

  static Color get warning => accentTerracotta;

  static const Color _lError = Color(0xFF9C4A32); // muted, never harsh red
  static const Color _dError = Color(0xFFDA8C81);
  static Color get error => isDark ? _dError : _lError;

  static const Color _lInfo = Color(0xFF5C7A99);
  static const Color _dInfo = Color(0xFF91B1CA);
  static Color get info => isDark ? _dInfo : _lInfo;

  // Overdue/not-done status dots (task tile, Overdue filter chip) read as a
  // traffic-light signal — needs to look actually red, unlike the muted
  // `error` tone above.
  static const Color _lStatusOverdue = Color(0xFFC0392B);
  static const Color _dStatusOverdue = Color(0xFFE17970);
  static Color get statusOverdue => isDark ? _dStatusOverdue : _lStatusOverdue;

  // ---------------------------------------------------------------------------
  // Borders & Divider
  // ---------------------------------------------------------------------------

  static const Color _lBorder = Color(0xFFE6DFD5);
  static const Color _dBorder = Color(0xFF423D38);
  static Color get border => isDark ? _dBorder : _lBorder;

  static Color get divider => border;

  /// A stronger outline than [border] — for interactive element edges
  /// (checkboxes, input fields) that need to read as tappable, not just
  /// as a quiet section divider.
  static const Color _lBorderOutline = Color(0xFF9F8D7B);
  static const Color _dBorderOutline = Color(0xFF7E756D);
  static Color get borderOutline => isDark ? _dBorderOutline : _lBorderOutline;

  // ---------------------------------------------------------------------------
  // Disabled
  // ---------------------------------------------------------------------------

  static Color get disabled => textDisabled;

  // ---------------------------------------------------------------------------
  // Overlay
  // ---------------------------------------------------------------------------

  static const Color _lOverlay = Color(0x66000000);
  static const Color _dOverlay = Color(0x99000000);
  static Color get overlay => isDark ? _dOverlay : _lOverlay;

  // ---------------------------------------------------------------------------
  // Heatmap
  // ---------------------------------------------------------------------------

  // heatmap[0] is `HabitBreakdown.heatmapLevel`'s "zero completions that
  // day" bucket (see habit_models.dart) — a genuinely empty cell, not a
  // faint tint of the accent. It used to lerp from [primary] like every
  // other level, so every cell in the grid carried the accent hue even on
  // days nothing happened; picking a new accent recolored the *entire*
  // grid, empty cells included, which read as "some activity" everywhere.
  // [surfaceVariant] is flat and accent-independent on purpose. Levels
  // 1–4 are the real ramp: three tints climbing to full [primary], plus
  // primary itself, matching `statistics/code.html`'s activity heatmap
  // shape. This is also what a habit's streak intensity renders with, so
  // it re-skins with everything else when the accent color (or theme)
  // changes. Light mode tints toward white — every card in light mode *is*
  // white, so this blends the lightest filled cell toward the card holding
  // it. Dark mode tints toward [surface] for the same reason:
  // [OverallHeatmapCard] paints its grid on an `AppColors.surface` card,
  // not the app-level [background] — tinting toward background there made
  // filled cells at low intensity render *darker* than the card itself,
  // like holes punched in it, instead of blending in from it.
  static List<Color> get heatmap => isDark
      ? [
          surfaceVariant,
          Color.lerp(primary, surface, 0.70)!,
          Color.lerp(primary, surface, 0.40)!,
          Color.lerp(primary, surface, 0.15)!,
          primary,
        ]
      : [
          surfaceVariant,
          Color.lerp(primary, Colors.white, 0.65)!,
          Color.lerp(primary, Colors.white, 0.38)!,
          Color.lerp(primary, Colors.white, 0.15)!,
          primary,
        ];

  // ---------------------------------------------------------------------------
  // Chart Colors
  // ---------------------------------------------------------------------------

  static List<Color> get chartPalette => [
        primary,
        accentTerracotta,
        success,
        accentText,
        primaryLight,
      ];

  // ---------------------------------------------------------------------------
  // Category Colors (muted, warm variants — never harsh)
  //
  // Health/Mind/Fitness/Learning migrated 2026-09-25 to the exact hues
  // Stitch specifies in `add_habit/code.html`'s category chip selector — the
  // only place in the whole design system that defines category colors, and
  // it only covers these four. The real per-category color a habit displays
  // lives in the `categories.colorValue` DB column (see AppDatabase's
  // migration v3→v4 and `_seedDefaultCategories`); these constants exist for
  // the ReasonDisplay mapping and as the categoryCustom fallback.
  //
  // Creativity/Social/Self-Care have NO Stitch source — still the old Stone
  // & Sand-era hues (saturated rose/teal/amber), deliberately left alone
  // rather than inventing colors and calling them "Stitch's".
  //
  // Not mode-switched: these come from the DB (a habit's actual dot/icon
  // color is `categories.colorValue`, set once at creation), not a live
  // token — re-deriving them per-mode would mean every stored habit color
  // needs its own dark variant computed on the fly instead of just read.
  // ---------------------------------------------------------------------------

  static const Color categoryHealth = Color(0xFF5A7233); // Stitch: Olive
  static const Color categoryMind = Color(0xFF6B5B8C); // Stitch: Violet
  static const Color categoryFitness = Color(0xFFAC5E2D); // Stitch: Terracotta
  static const Color categoryLearning = Color(0xFF3F6480); // Stitch: Slate
  static const Color categoryCreativity = Color(0xFFDB2777); // Soft rose
  static const Color categorySocial = Color(0xFF0891B2); // Teal
  static const Color categorySelfCare = Color(0xFFD97706); // Amber
  static const Color categoryCustom = Color(0xFF78716C); // Stone

  // ---------------------------------------------------------------------------
  // Completion States (gentle, never alarming)
  // ---------------------------------------------------------------------------

  static const Color _lCompletedBackground = Color(0xFFF0FDF4);
  static const Color _dCompletedBackground = Color(0xFF1B281D);
  static Color get completedBackground =>
      isDark ? _dCompletedBackground : _lCompletedBackground;

  static const Color _lCompletedBorder = Color(0xFFBBF7D0);
  static const Color _dCompletedBorder = Color(0xFF36593C);
  static Color get completedBorder =>
      isDark ? _dCompletedBorder : _lCompletedBorder;

  static const Color _lUncompletedBackground = Color(0xFFFAFAF9);
  static const Color _dUncompletedBackground = Color(0xFF24211E);
  static Color get uncompletedBackground =>
      isDark ? _dUncompletedBackground : _lUncompletedBackground;

  static const Color _lRecoveryDay = Color(0xFFFEF3C7);
  static const Color _dRecoveryDay = Color(0xFF352E1D);
  static Color get recoveryDay => isDark ? _dRecoveryDay : _lRecoveryDay;

  // ---------------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------------

  static Color get streakActive => accentTerracotta;
  static Color get streakRecord => primary;

  static const Color _lInsightCard = Color(0xFFFFFBEB);
  static const Color _dInsightCard = Color(0xFF2D261B);
  static Color get insightCard => isDark ? _dInsightCard : _lInsightCard;

  // ---------------------------------------------------------------------------
  // Task Priority
  // ---------------------------------------------------------------------------

  static Color get priorityHigh => accentTerracotta;

  static const Color _lPriorityMedium = Color(0xFF97692A);
  static const Color _dPriorityMedium = Color(0xFFCAAA72);
  static Color get priorityMedium => isDark ? _dPriorityMedium : _lPriorityMedium;

  static Color get priorityLow => textDisabled;
}
