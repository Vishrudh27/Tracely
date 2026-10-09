import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/services/database_service.dart';
import '../../../../data/services/reminder_service.dart';

/// Full-screen alarm ring UI shown when a Call Reminder notification fires.
///
/// Incoming-call aesthetic built from Tracely's own "Clay & Oat" brand hue
/// ([AppColors.accentBase]) rather than a generic blue/slate palette. The
/// background (and the handful of white/black overlay tones it forces —
/// header chip, close button, title/subtitle text) follows the app's own
/// light/dark setting ([AppColors.isDark]); the accent-colored elements
/// (pulsing badge/glow, time chip, Snooze, Mark Done) stay exactly as
/// designed regardless of theme — those were already using the user's own
/// chosen accent color, not a hardcoded dark-mode palette.
class AlarmRingScreen extends ConsumerStatefulWidget {
  const AlarmRingScreen({super.key, required this.type, required this.id});

  /// 'habit' or 'task'
  final String type;

  /// The habit or task id.
  final int id;

  @override
  ConsumerState<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends ConsumerState<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  // ── Accent palette — the user's own chosen accent, unaffected by theme.
  // Buttons/glow/badge/time-chip all key off these — left exactly as they
  // were, per instruction: only the background follows light/dark. ──────
  static Color get _accent => AppColors.accentBase;
  static Color get _accentLight =>
      HSLColor.fromColor(_accent).withLightness(0.62).withSaturation(0.55).toColor();
  static const Color _snoozeBg = Color(0xFF3A2F28);
  static const Color _snoozeIcon = Color(0xFFD9A463);
  static const Color _doneGreen = Color(0xFF99B983); // AppColors dark success

  // ── Background + the overlay tones it forces — these follow the app's
  // light/dark setting. Dark keeps the exact values already used; light
  // mirrors AppColors' own light palette (_lBackground/_lSurfaceVariant)
  // so the screen matches the rest of the app instead of a hardcoded hue. ─
  static bool get _isDark => AppColors.isDark;
  static Color get _bgTop =>
      _isDark ? const Color(0xFF1C1512) : const Color(0xFFFAF8F5);
  static Color get _bgMid =>
      _isDark ? const Color(0xFF2A1F19) : const Color(0xFFF2EDE6);
  static Color get _onBg => _isDark ? Colors.white : Colors.black87;
  static Color get _onBgSecondary => _isDark ? Colors.white70 : Colors.black54;
  static Color get _onBgTertiary => _isDark ? Colors.white60 : Colors.black45;
  static Color get _overlayChipBg =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);
  static Color get _overlayChipBorder =>
      _isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
  static Color get _overlayButtonBg =>
      _isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);

  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  bool _stopping = false; // prevents double-stop races

  // ── Resolved display data ─────────────────────────────────────────────────
  String _title = '';
  String _subtitle = '';
  String _scheduledTime = '';
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );
    _pulseOpacity = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    // Ringtone + vibration are owned natively from the moment the alarm
    // fires (AlarmRingtonePlayer), not from when this screen opens — so the
    // heads-up banner rings too, before the user ever taps it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDisplayData();
    });
  }

  Future<void> _loadDisplayData() async {
    if (widget.type == 'habit') {
      final db = ref.read(appDatabaseProvider);
      final habit = await db.habitDao.getHabitById(widget.id);
      if (!mounted) return;
      setState(() {
        _title = habit?.name ?? 'Habit reminder';
        _subtitle = AppStrings.callReminderHabitSubtitle;
        if (habit?.reminderTime != null) {
          final parts = habit!.reminderTime!.split(':');
          final m = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          _scheduledTime = _formatMinutes(m);
        }
        _isLoaded = true;
      });
    } else {
      final db = ref.read(appDatabaseProvider);
      final task = await db.taskDao.getTaskById(widget.id);
      if (!mounted) return;
      setState(() {
        _title = task?.title ?? 'Task reminder';
        _subtitle = AppStrings.callReminderTaskSubtitle;
        if (task?.dueTime != null) {
          final parts = task!.dueTime!.split(':');
          final m = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          _scheduledTime = _formatMinutes(m);
        }
        _isLoaded = true;
      });
    }
  }

  static String _formatMinutes(int minuteOfDay) {
    final h = minuteOfDay ~/ 60;
    final m = minuteOfDay % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h % 12 == 0 ? 12 : h % 12;
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }

  Future<void> _stopAlarm() async {
    if (_stopping) return;
    _stopping = true;
    try {
      // Cancels the notification AND stops the native ringtone/vibration
      // (AlarmRingtonePlayer.stop(), wired into cancelCallAlarm).
      await ReminderService.cancelItemNotification(widget.type, widget.id);
      await ReminderService.clearLockScreenFlags();
    } catch (_) {}
  }

  Future<void> _safeExit() async {
    // Clear this screen out of the nav stack FIRST, while still foreground
    // and definitely mounted — not after backgrounding, where context can
    // be unreliable and leave the ring screen as the resumed route next
    // time the app is reopened.
    if (mounted) {
      try {
        context.go('/dashboard');
      } catch (_) {}
    }
    // Then hide the app behind the lock screen / home screen / whatever
    // was there before.
    await ReminderService.exitAlarmScreen();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  Future<void> _snooze() async {
    await _stopAlarm();
    if (widget.type == 'habit') {
      await ReminderService.snoozeHabitAlarm(widget.id);
    } else {
      await ReminderService.snoozeTaskAlarm(widget.id);
    }
    await _safeExit();
  }

  Future<void> _markDone() async {
    // "Will Complete" is an acknowledgement of the reminder, not a
    // completion — it must NOT touch habit/task done-state or stats.
    await _stopAlarm();
    HapticFeedback.mediumImpact();
    await _safeExit();
  }

  Future<void> _dismiss() async {
    await _stopAlarm();
    await _safeExit();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _dismiss();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgMid, _bgTop],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeaderRow(),
                Expanded(child: _buildCenterContent()),
                _buildActionDock(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _overlayChipBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _overlayChipBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _accentLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'INCOMING REMINDER',
                  style: GoogleFonts.inter(
                    color: _onBgSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _dismiss,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _overlayButtonBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFFE05A4E),
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PulsingHeroBadge(
          scale: _pulseScale,
          opacity: _pulseOpacity,
          accent: _accent,
          accentLight: _accentLight,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        AnimatedOpacity(
          opacity: _isLoaded ? 1.0 : 0.0,
          duration: AppDurations.medium,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text(
                  _title,
                  style: GoogleFonts.inter(
                    color: _onBg,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _subtitle,
                style: GoogleFonts.inter(
                  color: _onBgTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (_scheduledTime.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _accentLight.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    _scheduledTime,
                    style: GoogleFonts.inter(
                      color: _accentLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionDock() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundCallActionButton(
            onTap: _snooze,
            icon: Icons.snooze_rounded,
            label: AppStrings.callReminderSnooze,
            backgroundColor: _snoozeBg,
            iconColor: _snoozeIcon,
            labelColor: _onBgSecondary,
            size: 68,
          ),
          const SizedBox(width: AppSpacing.xl),
          _RoundCallActionButton(
            onTap: _markDone,
            icon: Icons.check_rounded,
            label: AppStrings.callReminderMarkDone,
            backgroundColor: _doneGreen,
            iconColor: _bgTop,
            labelColor: _doneGreen,
            size: 80,
          ),
        ],
      ),
    );
  }
}

class _PulsingHeroBadge extends StatelessWidget {
  const _PulsingHeroBadge({
    required this.scale,
    required this.opacity,
    required this.accent,
    required this.accentLight,
  });

  final Animation<double> scale;
  final Animation<double> opacity;
  final Color accent;
  final Color accentLight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scale,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale.value * 1.35,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: opacity.value * 0.25),
                ),
              ),
            ),
            Transform.scale(
              scale: scale.value * 1.18,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: opacity.value * 0.4),
                ),
              ),
            ),
            Transform.scale(
              scale: scale.value,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accentLight, accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  size: 54,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoundCallActionButton extends StatelessWidget {
  const _RoundCallActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.labelColor,
    this.size = 68,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final Color labelColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: size * 0.45, color: iconColor),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
