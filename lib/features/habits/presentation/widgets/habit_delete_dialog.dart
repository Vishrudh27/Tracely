import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/theme.dart';

/// Shared destructive-delete confirmation, styled like Settings' Clear All
/// Data dialog. Not part of any Stitch mock — added on explicit request.
///
/// Returns true only if the user tapped "Delete".
Future<bool> confirmDeleteHabit(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
      title: const Text('Delete this habit?'),
      content: const Text(
        'This permanently removes it and all its history. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => context.pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
