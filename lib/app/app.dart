import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class TracelyApp extends StatelessWidget {
  const TracelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,

      title: 'Tracely',

      theme: AppTheme.lightTheme,

      routerConfig: AppRouter.router,
    );
  }
}
