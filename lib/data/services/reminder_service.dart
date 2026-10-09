import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../app/router/app_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/habit_schedule.dart';
import '../database/app_database.dart';

/// The saved state of the daily reminder — whether it's on, and what time.
class ReminderSettings {
  const ReminderSettings({required this.enabled, required this.hour, required this.minute});

  final bool enabled;
  final int hour;
  final int minute;

  /// "8:30 AM" — the exact format Settings' Reminder time row shows.
  String get timeLabel {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

/// Given the current moment and a target hour/minute, how many days from now
/// (0 = today, 1 = tomorrow) the next occurrence of that time falls.
///
/// Pure and platform-independent on purpose — the one piece of this feature
/// that's actually worth a unit test; scheduling, permissions, and the
/// plugin itself can't be.
int daysUntilNextOccurrence(DateTime now, int hour, int minute) {
  final todayAtTime = DateTime(now.year, now.month, now.day, hour, minute);
  return now.isBefore(todayAtTime) ? 0 : 1;
}

/// Notification id for one habit's reminder. Slot 0 = every day, 1–7 = that
/// weekday (Mon=1). habitId ≥ 1 means ids start at 8 — never the daily
/// nudge's 0.
int habitNotificationId(int habitId, int slot) => habitId * 8 + slot;

/// ponytail: collides once habit ids pass 125M; widen the base if that ever matters.
int taskNotificationId(int taskId) => 1000000000 + taskId;

/// Days from [now] until the next [weekday] (Mon=1) at hour:minute —
/// 0 if that's later today, 7 if today's slot already passed.
int daysUntilNextWeekday(DateTime now, int weekday, int hour, int minute) {
  final d = (weekday - now.weekday) % 7;
  if (d > 0) return d;
  return now.isBefore(DateTime(now.year, now.month, now.day, hour, minute))
      ? 0
      : 7;
}

/// When a task's one-shot reminder should fire, or null if it has no
/// date/time or that moment isn't after [now] (the plugin throws on a past
/// one-shot date).
DateTime? taskReminderAt(DateTime? dueDate, String? dueTime, DateTime now) {
  final minute = parseHhMm(dueTime);
  if (dueDate == null || minute == null) return null;
  final at = DateTime(
    dueDate.year,
    dueDate.month,
    dueDate.day,
    minute ~/ 60,
    minute % 60,
  );
  return at.isAfter(now) ? at : null;
}

/// Payload type constants carried in the alarm notification payload so the
/// tap handler (and the ring screen) know which item to display.
const _payloadTypeHabitAlarm = 'habit_alarm';
const _payloadTypeTaskAlarm = 'task_alarm';

/// Top-level callback required by flutter_local_notifications for background
/// action taps. Runs in a separate Dart isolate spawned just for this call —
/// Dart statics (including [AppRouter.router]) aren't shared across
/// isolates, so this must never try to navigate; `navigate: false` restricts
/// it to plugin-only calls (cancel/reschedule), which work fine here.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  ReminderService._handleAction(response, navigate: false);
}

/// Schedules, cancels, and persists Tracely's notifications.
///
/// Id 0 is the one app-wide daily nudge (Settings → Reminders). Per-habit
/// reminders use [habitNotificationId] and task reminders use
/// [taskNotificationId].
///
/// Soft notifications (default): `inexactAllowWhileIdle` — unchanged.
/// Call Reminder (opt-in): when a habit/task has `isAlarmReminder == true`,
/// uses native Android `NotificationCompat.CallStyle` channel via MethodChannel instead.
class ReminderService {
  ReminderService._();

  static const _notificationId = 0;
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily reminder';

  static const _callAlarmChannel = MethodChannel('com.tracely/call_alarm');

  // ── Soft habit/task reminder channel (unchanged) ──────────────────────────
  static const _itemDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'item_reminders',
      'Habit and task reminders',
      channelDescription: 'Reminders you set on a habit or task.',
    ),
  );

  // Call Reminder notifications (isAlarmReminder == true) are no longer
  // posted through this plugin at all — scheduling, the CallStyle
  // notification, and Snooze/Decline all live natively (see
  // android/.../CallAlarmFireReceiver.kt + CallAlarmActionReceiver.kt),
  // reached via _callAlarmChannel below.

  static const _kEnabledKey = 'reminder_enabled';
  static const _kHourKey = 'reminder_hour';
  static const _kMinuteKey = 'reminder_minute';

  static const defaultHour = 8;
  static const defaultMinute = 30;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Public initializer to setup local notifications at app launch.
  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      var id = info.identifier;
      if (id == 'Asia/Calcutta') id = 'Asia/Kolkata';

      try {
        tz.setLocalLocation(tz.getLocation(id));
      } catch (_) {
        final match = tz.timeZoneDatabase.locations.keys.firstWhere(
          (k) => k.toLowerCase() == id.toLowerCase(),
          orElse: () => '',
        );
        if (match.isNotEmpty) {
          tz.setLocalLocation(tz.getLocation(match));
        } else {
          final offset = DateTime.now().timeZoneOffset;
          final hours = offset.inHours;
          final locationName =
              hours >= 0 ? 'Etc/GMT-${hours.abs()}' : 'Etc/GMT+${hours.abs()}';
          try {
            tz.setLocalLocation(tz.getLocation(locationName));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('ReminderService timezone init error: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Native side pushes here the moment a Call Reminder intent lands on an
    // ALREADY-RUNNING MainActivity (app merely backgrounded, not killed —
    // e.g. tapping the heads-up banner from the home screen). The one-time
    // getPendingAlarmOpen() poll below only ever runs on this first
    // initialize() call, so it alone misses that case entirely — this
    // handler is what makes a warm app open the ring screen reliably
    // instead of "sometimes it just doesn't show full screen."
    _callAlarmChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmIntentReceived') {
        final args = call.arguments as Map?;
        final type = args?['type'] as String?;
        final id = (args?['id'] as num?)?.toInt();
        if (type != null && id != null) _pushAlarmRoute(type, id);
      }
    });

    _initialized = true;

    // Check if cold-started by a soft notification response
    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchDetails?.notificationResponse != null) {
        _onNotificationResponse(launchDetails!.notificationResponse!);
      }
    } catch (e) {
      debugPrint('ReminderService.initialize launch check error: $e');
    }

    // Check if cold-started by a native CallStyle alarm intent
    try {
      final pendingOpen = await _callAlarmChannel.invokeMapMethod<String, dynamic>('getPendingAlarmOpen');
      if (pendingOpen != null) {
        final type = pendingOpen['type'] as String?;
        final id = (pendingOpen['id'] as num?)?.toInt();
        if (type != null && id != null) _pushAlarmRoute(type, id);
      }
    } catch (e) {
      debugPrint('ReminderService.initialize native pending open check error: $e');
    }
  }

  static Future<void> _ensureInitialized() => initialize();

  static void _pushAlarmRoute(String type, int id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (type == _payloadTypeHabitAlarm) {
        AppRouter.router.push('/alarm/habit/$id');
      } else if (type == _payloadTypeTaskAlarm) {
        AppRouter.router.push('/alarm/task/$id');
      }
    });
  }

  /// Reverts the Activity to normal behavior so it stops being able to draw
  /// over the lock screen — called the instant the user acts on the ring
  /// screen (Mark Done / Snooze / Dismiss), never left on afterward. Without
  /// this, the next thing the Activity shows (the dashboard) draws right
  /// over the lock screen too, since the window flags are otherwise static.
  static Future<void> clearLockScreenFlags() async {
    try {
      await _callAlarmChannel.invokeMethod('clearLockScreenFlags');
    } catch (e) {
      debugPrint('ReminderService.clearLockScreenFlags failed: $e');
    }
  }

  /// Sends the whole app task behind whatever was showing before the ring
  /// screen (lock screen, home screen, or another app). Used instead of
  /// go_router navigation for the ring screen's own exit, so Mark Done /
  /// Snooze / Dismiss never flashes the dashboard first.
  static Future<void> exitAlarmScreen() async {
    try {
      await _callAlarmChannel.invokeMethod('moveTaskToBack');
    } catch (e) {
      debugPrint('ReminderService.exitAlarmScreen failed: $e');
    }
  }

  static void _onNotificationResponse(NotificationResponse response) {
    _handleAction(response, navigate: true);
  }

  /// Dispatches actions (Snooze / Dismiss action buttons) or full-screen
  /// opens. Always safe to call from the main isolate (foreground tap, or
  /// the cold-start replay in [initialize]) — see [notificationTapBackground]
  /// for why the background isolate must call [_handleAction] directly with
  /// `navigate: false` instead.
  static Future<void> handleNotificationAction(NotificationResponse response) =>
      _handleAction(response, navigate: true);

  static Future<void> _handleAction(
    NotificationResponse response, {
    required bool navigate,
  }) async {
    await _ensureInitialized();
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final id = data['id'] as int?;
      if (id == null || type == null) return;

      final actionId = response.actionId;

      if (actionId == 'snooze_action') {
        await cancelItemNotification(type, id);
        if (type == _payloadTypeHabitAlarm) {
          await snoozeHabitAlarm(id);
        } else if (type == _payloadTypeTaskAlarm) {
          await snoozeTaskAlarm(id);
        }
      } else if (actionId == 'dismiss_action') {
        await cancelItemNotification(type, id);
      } else if (navigate) {
        await cancelItemNotification(type, id);
        _pushAlarmRoute(type, id);
      }
    } catch (e) {
      debugPrint('ReminderService.handleNotificationAction error: $e');
    }
  }

  /// Loads the saved state — off, at 8:30 AM, until the user turns it on.
  static Future<ReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      enabled: prefs.getBool(_kEnabledKey) ?? false,
      hour: prefs.getInt(_kHourKey) ?? defaultHour,
      minute: prefs.getInt(_kMinuteKey) ?? defaultMinute,
    );
  }

  /// Turns the reminder on at the given time. Requests Android 13+'s
  /// notification permission first; if it's denied, nothing is scheduled or
  /// saved and the caller should leave its toggle off.
  static Future<bool> enable({required int hour, required int minute}) async {
    await _ensureInitialized();
    if (!await _requestPermission()) return false;

    await _schedule(hour, minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, true);
    await prefs.setInt(_kHourKey, hour);
    await prefs.setInt(_kMinuteKey, minute);
    return true;
  }

  static Future<void> disable() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, false);
  }

  /// Reschedules at a new time. Only meaningful while enabled — the caller
  /// is expected to only offer the time row when the toggle is already on.
  static Future<void> updateTime({required int hour, required int minute}) async {
    await _ensureInitialized();
    await _schedule(hour, minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHourKey, hour);
    await prefs.setInt(_kMinuteKey, minute);
  }

  /// Cancels the reminder and forgets its saved time — Clear All Data means
  /// "back to first install," and first install has no reminder set.
  static Future<void> reset() async {
    await _ensureInitialized();
    await _plugin.cancel(id: _notificationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEnabledKey);
    await prefs.remove(_kHourKey);
    await prefs.remove(_kMinuteKey);
  }

  /// Asks for Android 13+'s notification permission. False on denial or any
  /// plugin failure.
  static Future<bool> requestPermission() async {
    try {
      await _ensureInitialized();
      return await _requestPermission();
    } catch (e) {
      debugPrint('ReminderService.requestPermission failed: $e');
      return false;
    }
  }

  // ── Exact-alarm permission (Call Reminder) ─────────────────────────────────

  /// Returns true if the app can schedule exact alarms. Always true on
  /// non-Android platforms — nothing to ask there. False (soft-notification
  /// fallback) on any plugin failure, same convention as [requestPermission].
  static Future<bool> canScheduleExact() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return true;
      return await android.canScheduleExactNotifications() ?? false;
    } catch (e) {
      debugPrint('ReminderService.canScheduleExact failed: $e');
      return false;
    }
  }

  /// Opens the system "Alarms & reminders" settings page so the user can
  /// grant SCHEDULE_EXACT_ALARM. This is the only way to request it on
  /// Android 12+ — no in-app dialog is possible (OS restriction).
  static Future<void> requestExactAlarmPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('ReminderService.requestExactAlarmPermission failed: $e');
    }
  }

  /// Cancels any active notification for a habit or task (both plugin and native).
  static Future<void> cancelItemNotification(String type, int id) async {
    await _ensureInitialized();
    if (type == 'habit') {
      for (var slot = 0; slot < 8; slot++) {
        await _plugin.cancel(id: habitNotificationId(id, slot));
      }
      try {
        await _callAlarmChannel.invokeMethod('cancelCallAlarm', {'id': habitNotificationId(id, 0)});
      } catch (e) {
        debugPrint('ReminderService.cancelItemNotification native cancel error: $e');
      }
    } else {
      await _plugin.cancel(id: taskNotificationId(id));
      try {
        await _callAlarmChannel.invokeMethod('cancelCallAlarm', {'id': taskNotificationId(id)});
      } catch (e) {
        debugPrint('ReminderService.cancelItemNotification native cancel error: $e');
      }
    }
  }

  // ── Snooze helpers (Call Reminder) ────────────────────────────────────────

  /// Reschedules a habit's alarm 5 minutes from now (one-shot, no recurrence
  /// carried for this fire — [_scheduleHabitAlarm] re-syncs the real
  /// recurrence on the habit's next normal save). Routed through the same
  /// native CallStyle pipeline as the initial fire — this used to fall back
  /// to the old plugin-rendered notification, which looked wrong (no
  /// heads-up banner, no call UI) for a snoozed alarm.
  static Future<void> snoozeHabitAlarm(int habitId) => _quietly(() async {
        await _ensureInitialized();
        await cancelItemNotification('habit', habitId);
        final snoozeAt = tz.TZDateTime.now(tz.local).add(
          const Duration(minutes: 5),
        );
        await _callAlarmChannel.invokeMethod('scheduleCallAlarm', {
          'id': habitNotificationId(habitId, 0),
          'type': _payloadTypeHabitAlarm,
          'title': AppStrings.callReminderSnooze,
          'subtitle': AppStrings.callReminderHabitSubtitle,
          'triggerAtMillis': snoozeAt.millisecondsSinceEpoch,
          'recurrenceDays': null,
          'hour': snoozeAt.hour,
          'minute': snoozeAt.minute,
        });
      });

  /// Reschedules a task's alarm 5 minutes from now (one-shot). Same native
  /// CallStyle routing as [snoozeHabitAlarm] — see its doc comment.
  static Future<void> snoozeTaskAlarm(int taskId) => _quietly(() async {
        await _ensureInitialized();
        await cancelItemNotification('task', taskId);
        final snoozeAt = tz.TZDateTime.now(tz.local).add(
          const Duration(minutes: 5),
        );
        await _callAlarmChannel.invokeMethod('scheduleCallAlarm', {
          'id': taskNotificationId(taskId),
          'type': _payloadTypeTaskAlarm,
          'title': AppStrings.callReminderSnooze,
          'subtitle': AppStrings.callReminderTaskSubtitle,
          'triggerAtMillis': snoozeAt.millisecondsSinceEpoch,
          'recurrenceDays': null,
          'hour': snoozeAt.hour,
          'minute': snoozeAt.minute,
        });
      });

  // ── Sync / reschedule ──────────────────────────────────────────────────────

  /// Brings one habit's reminder in line with [habit] — cancels every slot
  /// first so a daily ↔ specific-days switch needs no knowledge of the old
  /// schedule. Pass null when the habit is gone.
  static Future<void> syncHabitReminder(
    int habitId,
    Habit? habit, {
    bool completedToday = false,
  }) =>
      _quietly(() async {
        await _ensureInitialized();
        await cancelItemNotification('habit', habitId);
        if (habit != null) {
          await _scheduleHabit(habit, completedToday: completedToday);
        }
      });

  /// Same as [syncHabitReminder] for a task's one-shot reminder.
  static Future<void> syncTaskReminder(int taskId, Task? task) =>
      _quietly(() async {
        await _ensureInitialized();
        await cancelItemNotification('task', taskId);
        if (task != null) await _scheduleTask(task);
      });

  /// Rebuilds every habit/task reminder from the database — after Clear All
  /// Data or a backup import. Leaves the daily nudge (id 0) alone.
  static Future<void> rescheduleAll(AppDatabase db) => _quietly(() async {
        await _ensureInitialized();
        for (final p in await _plugin.pendingNotificationRequests()) {
          if (p.id != _notificationId) await _plugin.cancel(id: p.id);
        }
        for (final h in await db.habitDao.getActiveHabits()) {
          await _scheduleHabit(h);
        }
        for (final t in await db.taskDao.watchAllTasks().first) {
          await _scheduleTask(t);
        }
      });

  /// A reminder failing must never fail the save that triggered it.
  static Future<void> _quietly(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      debugPrint('ReminderService: $e');
    }
  }

  // ── Internal scheduling ───────────────────────────────────────────────────

  static Future<void> _scheduleHabit(Habit h, {bool completedToday = false}) async {
    // Branch: if the habit has Call Reminder enabled, use the native alarm path.
    if (h.isAlarmReminder) {
      await _scheduleHabitAlarm(h, completedToday: completedToday);
      return;
    }

    // ── Original soft-notification path (unchanged) ───────────────────────
    final minute = parseHhMm(h.reminderTime);
    if (h.isArchived || !h.reminderEnabled || minute == null) return;
    final hour = minute ~/ 60;
    final min = minute % 60;
    // 2024-01-01 was a Monday, so day w of that week has weekday w.
    final weekdays = [
      for (var w = 1; w <= 7; w++)
        if (isScheduledOn(h.frequencyType, h.frequencyConfig, DateTime(2024, 1, w)))
          w,
    ];
    final now = _nowToMinute();

    if (weekdays.length == 7) {
      await _plugin.zonedSchedule(
        id: habitNotificationId(h.id, 0),
        title: h.name,
        body: AppStrings.habitReminderBody,
        scheduledDate: _at(now, daysUntilNextOccurrence(now, hour, min), hour, min),
        notificationDetails: _itemDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return;
    }
    for (final w in weekdays) {
      await _plugin.zonedSchedule(
        id: habitNotificationId(h.id, w),
        title: h.name,
        body: AppStrings.habitReminderBody,
        scheduledDate:
            _at(now, daysUntilNextWeekday(now, w, hour, min), hour, min),
        notificationDetails: _itemDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Native Alarm (Call Reminder) path for habits — schedules via MethodChannel
  /// to native Kotlin NotificationCompat.CallStyle pipeline.
  static Future<void> _scheduleHabitAlarm(Habit h, {bool completedToday = false}) async {
    final minute = parseHhMm(h.reminderTime);
    if (h.isArchived || !h.reminderEnabled || minute == null) return;
    final hour = minute ~/ 60;
    final min = minute % 60;
    final weekdays = [
      for (var w = 1; w <= 7; w++)
        if (isScheduledOn(h.frequencyType, h.frequencyConfig, DateTime(2024, 1, w)))
          w,
    ];
    if (weekdays.isEmpty) return;

    var now = _nowToMinute();
    if (completedToday) {
      // Already done for today — push the search past today's slot so a
      // completed habit's alarm doesn't fire later the same day.
      now = DateTime(now.year, now.month, now.day, 23, 59);
    }
    final daysAhead = weekdays.length == 7
        ? daysUntilNextOccurrence(now, hour, min)
        : daysUntilNextWeekday(now, weekdays.first, hour, min);
    final scheduledDate = _at(now, daysAhead, hour, min);

    try {
      await _callAlarmChannel.invokeMethod('scheduleCallAlarm', {
        'id': habitNotificationId(h.id, 0),
        'type': _payloadTypeHabitAlarm,
        'title': h.name,
        'subtitle': AppStrings.callReminderHabitSubtitle,
        'triggerAtMillis': scheduledDate.millisecondsSinceEpoch,
        'recurrenceDays': weekdays,
        'hour': hour,
        'minute': min,
      });
    } catch (e) {
      debugPrint('ReminderService._scheduleHabitAlarm native call error: $e');
    }
  }

  static Future<void> _scheduleTask(Task t) async {
    // Branch: if the task has Call Reminder enabled, use the native alarm path.
    if (t.isAlarmReminder) {
      await _scheduleTaskAlarm(t);
      return;
    }

    // ── Original soft-notification path (unchanged) ───────────────────────
    if (t.isDone) return;
    final at = taskReminderAt(t.dueDate, t.dueTime, DateTime.now());
    if (at == null) return;
    await _plugin.zonedSchedule(
      id: taskNotificationId(t.id),
      title: t.title,
      body: AppStrings.taskReminderBody,
      scheduledDate: tz.TZDateTime(
        tz.local,
        at.year,
        at.month,
        at.day,
        at.hour,
        at.minute,
      ),
      notificationDetails: _itemDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Native Alarm (Call Reminder) path for tasks — schedules via MethodChannel
  /// to native Kotlin NotificationCompat.CallStyle pipeline.
  static Future<void> _scheduleTaskAlarm(Task t) async {
    if (t.isDone) return;
    final at = taskReminderAt(t.dueDate, t.dueTime, DateTime.now());
    if (at == null) return;

    final scheduledDate = tz.TZDateTime(
      tz.local,
      at.year,
      at.month,
      at.day,
      at.hour,
      at.minute,
    );

    try {
      await _callAlarmChannel.invokeMethod('scheduleCallAlarm', {
        'id': taskNotificationId(t.id),
        'type': _payloadTypeTaskAlarm,
        'title': t.title,
        'subtitle': AppStrings.callReminderTaskSubtitle,
        'triggerAtMillis': scheduledDate.millisecondsSinceEpoch,
        'recurrenceDays': null,
        'hour': at.hour,
        'minute': at.minute,
      });
    } catch (e) {
      debugPrint('ReminderService._scheduleTaskAlarm native call error: $e');
    }
  }

  static DateTime _nowToMinute() {
    final now = tz.TZDateTime.now(tz.local);
    return DateTime(now.year, now.month, now.day, now.hour, now.minute);
  }

  static tz.TZDateTime _at(DateTime now, int daysAhead, int hour, int minute) =>
      tz.TZDateTime(tz.local, now.year, now.month, now.day + daysAhead, hour, minute);

  static Future<bool> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // not on Android — nothing to ask
    return await android.requestNotificationsPermission() ?? false;
  }

  static Future<void> _schedule(int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    final daysAhead = daysUntilNextOccurrence(
      DateTime(now.year, now.month, now.day, now.hour, now.minute),
      hour,
      minute,
    );
    final scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysAhead,
      hour,
      minute,
    );

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Time for your habits',
      body: "A gentle nudge to check in on today's habits.",
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'A daily nudge to check in on your habits.',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
