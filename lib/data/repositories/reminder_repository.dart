import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reminder_service.dart';

export '../services/reminder_service.dart' show ReminderSettings;

/// Holds Settings' Daily reminder state, delegating the actual scheduling
/// and persistence to [ReminderService].
class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  @override
  Future<ReminderSettings> build() => ReminderService.loadSettings();

  /// Turns the reminder on or off. If turning on and the permission prompt
  /// is denied, state falls back to disabled rather than showing a toggle
  /// that lies about what's actually scheduled.
  ///
  /// Returns whether the requested state was actually achieved — false only
  /// means "tried to turn on, permission was refused," so the caller can
  /// tell the user why the toggle snapped back instead of leaving it looking
  /// broken.
  Future<bool> setEnabled(bool enabled) async {
    final current = state.asData?.value ??
        const ReminderSettings(
          enabled: false,
          hour: ReminderService.defaultHour,
          minute: ReminderService.defaultMinute,
        );

    if (!enabled) {
      await ReminderService.disable();
      state = AsyncData(current.copyWith(enabled: false));
      return true;
    }

    final granted = await ReminderService.enable(
      hour: current.hour,
      minute: current.minute,
    );
    state = AsyncData(current.copyWith(enabled: granted));
    return granted;
  }

  /// Changes the reminder time. Only actually reschedules when the reminder
  /// is currently on — the caller is expected to hide the time row otherwise.
  Future<void> setTime({required int hour, required int minute}) async {
    final current = state.asData?.value;
    if (current == null || !current.enabled) return;

    await ReminderService.updateTime(hour: hour, minute: minute);
    state = AsyncData(current.copyWith(hour: hour, minute: minute));
  }
}

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
  ReminderSettingsNotifier.new,
);
