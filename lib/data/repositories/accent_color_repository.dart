import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/force_repaint.dart';
import '../services/accent_color_service.dart';

/// Holds Settings' accent-color choice (the preset id), delegating
/// persistence to [AccentColorService]. Mirrors [ReduceMotionNotifier]'s
/// shape — [TracelyApp] watches this provider purely to force a full
/// rebuild (and thus re-read [AppColors]' now-mutable getters) whenever
/// the preset changes.
class AccentColorNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() => AccentColorService.loadPresetId();

  /// Live preview while the Settings slider is being dragged — no disk
  /// write, so it's cheap enough to call on every band the thumb crosses.
  void preview(String id) {
    AccentColorService.applyPreview(id);
    state = AsyncData(id);
  }

  /// Commits the choice once the drag (or tap) ends. [preview] already got
  /// most widgets to re-skin live; this is also the point where
  /// [forceFullRepaint] catches the const-widget stragglers (a divider's
  /// border color, say) that a plain provider rebuild leaves stale — see
  /// its doc. Skipped in [preview] itself since that fires up to 7x per
  /// drag and a full-tree walk on every step was what made the slider laggy
  /// before.
  Future<void> commit(String id) async {
    await AccentColorService.persist(id);
    state = AsyncData(id);
    forceFullRepaint();
  }
}

final accentColorProvider = AsyncNotifierProvider<AccentColorNotifier, String>(
  AccentColorNotifier.new,
);
