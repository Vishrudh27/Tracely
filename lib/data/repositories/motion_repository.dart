import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/motion_service.dart';

/// Holds Settings' Reduce Motion state, delegating persistence to
/// [MotionService]. Mirrors [ReminderSettingsNotifier]'s shape.
class ReduceMotionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => MotionService.isEnabled();

  Future<void> setEnabled(bool enabled) async {
    await MotionService.setEnabled(enabled);
    state = AsyncData(enabled);
  }
}

final reduceMotionProvider =
    AsyncNotifierProvider<ReduceMotionNotifier, bool>(
  ReduceMotionNotifier.new,
);
