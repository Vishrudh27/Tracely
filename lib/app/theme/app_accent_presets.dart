import 'package:flutter/material.dart';

/// One choice in Settings' accent-color picker. [base] becomes
/// [AppColors.primary]; every other brand token (light/dark shades, the
/// fill accent, the heatmap ramp) is derived from it, so picking a preset
/// re-skins the whole app consistently.
class AccentPreset {
  const AccentPreset(this.id, this.label, this.base);

  final String id;
  final String label;
  final Color base;
}

/// Curated, not a free RGB picker — each [AccentPreset.base] below is
/// verified at >=5.8:1 contrast against white, comfortably clearing the
/// 4.5:1 text threshold buttons/FABs need for their white label. A free
/// picker would let someone choose an unreadable color; this can't.
const AccentPreset kDefaultAccentPreset =
    AccentPreset('brown', 'Clay & Oat', Color(0xFF6F4E37));

const List<AccentPreset> kAccentPresets = [
  kDefaultAccentPreset,
  AccentPreset('forest', 'Forest', Color(0xFF3F6B3F)),
  AccentPreset('teal', 'Teal', Color(0xFF2F6F63)),
  AccentPreset('indigo', 'Indigo', Color(0xFF40548C)),
  AccentPreset('plum', 'Plum', Color(0xFF6B4079)),
  AccentPreset('rust', 'Rust', Color(0xFFA1432B)),
  AccentPreset('navy', 'Navy', Color(0xFF3A4750)),
  AccentPreset('berry', 'Berry', Color(0xFF8C3A5C)),
];
