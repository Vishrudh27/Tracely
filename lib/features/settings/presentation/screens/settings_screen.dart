import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/theme.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../data/repositories/reminder_repository.dart';
import '../../../../data/services/database_service.dart';
import '../../../../data/services/reminder_service.dart';

/// Settings — the four Stitch sections plus a Danger Zone.
///
/// Most rows here describe features that don't exist yet (themes, reduce
/// motion, reminders, export/import, feedback). They're rendered greyed and
/// say so when tapped rather than being dropped, so the screen matches
/// `settings/code.html` and the roadmap stays visible. "Clear All Data" is
/// the one real action, and is the one row Stitch doesn't have.
///
/// Reachable via a settings gear on the Dashboard header (added 2026-09-25,
/// not in Stitch — the profile avatar that used to open it was removed as
/// un-Stitch once every tab was rebuilt exact).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Kept in step with `version:` in pubspec.yaml by hand — reading it at
  /// runtime would mean adding package_info_plus for one string.
  static const _appVersion = '0.1.0';

  void _notReady(BuildContext context, String feature) =>
      _showMessage(context, '$feature — coming soon.');

  void _showMessage(BuildContext context, String message) {
    // Shared by every greyed row and the reminder-time guard, so clear the
    // queue first — otherwise tapping a few of them stacks up 20s of
    // snackbars.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

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
    // Clear All Data means "back to first install" — a first install has no
    // reminder scheduled either.
    await ReminderService.reset();
    ref.invalidate(reminderSettingsProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All data cleared.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go(AppRouter.dashboard);
  }

  Future<void> _toggleReminder(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final achieved =
        await ref.read(reminderSettingsProvider.notifier).setEnabled(value);
    // Only a denied permission looks like this: asked to turn on, and it
    // didn't. Once Android stops showing the system prompt after repeated
    // denials, the toggle would otherwise just silently snap back with no
    // explanation.
    if (value && !achieved && context.mounted) {
      _showMessage(
        context,
        'Notifications are off for Tracely. Turn them on in system settings.',
      );
    }
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null) return;
    await ref
        .read(reminderSettingsProvider.notifier)
        .setTime(hour: picked.hour, minute: picked.minute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderAsync = ref.watch(reminderSettingsProvider);
    // Falls back to "off, 8:30 AM" for the one frame before the saved state
    // loads — same appearance the row always had, so there's no flash.
    final reminder = reminderAsync.asData?.value ??
        const ReminderSettings(
          enabled: false,
          hour: ReminderService.defaultHour,
          minute: ReminderService.defaultMinute,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _SettingsHeader(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                children: [
                  const _SectionLabel('APPEARANCE', topPadding: AppSpacing.lg),
                  _SectionCard(
                    children: [
                      _SettingsRow(
                        label: 'Theme',
                        value: 'Clay & Oat',
                        enabled: false,
                        onTap: () => _notReady(context, 'Other themes'),
                      ),
                      const _RowDivider(),
                      _SettingsRow(
                        label: 'Reduce motion',
                        enabled: false,
                        trailing: const _SettingsSwitch(value: false),
                        onTap: () => _notReady(context, 'Reduce motion'),
                      ),
                    ],
                  ),
                  const _SectionLabel('REMINDERS'),
                  _SectionCard(
                    children: [
                      Semantics(
                        toggled: reminder.enabled,
                        child: _SettingsRow(
                          label: 'Daily reminder',
                          trailing: _SettingsSwitch(value: reminder.enabled),
                          // The whole 56px row is the tap target, not just
                          // the 44×24 switch graphic — that alone is under
                          // Android's 48dp minimum.
                          onTap: () => _toggleReminder(
                            context,
                            ref,
                            !reminder.enabled,
                          ),
                        ),
                      ),
                      const _RowDivider(),
                      _SettingsRow(
                        label: 'Reminder time',
                        value: reminder.timeLabel,
                        enabled: reminder.enabled,
                        onTap: reminder.enabled
                            ? () => _pickReminderTime(context, ref, reminder)
                            : () => _showMessage(
                                context, 'Turn the reminder on first.'),
                      ),
                    ],
                  ),
                  const _SectionLabel('YOUR DATA'),
                  _SectionCard(
                    children: [
                      _SettingsRow(
                        label: 'Export as CSV',
                        enabled: false,
                        onTap: () => _notReady(context, 'Export'),
                      ),
                      const _RowDivider(),
                      _SettingsRow(
                        label: 'Export as JSON',
                        enabled: false,
                        onTap: () => _notReady(context, 'Export'),
                      ),
                      const _RowDivider(),
                      _SettingsRow(
                        label: 'Import from backup',
                        enabled: false,
                        onTap: () => _notReady(context, 'Import'),
                      ),
                      const _PrivacyNote(),
                    ],
                  ),
                  const _SectionLabel('ABOUT'),
                  _SectionCard(
                    children: [
                      const _SettingsRow(
                        label: 'Version',
                        value: _appVersion,
                        showChevron: false,
                      ),
                      const _RowDivider(),
                      _SettingsRow(
                        label: 'Send feedback',
                        enabled: false,
                        onTap: () => _notReady(context, 'Sending feedback'),
                      ),
                    ],
                  ),

                  // Not in Stitch — the one action on this screen that does
                  // something, so it gets its own section rather than hiding
                  // among rows that don't.
                  const _SectionLabel('DANGER ZONE'),
                  _SectionCard(
                    children: [
                      _SettingsRow(
                        label: 'Clear All Data',
                        labelColor: AppColors.error,
                        showChevron: false,
                        onTap: () => _confirmClearData(context, ref),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xxxl),
                  const _Colophon(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            iconSize: 22,
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text('Settings', style: context.textTheme.displaySmall),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section chrome
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.topPadding = AppSpacing.xxl});

  final String label;

  /// Stitch gives the first section less headroom than the ones after it.
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        topPadding,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: context.textTheme.bodySmall?.copyWith(
          color: AppColors.textDisabled,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.96, // 0.08em at 12px
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          boxShadow: AppShadows.sm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

/// Hairline between rows, inset from the left the way Stitch indents it.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: AppSpacing.lg),
      child: Divider(height: 1, thickness: 1, color: AppColors.border),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
    this.labelColor,
  });

  final String label;

  /// Right-aligned current value, e.g. "Clay & Oat" or "8:30 AM".
  final String? value;

  /// Replaces value + chevron entirely — used by the toggles.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// False greys the row out: the feature behind it doesn't exist yet, and
  /// tapping says so instead of doing nothing.
  final bool enabled;

  final bool showChevron;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final color = labelColor ??
        (enabled ? AppColors.textPrimary : AppColors.textDisabled);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyLarge?.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null)
                trailing!
              else ...[
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Text(
                      value!,
                      // A greyed row's value must grey too — "8:30 AM" at
                      // full contrast reads like a live reminder.
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: enabled
                            ? AppColors.textSecondary
                            : AppColors.textDisabled,
                      ),
                    ),
                  ),
                if (showChevron)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: AppSizes.iconMd,
                    color: AppColors.textDisabled,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Stitch's pill switch — purely decorative. The tap target is the row it
/// sits in (56px, full width), not this 44×24 graphic on its own, which is
/// under Android's 48dp minimum touch size.
class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? AppColors.primary : AppColors.border,
        borderRadius: AppRadius.fab,
      ),
      child: AnimatedAlign(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Everything stays on this device. '
              'Tracely has no account and no servers.',
              style: context.textTheme.bodySmall?.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _Colophon extends StatelessWidget {
  const _Colophon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'HANDCRAFTED OFFLINE COMPANION',
        style: context.textTheme.labelSmall?.copyWith(
          color: AppColors.textDisabled,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
