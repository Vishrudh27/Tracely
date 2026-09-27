import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/theme/app_durations.dart';
import 'data/services/motion_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read once before the first frame so nothing animates at full speed and
  // then jumps to zero a beat later.
  AppDurations.reduceMotion = await MotionService.isEnabled();

  runApp(const ProviderScope(child: TracelyApp()));
}
