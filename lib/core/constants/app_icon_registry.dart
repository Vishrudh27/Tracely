import 'package:flutter/material.dart';

/// Maps a stable string key to a Material icon.
///
/// Replaces raw emoji characters everywhere in the app. Emoji render as
/// whatever glyph the device's OS/font ships — different on every phone —
/// and can't be recolored to match the brand palette. These are real
/// vector icons: consistent everywhere, and `Icon(..., color: ...)` works.
///
/// Categories, habits, and reflection reasons all store one of these keys
/// (in what used to be a literal emoji column) rather than an [IconData]
/// directly, since IconData can't be serialized to SQLite cleanly. [resolve]
/// falls back to a neutral default for any key saved before this migration.
final class AppIconRegistry {
  AppIconRegistry._();

  static const Map<String, IconData> _icons = {
    // Category defaults
    'favorite': Icons.favorite_rounded,
    'psychology': Icons.psychology_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'menu_book': Icons.menu_book_rounded,
    'palette': Icons.palette_rounded,
    'groups': Icons.groups_rounded,
    'spa': Icons.spa_rounded,

    // Additional options offered in the habit icon picker
    'directions_run': Icons.directions_run_rounded,
    'directions_bike': Icons.directions_bike_rounded,
    'directions_walk': Icons.directions_walk_rounded,
    'water_drop': Icons.water_drop_rounded,
    'restaurant': Icons.restaurant_rounded,
    'eco': Icons.eco_rounded,
    'edit_note': Icons.edit_note_rounded,
    'music_note': Icons.music_note_rounded,
    'piano': Icons.piano_rounded,
    'laptop': Icons.laptop_mac_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'bedtime': Icons.bedtime_rounded,
    'cleaning': Icons.cleaning_services_rounded,
    'local_florist': Icons.local_florist_rounded,
    'wb_sunny': Icons.wb_sunny_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'handshake': Icons.handshake_rounded,
    'call': Icons.call_rounded,
    'savings': Icons.savings_rounded,
    'track_changes': Icons.track_changes_rounded,
    'hourglass_empty': Icons.hourglass_empty_rounded,
    'vpn_key': Icons.vpn_key_rounded,
    'pets': Icons.pets_rounded,
    'flight': Icons.flight_rounded,
    'schedule': Icons.schedule_rounded,

    // Reflection reasons (Pause & Reflect + Statistics)
    'luggage': Icons.luggage_rounded,

    // Misc UI accents (streaks, celebration, defaults)
    'local_fire_department': Icons.local_fire_department_rounded,
    'emoji_events': Icons.emoji_events_rounded,
    'auto_awesome': Icons.auto_awesome_rounded,
    'star_outline': Icons.star_outline_rounded,
  };

  /// Used when a key is missing/unrecognized — e.g. a row saved before
  /// this migration, still holding the old emoji-based value.
  static const IconData fallback = Icons.star_outline_rounded;

  static IconData resolve(String? key) => _icons[key] ?? fallback;

  /// Curated set offered in the habit/category icon picker grid, in
  /// display order. Deliberately a fixed list, not every registry key —
  /// some keys above exist only as internal defaults (streak fire, the
  /// personal-best sparkle), not user-facing choices.
  static const List<String> pickerOptions = [
    'fitness_center', 'directions_run', 'directions_bike', 'directions_walk',
    'spa', 'water_drop', 'restaurant', 'eco',
    'psychology', 'menu_book', 'edit_note', 'palette',
    'music_note', 'piano', 'laptop', 'lightbulb',
    'bedtime', 'cleaning', 'local_florist', 'wb_sunny',
    'local_cafe', 'handshake', 'call', 'favorite',
    'savings', 'track_changes', 'hourglass_empty', 'vpn_key',
    'pets', 'flight', 'groups', 'schedule',
  ];
}
