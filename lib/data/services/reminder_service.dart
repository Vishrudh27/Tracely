import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

/// Schedules, cancels, and persists Tracely's notifications.
///
/// Id 0 is the one app-wide daily nudge (Settings → Reminders). Per-habit
/// reminders use [habitNotificationId] and task reminders use
/// [taskNotificationId]. Everything is inexact (`inexactAllowWhileIdle`):
/// Android 14 denies the exact-alarm permission by default, so asking for it
/// would add a permission prompt for a few minutes of precision.
class ReminderService {
  ReminderService._();

  static const _notificationId = 0;
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily reminder';

  static const _itemDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'item_reminders',
      'Habit and task reminders',
      channelDescription: 'Reminders you set on a habit or task.',
    ),
  );

  static const _kEnabledKey = 'reminder_enabled';
  static const _kHourKey = 'reminder_hour';
  static const _kMinuteKey = 'reminder_minute';

  static const defaultHour = 8;
  static const defaultMinute = 30;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to UTC. Wrong hour beats no reminder at all, and this
      // only matters until the device's real zone can be read.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
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

  /// Brings one habit's reminder in line with [habit] — cancels every slot
  /// first so a daily ↔ specific-days switch needs no knowledge of the old
  /// schedule. Pass null when the habit is gone.
  static Future<void> syncHabitReminder(int habitId, Habit? habit) =>
      _quietly(() async {
        await _ensureInitialized();
        for (var slot = 0; slot < 8; slot++) {
          await _plugin.cancel(id: habitNotificationId(habitId, slot));
        }
        if (habit != null) await _scheduleHabit(habit);
      });

  /// Same as [syncHabitReminder] for a task's one-shot reminder.
  static Future<void> syncTaskReminder(int taskId, Task? task) =>
      _quietly(() async {
        await _ensureInitialized();
        await _plugin.cancel(id: taskNotificationId(taskId));
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

  static Future<void> _scheduleHabit(Habit h) async {
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

  static Future<void> _scheduleTask(Task t) async {
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
