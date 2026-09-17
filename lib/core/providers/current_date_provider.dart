import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/date_extensions.dart';

/// Holds today's date, midnight-normalized.
///
/// Dashboard and statistics streams are long-lived — they outlive the calendar
/// day that created them. Reading `DateTime.now()` once when a stream is built
/// pins it to that day forever, so an app left open past midnight keeps
/// filtering on yesterday while writes land on today.
///
/// Watching this provider re-creates those streams when the day turns. It
/// re-checks on a timer aimed at the next midnight and whenever the app is
/// resumed, which covers the common case of the process being suspended
/// overnight and the timer never firing.
class CurrentDateNotifier extends Notifier<DateTime>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  DateTime build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    _scheduleNextMidnight();
    return DateTime.now().startOfDay;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshNow();
  }

  /// Re-reads the clock and pushes a new state if the day has changed.
  void refreshNow() {
    final today = DateTime.now().startOfDay;
    if (today != state) state = today;
    _scheduleNextMidnight();
  }

  void _scheduleNextMidnight() {
    _timer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // One second past the boundary so the clock has definitely rolled over.
    _timer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      refreshNow,
    );
  }
}

final currentDateProvider =
    NotifierProvider<CurrentDateNotifier, DateTime>(CurrentDateNotifier.new);
