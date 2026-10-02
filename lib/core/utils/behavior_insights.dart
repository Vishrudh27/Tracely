import '../extensions/date_extensions.dart';
import 'habit_schedule.dart';

/// Pause & Reflect reasons that mean "too tired" — the ones an earlier time
/// could plausibly fix.
const kEnergyReasonKeys = {'low_energy', 'poor_sleep', 'burned_out', 'needed_rest'};

/// The time of day a habit is usually ticked off, in minutes since midnight
/// — or null when there's too little data or it's too scattered to claim.
///
/// Median of the last [days] days' tap times, only when at least
/// [minSamples] exist and the middle half sits within [maxIqrMinutes].
/// ponytail: ignores midnight wrap — 23:50 + 00:10 reads as a wide spread,
/// so it stays silent rather than wrong.
int? usualCompletionMinute(
  Iterable<DateTime> completedAts, {
  required DateTime today,
  int days = 30,
  int minSamples = 5,
  int maxIqrMinutes = 90,
}) {
  final since = today.addDays(-(days - 1));
  final s = [
    for (final at in completedAts)
      if (!at.isBefore(since)) at.hour * 60 + at.minute,
  ]..sort();
  final n = s.length;
  if (n < minSamples) return null;
  if (s[3 * (n - 1) ~/ 4] - s[(n - 1) ~/ 4] > maxIqrMinutes) return null;
  return n.isOdd ? s[n ~/ 2] : ((s[n ~/ 2 - 1] + s[n ~/ 2]) / 2).round();
}

class HabitTimingInput {
  const HabitTimingInput({
    required this.habitId,
    required this.name,
    required this.reminderMinute,
    required this.completedAts,
    this.energyMisses = 0,
  });

  final int habitId;
  final String name;
  final int? reminderMinute;
  final List<DateTime> completedAts;

  /// How many energy-type miss reasons this habit has collected.
  final int energyMisses;
}

class BehaviorInsight {
  const BehaviorInsight({
    required this.key,
    required this.habitId,
    required this.message,
    this.suggestedMinute,
  });

  /// Stable id for dismissal — includes the suggested time, so a dismissed
  /// suggestion can come back if the pattern moves.
  final String key;
  final int habitId;
  final String message;

  /// When set, the card offers to move the habit's reminder here.
  final int? suggestedMinute;
}

/// The single most useful suggestion right now, or null.
///
/// Order: tired-at-a-late-reminder first, then reminder drift, then a plain
/// "you usually do this around…" for habits with no reminder. Dismissed
/// keys are skipped.
/// ponytail: miss reasons are bulk-applied to every missed habit by the
/// Pause & Reflect sheet, so the energy count is noisy — fine for a nudge.
BehaviorInsight? pickBehaviorInsight(
  List<HabitTimingInput> habits, {
  required DateTime today,
  required Set<String> dismissed,
}) {
  final miss = <BehaviorInsight>[];
  final drift = <BehaviorInsight>[];
  final usual = <BehaviorInsight>[];

  for (final h in habits) {
    final m = usualCompletionMinute(h.completedAts, today: today);
    if (m == null) continue;
    final s = ((m / 15).round() * 15) % (24 * 60);
    final at = clockLabel(s);
    final r = h.reminderMinute;

    if (r == null) {
      usual.add(BehaviorInsight(
        key: 'usual:${h.habitId}',
        habitId: h.habitId,
        message: 'You usually complete ${h.name} around $at.',
      ));
      continue;
    }
    if (r >= 20 * 60 && h.energyMisses >= 3 && r - s >= 60) {
      miss.add(BehaviorInsight(
        key: 'miss:${h.habitId}:${formatHhMm(s)}',
        habitId: h.habitId,
        message: 'You’ve often missed ${h.name} when tired. '
            'Try a reminder at $at instead?',
        suggestedMinute: s,
      ));
    }
    if ((s - r).abs() >= 60) {
      drift.add(BehaviorInsight(
        key: 'drift:${h.habitId}:${formatHhMm(s)}',
        habitId: h.habitId,
        message: 'You usually complete ${h.name} around $at. '
            'Move its reminder to $at?',
        suggestedMinute: s,
      ));
    }
  }

  for (final insight in [...miss, ...drift, ...usual]) {
    if (!dismissed.contains(insight.key)) return insight;
  }
  return null;
}
