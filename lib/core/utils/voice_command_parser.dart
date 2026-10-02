import 'dart:math' as math;

import '../extensions/date_extensions.dart';

/// What a spoken (or typed) "Talk to Tracely" command asks for.
enum VoiceIntent { createHabit, createReminderTask, completeHabit, logMiss, unknown }

/// A parsed command. Deterministic English grammar — no model, no network.
/// Everything here is a *suggestion* the confirm card lets the user edit.
class VoiceCommand {
  const VoiceCommand({
    required this.intent,
    this.text = '',
    this.frequencyType = 'daily',
    this.specificDays = const [],
    this.minuteOfDay,
    this.date,
    this.reasonKey,
    this.reasonText,
  });

  final VoiceIntent intent;

  /// Habit name / task title (create intents), or the spoken habit phrase to
  /// match against existing habits (complete / miss).
  final String text;

  /// `'daily'` or `'specific_days'`.
  final String frequencyType;

  /// Mon=1…Sun=7, sorted. Only meaningful for `specific_days`.
  final List<int> specificDays;

  /// Reminder / due time, minutes since midnight.
  final int? minuteOfDay;

  /// Task due day, or the day a habit was missed (local midnight).
  final DateTime? date;

  /// One of the Pause & Reflect reason keys, or null.
  final String? reasonKey;

  /// The raw reason words — stored as a `'custom'` reason when [reasonKey]
  /// is null.
  final String? reasonText;
}

const _unknown = VoiceCommand(intent: VoiceIntent.unknown);

const _dayNames = [
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
];
const _day = '(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?';

VoiceCommand parseVoiceCommand(
  String input, {
  required DateTime today,
  required int nowMinute,
}) {
  var s = _normalize(input).replaceFirst(
    RegExp(
      r'^(?:(?:hey tracely|please|can you|could you|i want to|id like to|i would like to) )+',
    ),
    '',
  );
  if (s.isEmpty) return _unknown;

  final reminder = RegExp(
    r'^(?:remind me|set a reminder|set reminder|add a reminder|reminder)(?: to| that| about| for)? (.+)$',
  ).firstMatch(s);
  if (reminder != null) {
    return _reminderTask(reminder.group(1)!, today: today, nowMinute: nowMinute);
  }

  final create = RegExp(
    r'^(?:add|create|new|start|track)(?: a)?(?: new)?(?: habit)?(?: called| named| to| of)? (.+)$',
  ).firstMatch(s);
  if (create != null) return _createHabit(create.group(1)!);

  return _miss(s, today) ?? _complete(s) ?? _unknown;
}

// -----------------------------------------------------------------------------
// Normalization
// -----------------------------------------------------------------------------

const _numberWords = {
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
  'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
};
const _minuteWords = {'fifteen': 15, 'thirty': 30, 'forty five': 45};

String _normalize(String input) {
  var s = input.toLowerCase().replaceAll(RegExp('[‘’`]'), "'");
  s = s.replaceAllMapped(RegExp(r'\b([ap])\.\s?m\b\.?'), (m) => '${m[1]}m');
  s = s.replaceAll("'", '');
  s = s.replaceAll(RegExp(r'[^a-z0-9:, ]'), ' ');
  s = s.replaceAll(RegExp(r'(?<!\d):|:(?!\d)'), ' ');
  s = s.replaceAll(RegExp(r'\bo ?clock\b'), ' ');
  s = s.replaceAllMapped(
    RegExp(
      '\\b(at|around|by) (${_numberWords.keys.join('|')})\\b'
      '(?: (${_minuteWords.keys.join('|')})\\b)?',
    ),
    (m) {
      final minutes = _minuteWords[m[3]];
      final mm = minutes == null ? '' : ':$minutes';
      return '${m[1]} ${_numberWords[m[2]]}$mm';
    },
  );
  return _tidy(s);
}

String _tidy(String s) => s
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'\s*,\s*'), ', ')
    .replaceAll(RegExp(r'(?:, )+'), ', ')
    .trim();

String _cut(String s, Match m) =>
    _tidy('${s.substring(0, m.start)} ${s.substring(m.end)}');

// -----------------------------------------------------------------------------
// Time
// -----------------------------------------------------------------------------

typedef _Time = ({int? minute, bool bareAm, String rest});

/// Pulls the first time phrase out of [s]. [bareAm] means the hour carried
/// no am/pm or day-part and was *guessed* as morning — callers may flip it.
_Time _extractTime(String s) {
  final qualifier = RegExp(
    r'\b(morning|afternoon|evening|night|tonight|nightly)\b',
  ).firstMatch(s)?.group(1);

  final t1 = RegExp(r'\b(?:(?:at|around|by) )?(noon|midday|midnight)\b')
      .firstMatch(s);
  if (t1 != null) {
    return (minute: t1[1] == 'midnight' ? 0 : 720, bareAm: false, rest: _cut(s, t1));
  }

  final t2 = RegExp(r'\b(?:(?:at|around|by) )?(\d{1,2})(?::(\d{2}))? ?(am|pm)\b')
      .firstMatch(s);
  if (t2 != null) {
    final h = int.parse(t2[1]!);
    final m = int.parse(t2[2] ?? '0');
    if (h >= 1 && h <= 12 && m <= 59) {
      final hour = h % 12 + (t2[3] == 'pm' ? 12 : 0);
      return (minute: hour * 60 + m, bareAm: false, rest: _cut(s, t2));
    }
  }

  final t3 = RegExp(
    r'\b(?:(?:at|around|by) )?(\d{1,2})(?::(\d{2}))? (?:in the |at )?(morning|afternoon|evening|night|tonight)\b',
  ).firstMatch(s);
  if (t3 != null) {
    final minute = _qualified(int.parse(t3[1]!), int.parse(t3[2] ?? '0'), t3[3]!);
    if (minute != null) return (minute: minute, bareAm: false, rest: _cut(s, t3));
  }

  final bare = RegExp(r'\b(?:at|around|by) (\d{1,2})(?::(\d{2}))?\b').firstMatch(s) ??
      RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(s);
  if (bare != null) {
    final h = int.parse(bare[1]!);
    final m = int.parse(bare[2] ?? '0');
    if (qualifier != null) {
      final minute = _qualified(h, m, qualifier);
      if (minute != null) return (minute: minute, bareAm: false, rest: _cut(s, bare));
    } else if (h <= 23 && m <= 59) {
      // No am/pm and no day-part: 1–6 are far likelier pm, 7–11 am.
      final hour = (h >= 1 && h <= 6) ? h + 12 : h;
      return (
        minute: hour * 60 + m,
        bareAm: h >= 7 && h <= 11,
        rest: _cut(s, bare),
      );
    }
  }
  return (minute: null, bareAm: false, rest: s);
}

int? _qualified(int h, int m, String qualifier) {
  if (h > 23 || m > 59) return null;
  if (h > 12) return h * 60 + m; // already 24-hour
  final hour = switch (qualifier) {
    'morning' => h % 12,
    'afternoon' || 'evening' => h < 12 ? h + 12 : h,
    _ => h == 12 ? 0 : (h >= 6 ? h + 12 : h), // night / tonight / nightly
  };
  return hour * 60 + m;
}

// -----------------------------------------------------------------------------
// Intents
// -----------------------------------------------------------------------------

VoiceCommand _createHabit(String phrase) {
  final time = _extractTime(phrase);
  var s = time.rest;
  final days = <int>{};
  var daily = false;

  final dailyRe = RegExp(
    r'\b(?:every ?day|daily|each day|every single day|every (?:morning|afternoon|evening|night)|each (?:morning|evening|night)|nightly)\b',
  );
  for (var m = dailyRe.firstMatch(s); m != null; m = dailyRe.firstMatch(s)) {
    daily = true;
    s = _cut(s, m);
  }

  final weekdays = RegExp(
    r'\b(?:on |every )?(?:weekdays?|week days|monday (?:to|through|thru) friday)\b',
  ).firstMatch(s);
  if (weekdays != null) {
    days.addAll([1, 2, 3, 4, 5]);
    s = _cut(s, weekdays);
  }
  final weekends = RegExp(r'\b(?:on |every )?weekends?\b').firstMatch(s);
  if (weekends != null) {
    days.addAll([6, 7]);
    s = _cut(s, weekends);
  }
  final named = RegExp(
    '\\b(?:on |every )?($_day(?:(?:,? and |, | or )$_day)*)\\b',
  );
  for (var m = named.firstMatch(s); m != null; m = named.firstMatch(s)) {
    for (final d in RegExp(_day).allMatches(m[1]!)) {
      days.add(_dayNames.indexOf(d[0]!.replaceFirst(RegExp(r's$'), '')) + 1);
    }
    s = _cut(s, m);
  }

  final name = _cleanName(s);
  if (name.isEmpty) return _unknown;
  final specific = days.isNotEmpty && days.length < 7 && !daily;
  return VoiceCommand(
    intent: VoiceIntent.createHabit,
    text: name,
    frequencyType: specific ? 'specific_days' : 'daily',
    specificDays: specific ? (days.toList()..sort()) : const [],
    minuteOfDay: time.minute,
  );
}

VoiceCommand _reminderTask(
  String phrase, {
  required DateTime today,
  required int nowMinute,
}) {
  final time = _extractTime(phrase);
  var s = time.rest;
  var minute = time.minute;
  DateTime? date;

  final rel = RegExp(r'\b(day after tomorrow|tomorrow|today|tonight)\b')
      .firstMatch(s);
  if (rel != null) {
    date = today.addDays(switch (rel[1]) {
      'day after tomorrow' => 2,
      'tomorrow' => 1,
      _ => 0,
    });
    s = _cut(s, rel);
  } else {
    final wd = RegExp('\\b(?:on |next |this )?($_day)\\b').firstMatch(s);
    if (wd != null) {
      final target =
          _dayNames.indexOf(wd[1]!.replaceFirst(RegExp(r's$'), '')) + 1;
      var delta = (target - today.weekday) % 7;
      if (delta == 0 && minute != null && minute <= nowMinute) delta = 7;
      date = today.addDays(delta);
      s = _cut(s, wd);
    }
  }

  final isToday = date == null || date == today;
  if (isToday && minute != null && minute <= nowMinute) {
    if (time.bareAm && minute + 720 > nowMinute) {
      minute += 720; // "study at 9" said at 10 AM means tonight
    } else {
      date ??= today.addDays(1);
    }
  }

  final name = _cleanName(s);
  if (name.isEmpty) return _unknown;
  return VoiceCommand(
    intent: VoiceIntent.createReminderTask,
    text: name,
    minuteOfDay: minute,
    date: date ?? today,
  );
}

VoiceCommand? _miss(String input, DateTime today) {
  final dateRe = RegExp(r'\b(yesterday|last night|today|this morning)\b');
  var yesterday = false;
  var s = input;
  for (var m = dateRe.firstMatch(s); m != null; m = dateRe.firstMatch(s)) {
    if (m[1] == 'yesterday' || m[1] == 'last night') yesterday = true;
    s = _cut(s, m);
  }

  final trigger = RegExp(r'\b(missed|skipped|skip)\b').firstMatch(s) ??
      RegExp(
        r'\b(didnt do|did not do|didnt get to|didnt|did not|couldnt do|couldnt|could not|forgot to do|forgot to|forgot)\b',
      ).firstMatch(s);
  if (trigger == null) return null;

  final after = s.substring(trigger.end).trim();
  final split = RegExp(r',|\b(?:because|cause|cuz|coz|since|as|due to)\b')
      .firstMatch(after);
  final habitPhrase =
      _trimCommas(split == null ? after : after.substring(0, split.start));
  String? reason =
      split == null ? null : _trimCommas(after.substring(split.end));

  if (reason == null || reason.isEmpty) {
    // "I was sick so I skipped the gym" — the reason comes first.
    reason = _trimCommas(
      s
          .substring(0, trigger.start)
          .replaceFirst(RegExp(r'\s*\b(?:so|and|then)?\s*\bi\s*$'), '')
          .replaceFirst(RegExp(r'\s*\b(?:so|and|then)\s*$'), ''),
    );
  }
  reason = reason
      .replaceFirst(RegExp(r'^(?:i was|i am|im|i felt|i feel|it was|was|of) '), '')
      .trim();
  if (reason.isEmpty || reason == 'i') reason = null;

  var key = reason == null ? null : reasonKeyFor(reason);
  if (key == null && trigger[1]!.startsWith('forgot')) key = 'forgot';

  return VoiceCommand(
    intent: VoiceIntent.logMiss,
    text: habitPhrase,
    date: yesterday ? today.addDays(-1) : today,
    reasonKey: key,
    reasonText: reason,
  );
}

VoiceCommand? _complete(String input) {
  final s = input
      .replaceFirst(RegExp(r'\s*\b(?:for today|today|just now|already|now)$'), '')
      .trim();
  const patterns = [
    r'^(?:mark|tick|check)(?: off)? (.+?) (?:as )?(?:done|complete|completed|finished)$',
    r'^(?:mark|tick off|check off) (.+)$',
    r'^(?:done with|finished|completed) (.+)$',
    r'^(.+?) (?:is |was )?(?:done|complete|completed|finished)$',
    r'^i (?:just |already )?(?:did|finished|completed|have done|ve done|went) (.+)$',
    r'^i (?:just |already )?(.+)$',
  ];
  for (final p in patterns) {
    final m = RegExp(p).firstMatch(s);
    if (m == null) continue;
    final text = _trimCommas(m[1]!);
    if (text.isEmpty) return null;
    return VoiceCommand(intent: VoiceIntent.completeHabit, text: text);
  }
  return null;
}

String _trimCommas(String s) =>
    s.replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');

const _edgeTokens = {
  'to', 'at', 'on', 'every', 'each', 'and', 'in', 'the', 'by', 'around',
  'a', 'an', 'habit', 'called', 'named',
};

/// Strips leftover connective words so "running every morning at 6" ends as
/// "Running". Bare day-parts ("evening walk") are kept — they're often part
/// of the name; only "in the morning"-style phrases go.
String _cleanName(String s) {
  s = _tidy(s
      .replaceAll(
        RegExp(r'\b(?:in the|at|this) (?:morning|afternoon|evening|night)\b'),
        ' ',
      )
      .replaceAll(
        RegExp(r'\b(?:(?:in the|on|every|each) )?(?:mornings|afternoons|evenings|nights)\b'),
        ' ',
      )
      .replaceAll(',', ' '));
  final tokens = s.split(' ').where((t) => t.isNotEmpty).toList();
  while (tokens.isNotEmpty && _edgeTokens.contains(tokens.first)) {
    tokens.removeAt(0);
  }
  while (tokens.isNotEmpty && _edgeTokens.contains(tokens.last)) {
    tokens.removeLast();
  }
  final name = tokens.join(' ');
  return name.isEmpty ? '' : name[0].toUpperCase() + name.substring(1);
}

// -----------------------------------------------------------------------------
// Reasons
// -----------------------------------------------------------------------------

/// Ordered — first hit wins. `weather` sits before `felt_sick` so "too cold"
/// isn't read as an illness.
final _reasonPatterns = <(String, RegExp)>[
  ('weather', RegExp(r'\b(?:rain\w*|weather|snow\w*|storm\w*|too hot|too cold)\b')),
  ('felt_sick', RegExp(r'\b(?:sick|ill|fever|flu|caught a cold|a cold|headache|migraine|unwell)\b')),
  ('emergency', RegExp(r'\b(?:emergency|hospital|accident|urgent)\b')),
  ('burned_out', RegExp(r'\b(?:burned out|burnt out|burnout|exhausted)\b')),
  ('poor_sleep', RegExp(r'\b(?:slept badly|bad sleep|poor sleep|didnt sleep|couldnt sleep|no sleep|insomnia|overslept)\b')),
  ('low_energy', RegExp(r'\b(?:tired|low energy|no energy|sleepy|drained|fatigued)\b')),
  ('needed_rest', RegExp(r'\b(?:needed rest|rest day|recover\w*)\b')),
  ('mental_break', RegExp(r'\b(?:mental break|mental health|needed a break)\b')),
  ('too_busy', RegExp(r'\b(?:busy|no time|ran out of time)\b')),
  ('meetings', RegExp(r'\bmeetings?\b')),
  ('unexpected_work', RegExp(r'\b(?:work came up|deadlines?|overtime|work)\b')),
  ('family', RegExp(r'\b(?:family|kids|mom|dad|parents|wife|husband|partner|guests)\b')),
  ('lost_motivation', RegExp(r'\b(?:motivation|unmotivated|didnt feel like|not in the mood)\b')),
  ('procrastinated', RegExp(r'\b(?:procrastinat\w*|lazy|put it off)\b')),
  ('forgot', RegExp(r'\b(?:forgot|forget|slipped my mind)\b')),
  ('felt_overwhelmed', RegExp(r'\b(?:overwhelm\w*|stress\w*|anxious|anxiety)\b')),
  ('couldnt_focus', RegExp(r'\b(?:focus\w*|distracted|concentrat\w*)\b')),
  ('traveling', RegExp(r'\b(?:travel\w*|trip|flight|airport)\b')),
  ('no_equipment', RegExp(r'\b(?:equipment|gym was closed|no shoes|no mat)\b')),
  ('outside_home', RegExp(r'\b(?:away from home|not at home|outside)\b')),
  ('personal_event', RegExp(r'\b(?:party|wedding|birthday|event|festival)\b')),
];

/// Maps free reason words to a Pause & Reflect reason key, or null.
String? reasonKeyFor(String text) {
  final s = _normalize(text);
  for (final (key, re) in _reasonPatterns) {
    if (re.hasMatch(s)) return key;
  }
  return null;
}

// -----------------------------------------------------------------------------
// Matching
// -----------------------------------------------------------------------------

const _stopwords = {
  'my', 'the', 'a', 'an', 'to', 'for', 'of', 'today', 'some', 'with', 'and',
  'at', 'in', 'on', 'i', 'go', 'going', 'do', 'doing', 'did', 'done', 'went',
  'got', 'have', 've', 'just', 'already', 'habit', 'this',
};
const _irregular = {
  'ran': 'run', 'swam': 'swim', 'wrote': 'write', 'ate': 'eat',
  'slept': 'sleep', 'went': 'go',
};

String _stem(String t) {
  t = _irregular[t] ?? t;
  if (t.length > 5 && t.endsWith('ing')) {
    t = t.substring(0, t.length - 3);
  } else if (t.length > 4 && t.endsWith('ed')) {
    t = t.substring(0, t.length - 2);
  } else if (t.length > 3 && t.endsWith('s') && !t.endsWith('ss')) {
    t = t.substring(0, t.length - 1);
  }
  if (t.length > 2 && t[t.length - 1] == t[t.length - 2]) {
    t = t.substring(0, t.length - 1);
  }
  if (t.length > 3 && t.endsWith('e')) t = t.substring(0, t.length - 1);
  return t;
}

List<String> _tokens(String s) => [
      for (final t in s.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
        if (t.isNotEmpty && !_stopwords.contains(t)) _stem(t),
    ];

String _compact(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _tokenMatch(String a, String b) {
  if (a == b) return true;
  final (short, long) = a.length <= b.length ? (a, b) : (b, a);
  return short.length >= 4 && long.startsWith(short);
}

/// Items whose name best matches the spoken [query]; empty when nothing is
/// close. ponytail: token overlap + light stemming, no edit distance — add
/// Levenshtein if speech misspellings show up in real use.
List<T> bestNameMatches<T>(
  String query,
  List<T> items,
  String Function(T) nameOf,
) {
  final q = _compact(query);
  if (q.isEmpty) return [];
  final exact = [for (final i in items) if (_compact(nameOf(i)) == q) i];
  if (exact.isNotEmpty) return exact;

  final qTokens = _tokens(query);
  final scored = <(T, double)>[];
  for (final item in items) {
    final name = nameOf(item);
    final nTokens = _tokens(name);
    var score = nTokens.isEmpty
        ? 0.0
        : nTokens.where((n) => qTokens.any((t) => _tokenMatch(n, t))).length /
            nTokens.length;
    final compactName = _compact(name);
    if (compactName.length >= 4 && q.contains(compactName) && score < 0.9) {
      score = 0.9;
    }
    if (score > 0) scored.add((item, score));
  }
  if (scored.isEmpty) return [];
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final cutoff = math.max(0.5, scored.first.$2 - 0.15);
  return [for (final (item, score) in scored) if (score >= cutoff) item]
      .take(4)
      .toList();
}

// -----------------------------------------------------------------------------
// Category guess
// -----------------------------------------------------------------------------

/// Ordered — first category with a matching keyword prefix wins. Names are
/// the seeded built-in category names.
const _categoryKeywords = <(String, List<String>)>[
  ('Mind', ['meditat', 'mindful', 'breath', 'gratitude', 'journal', 'reflect', 'pray', 'affirmation']),
  ('Fitness', ['run', 'jog', 'gym', 'workout', 'exercise', 'pushup', 'squat', 'lift', 'weight', 'yoga', 'swim', 'cycl', 'bike', 'walk', 'stretch', 'step', 'hike', 'cardio', 'plank', 'pilates']),
  ('Learning', ['read', 'book', 'study', 'learn', 'course', 'language', 'code', 'coding', 'lesson', 'duolingo', 'page', 'podcast']),
  ('Creativity', ['write', 'writing', 'draw', 'paint', 'sketch', 'music', 'guitar', 'piano', 'sing', 'photo', 'craft', 'poem', 'blog']),
  ('Social', ['call', 'friend', 'family', 'mom', 'dad', 'text', 'visit', 'parent']),
  ('Self-Care', ['skincare', 'skin', 'bath', 'relax', 'nap', 'massage', 'unplug', 'screen', 'phone', 'detox']),
  ('Health', ['water', 'drink', 'sleep', 'vitamin', 'medicine', 'meds', 'pill', 'diet', 'fruit', 'veg', 'sugar', 'floss', 'teeth']),
];

/// Built-in category name that fits [habitName], or null.
String? suggestCategoryName(String habitName) {
  final words = habitName.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
  for (final (category, keywords) in _categoryKeywords) {
    if (words.any((w) => keywords.any(w.startsWith))) return category;
  }
  return null;
}
