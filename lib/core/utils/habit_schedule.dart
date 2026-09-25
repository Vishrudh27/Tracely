import 'dart:convert';

import '../extensions/date_extensions.dart';

const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Human-readable label for a habit's `frequencyType`/`frequencyConfig`
/// pair — "Daily", "Mon to Fri", "Mon, Wed, Fri", or "Custom".
///
/// Shared by the Habits list and Habit Detail so both describe a habit's
/// schedule the same way.
String frequencyLabel(String frequencyType, String? frequencyConfig) {
  switch (frequencyType) {
    case 'daily':
      return 'Daily';
    case 'specific_days':
      if (frequencyConfig == null) return 'Daily';
      try {
        final days = (jsonDecode(frequencyConfig) as List).cast<int>().toList()
          ..sort();
        if (days.length == 5 &&
            days.first == 1 &&
            days.last == 5 &&
            days.every((d) => d >= 1 && d <= 5)) {
          return 'Mon to Fri';
        }
        return days.map((d) => _dayAbbr[d - 1]).join(', ');
      } catch (_) {
        return 'Daily';
      }
    case 'x_per_week':
      return 'Custom';
    default:
      return 'Daily';
  }
}

/// Whether a habit is meant to be done on [day].
///
/// Only `specific_days` narrows the schedule; everything else (including a
/// malformed config) counts every day, so a habit is never silently hidden.
bool isScheduledOn(String frequencyType, String? frequencyConfig, DateTime day) {
  if (frequencyType != 'specific_days' || frequencyConfig == null) return true;
  try {
    return (jsonDecode(frequencyConfig) as List).contains(day.weekday);
  } catch (_) {
    return true;
  }
}

/// Percentage of this habit's *scheduled* days in the last [days] that were
/// completed, as a whole number 0–100.
///
/// Days before [createdDay] and days the habit isn't scheduled for are left
/// out of both sides of the ratio — otherwise a perfect Mon–Fri habit would
/// score 71%.
int recentCompletionRate({
  required String frequencyType,
  required String? frequencyConfig,
  required DateTime today,
  required DateTime createdDay,
  required Set<DateTime> completedDays,
  int days = 30,
}) {
  var scheduled = 0;
  var hits = 0;
  for (var i = 0; i < days; i++) {
    final day = today.addDays(-i);
    if (day.isBefore(createdDay)) break;
    if (!isScheduledOn(frequencyType, frequencyConfig, day)) continue;
    scheduled++;
    if (completedDays.contains(day)) hits++;
  }
  return scheduled == 0 ? 0 : (hits / scheduled * 100).round();
}
