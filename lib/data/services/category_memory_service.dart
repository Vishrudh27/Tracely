import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the category the user picked when the voice card's guess was
/// wrong ("Juggling" → Creativity), so the guess follows them even after
/// that habit is deleted. Live habits are checked first; this is the
/// fallback memory. Mirrors [InsightService]'s shape.
class CategoryMemoryService {
  CategoryMemoryService._();

  static const _kKey = 'category_corrections';

  // ponytail: oldest corrections drop past this; plenty for one person.
  static const _max = 200;

  /// (habit name, category id), newest first.
  static Future<List<(String, int)>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final entry in prefs.getStringList(_kKey) ?? const <String>[])
        ?_parse(entry),
    ];
  }

  static Future<void> remember(String name, int categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final kept = [
      for (final entry in prefs.getStringList(_kKey) ?? const <String>[])
        if (_parse(entry)?.$1.toLowerCase() != name.toLowerCase()) entry,
    ];
    await prefs.setStringList(
      _kKey,
      ['$categoryId\t$name', ...kept].take(_max).toList(),
    );
  }

  /// Clear All Data / Import: ids may now point at different categories.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  static (String, int)? _parse(String entry) {
    final tab = entry.indexOf('\t');
    final id = tab < 0 ? null : int.tryParse(entry.substring(0, tab));
    return id == null ? null : (entry.substring(tab + 1), id);
  }
}
