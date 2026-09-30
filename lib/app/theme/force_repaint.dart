import 'package:flutter/widgets.dart';

/// Forces every mounted [Element] to rebuild, bypassing Flutter's normal
/// skip-if-the-widget-is-identical optimization.
///
/// Most of this app reads [AppColors] as bare static fields inside
/// `build()` methods rather than through `Theme.of(context)`. A `const`
/// widget whose `build()` reads one of those fields (e.g. `_RowDivider`
/// reading `AppColors.border`) produces the exact same canonical widget
/// instance on every rebuild, so Flutter's reconciler sees
/// `identical(oldWidget, newWidget)` and skips calling `build()` again —
/// it would stay frozen in whatever theme/accent it first painted in.
/// Call this right after flipping [AppColors.isDark] or
/// [AppColors.accentBase]. Not a `reassemble()`-based approach (that's
/// stripped in release builds); this walks the live element tree directly,
/// so it works in both debug and release.
void forceFullRepaint() {
  void visit(Element element) {
    element.markNeedsBuild();
    element.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
}
