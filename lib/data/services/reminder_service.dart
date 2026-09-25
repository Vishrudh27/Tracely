import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

/// Schedules, cancels, and persists Tracely's one daily reminder.
///
/// A single static notification (id 0) — there's only ever one reminder, so
/// there's nothing to key by habit or date. Time is inexact
/// (`inexactAllowWhileIdle`): a daily nudge doesn't need to fire on the
/// second, and Android 14 denies the exact-alarm permission by default, so
/// asking for it would just add a permission prompt for no real benefit.
class ReminderService {
  ReminderService._();

  static const _notificationId = 0;
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily reminder';

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
