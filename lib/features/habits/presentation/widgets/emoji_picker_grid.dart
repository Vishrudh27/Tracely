import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';

/// Horizontal scrollable/wrapped grid of emojis for habit customization.
///
/// Prompts the user to pick an emoji representing their habit.
/// Styled with generous padding and subtle selection indicator.
class EmojiPickerGrid extends StatelessWidget {
  const EmojiPickerGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  static const List<String> _emojis = [
    '💪', '🏃', '🚴', '🧘', '🚶', '💧', '🥗', '🍎',
    '🧠', '📚', '✍️', '🎨', '🎹', '🎸', '💻', '💡',
    '💤', '🧹', '🪴', '🌱', '☀️', '🍵', '🤝', '📞',
    '❤️', '💰', '🎯', '⌛', '🔑', '🌈', '🐾', '✈️'
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _emojis.map((emoji) {
        final isSelected = selected == emoji;

        return GestureDetector(
          onTap: () => onSelected(emoji),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.10)
                  : AppColors.surface,
              borderRadius: AppRadius.card,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
