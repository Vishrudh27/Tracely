import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/services/database_service.dart';

/// Settings — reachable from the profile avatar on Dashboard/Habits/
/// Statistics, not a bottom-nav tab (Tasks already occupies that slot).
///
/// Deliberately scoped to what's real: no fake account, theme picker, or
/// notification toggle, since none of those are backed by working features
/// yet. "Clear All Data" is the one action here that actually does
/// something.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes every habit, task, and completion. '
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
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(appDatabaseProvider).clearAllData();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All data cleared.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go(AppRouter.dashboard);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textSecondary,
                  ),
                  Text('Settings', style: context.textTheme.titleLarge),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                children: [
                  const SizedBox(height: AppSpacing.md),
                  _SectionCard(
                    label: 'DATA',
                    children: [
                      _SettingsRow(
                        icon: Icons.delete_forever_rounded,
                        label: 'Clear All Data',
                        iconColor: AppColors.error,
                        labelColor: AppColors.error,
                        onTap: () => _confirmClearData(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  const _AboutFooter(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.card,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: AppSpacing.card,
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: labelColor ?? AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: AppRadius.button,
          ),
          child: const Icon(
            Icons.all_inclusive_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Tracely', style: context.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '"Build habits. Build yourself."',
          style: context.textTheme.bodyMedium?.copyWith(
            color: AppColors.primary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
