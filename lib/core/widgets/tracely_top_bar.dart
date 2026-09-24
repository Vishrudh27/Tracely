import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../extensions/context_extensions.dart';

/// Shared top bar for the three tab-root screens (Dashboard, Habits,
/// Statistics) — profile avatar, "Tracely" wordmark, notifications bell.
///
/// Persistent chrome: sits above whatever loading/empty/content state a
/// screen is in, never animates with the entrance sequence below it.
class TracelyTopBar extends StatelessWidget implements PreferredSizeWidget {
  const TracelyTopBar({
    super.key,
    this.onAvatarTap,
    this.onNotificationsTap,
  });

  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationsTap;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.appBarHeight);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        height: AppSizes.avatarMd,
        child: Row(
          children: [
            TopBarIconButton(
              icon: Icons.person_outline_rounded,
              onTap: onAvatarTap,
            ),
            const Expanded(child: TracelyWordmark()),
            TopBarIconButton(
              icon: Icons.notifications_none_rounded,
              onTap: onNotificationsTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// The centered "Tracely" brand text — split out so screens with a
/// non-standard top bar (Tasks, with its search toggle) can still render
/// identical chrome instead of drifting out of sync with this widget.
class TracelyWordmark extends StatelessWidget {
  const TracelyWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Tracely',
        style: context.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// A circular chrome button matching [TracelyTopBar]'s avatar/bell style.
/// Public so screens that customize the top bar (Tasks) can reuse it.
class TopBarIconButton extends StatelessWidget {
  const TopBarIconButton({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.avatarMd,
      height: AppSizes.avatarMd,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceVariant,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(
            icon,
            color: AppColors.textSecondary,
            size: AppSizes.iconMd,
          ),
        ),
      ),
    );
  }
}
