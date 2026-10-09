import 'dart:math' as math;

import '../extensions/date_extensions.dart';

/// What a spoken (or typed) "Talk to Tracely" command asks for.
enum VoiceIntent {
  createHabit,
  createReminderTask,
  completeHabit,
  logMiss,
  deleteItem,
  unknown,
}

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
    this.target,
    this.isCallReminder = false,
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

  /// For [VoiceIntent.deleteItem]: `'habit'`, `'task'`, or null when the
  /// user didn't say which.
  final String? target;

  /// The user asked for a Call Reminder (full-screen ring, not a soft
  /// notification) — "call remind me", "ring me", "call alarm for gym".
  /// Only meaningful on [VoiceIntent.createHabit] /
  /// [VoiceIntent.createReminderTask].
  final bool isCallReminder;
}

const _unknown = VoiceCommand(intent: VoiceIntent.unknown);

const _dayNames = [
  'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
];
const _day = '(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?';

/// "call reminder", "call remind me", "ring me" — asks for the full-screen
/// Call Reminder instead of a soft notification. Deliberately specific
/// multi-word phrases only — a bare "call" is a common task name itself
/// ("call mom", "call client") and must not trip this.
final _callReminderRe = RegExp(
  r'\b(?:call reminder|call remind(?: me| us)?'
  r'|remind(?: me| us)? (?:by|with|via) (?:a )?call'
  r'|ring me|ring alarm|ring reminder'
  r'|phone call reminder|phone me|phone reminder'
  r'|call alarm|call notify me|voice call reminder'
  r'|(?:like|as) a (?:call|phone call))\b',
);

/// Words that say "this repeats" — a habit, not a one-off task.
final _frequencyRe = RegExp(
  '\\b(?:every ?day|daily|each day|every (?:morning|afternoon|evening|night|week|$_day)'
  '|each (?:morning|evening|night)|nightly|weekdays?|weekends?'
  '|(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)s)\\b',
);

/// Words that pin a single day — a task, not a habit.
final _oneOffRe = RegExp(
  '\\b(?:today|tonight|tomorrow|day after tomorrow|next (?:week|month|$_day)|this $_day)\\b',
);

/// Grammar first (anchored patterns), then looser fallbacks for broken
/// English: an intent keyword anywhere, then the sentence's shape
/// (repeat words → habit, a time or date → task).
VoiceCommand parseVoiceCommand(
  String input, {
  required DateTime today,
  required int nowMinute,
}) {
  final s0 = _stripFiller(_normalize(input));
  if (s0.isEmpty) return _unknown;
  final isCallReminder = _callReminderRe.hasMatch(s0);
  final s = isCallReminder ? _tidy(s0.replaceFirst(_callReminderRe, ' ')) : s0;
  VoiceCommand task(String phrase) => _reminderTask(
        phrase,
        today: today,
        nowMinute: nowMinute,
        isCallReminder: isCallReminder,
      );

  final delete = _deleteRe.firstMatch(s);
  if (delete != null) return _delete(delete[2]!, delete[1]);

  final reminder = _reminderRe.firstMatch(s) ?? _taskRe.firstMatch(s);
  if (reminder != null) return task(reminder[1]!);

  final create = _createRe.firstMatch(s);
  if (create != null) {
    return _createOrTask(
      create[1]!,
      task,
      saidHabit: _saidHabit(s),
      isCallReminder: isCallReminder,
    );
  }

  return _miss(s, today) ??
      _complete(s) ??
      _missByReason(s, today) ??
      _byKeyword(s, task, isCallReminder: isCallReminder) ??
      _byShape(s, task, today, isCallReminder: isCallReminder) ??
      _unknown;
}

/// A first-person report with a reason/excuse ("tired", "sick", "busy") and
/// a habit but no "did"/"missed" verb reads as a miss — "i was tired to do
/// the vessel habit". Runs before the keyword guesses so an incidental
/// "habit" or "to do" in the sentence doesn't turn it into a create/task.
/// The "i …" guard keeps questions like "what's the weather" out.
VoiceCommand? _missByReason(String s, DateTime today) {
  if (!RegExp(r'^i\b').hasMatch(s)) return null;
  final key = reasonKeyFor(s);
  if (key == null) return null;
  // The name can come back empty ("i am tired to the habit" names no
  // specific habit) — still a miss, not a fall-through to create-habit.
  // An empty query makes bestNameMatches show every habit to pick from.
  final name = _missNameFromShape(s);
  final yesterday = RegExp(r'\b(?:yesterday|last night)\b').hasMatch(s);
  return VoiceCommand(
    intent: VoiceIntent.logMiss,
    text: name,
    reasonKey: key,
    date: today.addDays(yesterday ? -1 : 0),
  );
}

final _deleteRe = RegExp(
  r'^(?:delete|remove|erase|discard|get rid of|cancel)'
  r'(?: (?:the|my|a|an|that|this|these|those))*'
  r'(?: (habits?|tasks?|to ?dos?|reminders?|alarms?))?'
  r'(?: (?:called|named|for|of|to|about))? (.+)$',
);

final _reminderRe = RegExp(
  r'^(?:remind(?: me| us)?|remember(?: me)?|(?:dont|do not) (?:let me )?forget'
  r'|(?:alert|notify|ping) me'
  r'|(?:(?:set|add|create|make|put|keep)(?: (?:a|an|the|one|new))* )?(?:reminder|alarm|alert)s?)'
  r'(?: for me)?(?: (?:to|that|about|for|of))? (.+)$',
);

final _taskRe = RegExp(
  r'^(?:(?:add|create|new|make|put|set|schedule|write|note)(?: (?:a|an|the|my|one|new))* )?'
  r'(?:tasks?|to ?dos?)(?: (?:called|named|of|for|to|that|about))? (.+)$',
);

/// Everyday verbs (make, put, set…) only count with the word "habit" —
/// "make tea at 6" is a task, not a habit.
final _createRe = RegExp(
  r'^(?:(?:add|adding|create|creating|new|start|starting|track|tracking|begin|include|register)'
  r'(?: (?:a|an|the|my|one|new|daily))*(?: habits?)?'
  r'|(?:make|put|set|set up|setup|keep|build|form|develop)(?: (?:a|an|the|my|one|new|daily))* habits?'
  r'|(?:a |an |the |new |one )*habits?)'
  r'(?: (?:called|named|of|for|to|that|like))? (.+)$',
);

final _fillerRe = RegExp(
  r'^(?:(?:hey tracely|hey|hi|hello|ok|okay|so|um|uh|hmm|yeah|yes|and|tracely|please|kindly|just'
  r'|can you|could you|would you|will you|i want to|i want|id like to|i would like to'
  r'|i need to|i need you to|i have to|i must|i should|i will|ill|i am going to|im going to'
  r'|help me|lets|let us),? )+',
);

String _stripFiller(String s) => _tidy(s
    .replaceFirst(_fillerRe, '')
    .replaceFirst(RegExp(r'(?:,? (?:please|thanks|thank you|ok|okay))+$'), ''));

bool _saidHabit(String s) => RegExp(r'\bhabits?\b').hasMatch(s);

/// "add call mom tomorrow" or "add milk to my tasks" is a one-off — unless
/// the user said "habit" ("add the habit of reading from tomorrow").
VoiceCommand _createOrTask(
  String phrase,
  VoiceCommand Function(String) task, {
  required bool saidHabit,
  required bool isCallReminder,
}) {
  final toList = RegExp(r' (?:to|in|on) (?:my |the )?(tasks?|to ?dos?|habits?)(?: list)?$')
      .firstMatch(phrase);
  if (toList != null) {
    final rest = phrase.substring(0, toList.start);
    return toList[1]!.startsWith('habit')
        ? _createHabit(rest, isCallReminder: isCallReminder)
        : task(rest);
  }
  if (!saidHabit &&
      _oneOffRe.hasMatch(phrase) &&
      !_frequencyRe.hasMatch(phrase)) {
    return task(phrase);
  }
  return _createHabit(phrase, isCallReminder: isCallReminder);
}

VoiceCommand _delete(String phrase, String? kindWord) {
  String? kind(String? w) => w == null
      ? null
      : w.startsWith('habit')
          ? 'habit'
          : 'task';
  var target = kind(kindWord);
  var s = phrase;
  final suffix = RegExp(
    r'(?: (?:from|in|on) (?:my |the )?(habits?|tasks?|to ?dos?|reminders?)(?: list)?| (habits?|tasks?|to ?dos?|reminders?|alarms?))$',
  ).firstMatch(s);
  if (suffix != null) {
    target ??= kind(suffix[1] ?? suffix[2]);
    s = s.substring(0, suffix.start);
  }
  final name = _cleanName(s);
  if (name.isEmpty) return _unknown;
  return VoiceCommand(intent: VoiceIntent.deleteItem, text: name, target: target);
}

/// An intent keyword anywhere in the sentence — "reading habit add daily".
VoiceCommand? _byKeyword(
  String s,
  VoiceCommand Function(String) task, {
  required bool isCallReminder,
}) {
  String without(RegExp re) => _tidy(s.replaceAll(re, ' '));

  final delete = RegExp(r'\b(?:delete|remove|erase|get rid of)\b');
  if (delete.hasMatch(s)) return _delete(without(delete), null);

  final reminder = RegExp(r'\b(?:remind(?: me)?|reminder|alarm|alert me)\b');
  if (reminder.hasMatch(s)) return task(without(reminder));

  // One-word "todo"/"task" only — bare "to do" is usually an infinitive
  // ("tired to do the vessel"), not a to-do item.
  final todo = RegExp(r'\b(?:add|create|new|tasks?|todos?)\b');
  if (RegExp(r'\b(?:tasks?|todos?)\b').hasMatch(s)) return task(without(todo));

  final create = RegExp(r'\b(?:add|create|new|start|track|habits?)\b');
  if (create.hasMatch(s)) {
    return _createOrTask(
      without(create),
      task,
      saidHabit: _saidHabit(s),
      isCallReminder: isCallReminder,
    );
  }

  final done = RegExp(r'\b(?:done|completed?|finished|finish|over)\b');
  if (done.hasMatch(s)) {
    final phrase = _tidy(without(done)
        .replaceAll(RegExp(r'\b(?:i|have|has|had|is|was|am|already|just)\b'), ' '));
    return phrase.isEmpty
        ? null
        : VoiceCommand(intent: VoiceIntent.completeHabit, text: phrase);
  }
  return null;
}

/// No intent words at all — guess from shape. Repeat words make a habit;
/// "I …" is a report of something done; a time or date makes a task.
VoiceCommand? _byShape(
  String s,
  VoiceCommand Function(String) task,
  DateTime today, {
  required bool isCallReminder,
}) {
  if (_frequencyRe.hasMatch(s)) {
    return _createHabit(s, isCallReminder: isCallReminder);
  }
  final stripped = _stripDoneWhen(s);
  final said = RegExp(r'^i (?:just |already )?(.+)$').firstMatch(stripped);
  if (said != null && !_oneOffRe.hasMatch(stripped)) {
    return VoiceCommand(intent: VoiceIntent.completeHabit, text: said[1]!);
  }
  final dated = _oneOffRe.hasMatch(s) || RegExp('\\bon $_day\\b').hasMatch(s);
  if (dated || _extractTime(s).minute != null) return task(s);
  return null;
}

/// The habit name from a verb-less "i was tired … vessel" — drop the reason
/// words and the "i was / i felt / to / the" scaffolding.
String _missNameFromShape(String s) {
  var t = s;
  for (final (_, re) in _reasonPatterns) {
    t = t.replaceAll(re, ' ');
  }
  t = t.replaceAll(
    RegExp(
      r'\b(?:i was feeling|i was|i am|im|i felt|i feel|feeling|i had|had|i got|i|was|were|been|so|then'
      r'|too|to do|do|doing|today|yesterday|last night|tonight|this morning)\b',
    ),
    ' ',
  );
  return _cleanName(t);
}

// -----------------------------------------------------------------------------
// Normalization
// -----------------------------------------------------------------------------

const _numberWords = {
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
  'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
};
const _minuteWords = {'fifteen': 15, 'thirty': 30, 'forty five': 45};

/// Common misspellings and chat shorthand, matched as whole words.
const _spellings = {
  'remaind': 'remind', 'rimind': 'remind', 'remainder': 'reminder',
  'remainders': 'reminders', 'reminde': 'reminder',
  'tmrw': 'tomorrow', 'tmr': 'tomorrow', 'tmrrw': 'tomorrow',
  'tomorow': 'tomorrow', 'tommorow': 'tomorrow', 'tommorrow': 'tomorrow',
  'tomorro': 'tomorrow', '2moro': 'tomorrow', '2morrow': 'tomorrow',
  'tdy': 'today', '2day': 'today', 'tonite': 'tonight', '2nite': 'tonight',
  'nite': 'night', 'mrng': 'morning', 'mornin': 'morning', 'morng': 'morning',
  'evng': 'evening', 'evry': 'every', 'dayly': 'daily', 'daly': 'daily',
  'pls': 'please', 'plz': 'please', 'plss': 'please',
  'wanna': 'want to', 'gonna': 'going to', 'u': 'you', 'iam': 'i am',
  'habbit': 'habit', 'habbits': 'habits', 'delet': 'delete', 'dlt': 'delete',
  'finsh': 'finish', 'finshed': 'finished', 'complet': 'complete',
  'completd': 'completed', 'compleated': 'completed',
  'excercise': 'exercise', 'exercize': 'exercise',
  'bcoz': 'because', 'becoz': 'because', 'bcz': 'because', 'bcos': 'because',
  'becuase': 'because', 'becasue': 'because', 'coz': 'because',
  'cuz': 'because', 'cause': 'because', 'cos': 'because',
};

/// Short day names, expanded only where a day is expected (after on, every,
/// and, a comma, another day…) so "my cat sat on my laptop" survives.
const _dayAbbrev = {
  'mon': 'monday', 'tue': 'tuesday', 'tues': 'tuesday', 'wed': 'wednesday',
  'thu': 'thursday', 'thur': 'thursday', 'thurs': 'thursday', 'fri': 'friday',
  'sat': 'saturday', 'sun': 'sunday',
};

String _normalize(String input) {
  var s = input.toLowerCase().replaceAll(RegExp('[‘’`]'), "'");
  s = s.replaceAllMapped(RegExp(r'\b([ap])\.\s?m\b\.?'), (m) => '${m[1]}m');
  s = s.replaceAllMapped(RegExp(r'\b(\d{1,2})\.(\d{2})\b'), (m) => '${m[1]}:${m[2]}');
  s = s.replaceAll("'", '');
  s = s.replaceAll(RegExp(r'[^a-z0-9:, ]'), ' ');
  s = s.replaceAll(RegExp(r'(?<!\d):|:(?!\d)'), ' ');
  s = _tidy(s);
  s = s.replaceAllMapped(
    RegExp('\\b(${_spellings.keys.join('|')})\\b'),
    (m) => _spellings[m[1]]!,
  );
  s = s.replaceAllMapped(RegExp(r'\b(\d{1,2}) ?([ap]) m\b'), (m) => '${m[1]}${m[2]}m');
  s = s.replaceAllMapped(RegExp(r'\b(\d{1,2}) (\d{2}) ?(am|pm)\b'), (m) => '${m[1]}:${m[2]} ${m[3]}');

  final days = _dayNames.join('|');
  const short = 'mon|tues?|wed|thu(?:rs?)?|fri|sat|sun';
  final afterDayWord = RegExp(
    '(\\b(?:on|every|next|this|and|or|to|through|thru|till|until|$days)|,) ($short)\\b',
  );
  // The first of a list/range: "mon, wed and fri", "mon to fri".
  final beforeDay = RegExp(
    '\\b($short)(?=(?:,| and| or| to| through| thru| till| until) (?:$short|$days)\\b)',
  );
  for (var prev = ''; prev != s;) {
    prev = s;
    s = s
        .replaceAllMapped(afterDayWord, (m) => '${m[1]} ${_dayAbbrev[m[2]]}')
        .replaceAllMapped(beforeDay, (m) => _dayAbbrev[m[1]]!);
  }

  // Spoken times: "at nine", "nine thirty pm", "six in the morning",
  // "half past six".
  final nums = _numberWords.keys.join('|');
  final mins = _minuteWords.keys.join('|');
  String clock(String hour, String? minute) {
    final m = _minuteWords[minute];
    return '${_numberWords[hour]}${m == null ? '' : ':$m'}';
  }

  s = s.replaceAllMapped(
    RegExp('\\b(at|around|by) ($nums)\\b(?: ($mins)\\b)?'),
    (m) => '${m[1]} ${clock(m[2]!, m[3])}',
  );
  s = s.replaceAllMapped(
    RegExp(
      '\\b($nums)(?: ($mins))? (?=(?:am|pm|o ?clock|in the (?:morning|afternoon|evening|night)'
      '|morning|afternoon|evening|night|tonight)\\b)',
    ),
    (m) => '${clock(m[1]!, m[2])} ',
  );
  s = s.replaceAllMapped(
    RegExp('\\b(half|quarter) (past|to) ($nums|\\d{1,2})\\b'),
    (m) {
      final h = _numberWords[m[3]] ?? int.parse(m[3]!);
      if (m[2] == 'past') return '$h:${m[1] == 'half' ? 30 : 15}';
      return m[1] == 'quarter' ? '${h == 1 ? 12 : h - 1}:45' : m[0]!;
    },
  );
  s = s.replaceAll(RegExp(r'\bo ?clock\b'), ' ');
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

  // Day-part first: "every morning at 6", "evening 7 pm", "night 9" — common
  // in Indian English. Not before a count ("evening 2 rounds").
  final dayPartFirst = RegExp(
    r'\b(morning|afternoon|evening|night|tonight) (?:(?:at|around|by) )?(\d{1,2})(?::(\d{2}))?(?: ?(am|pm))?\b'
    r'(?! (?:rounds?|times?|pages?|minutes?|mins?|hours?|hrs?|glass(?:es)?|kms?|miles?|reps?|sets?|laps?|steps?|chapters?|cups?|lit(?:er|re)s?)\b)',
  ).firstMatch(s);
  if (dayPartFirst != null) {
    final h = int.parse(dayPartFirst[2]!);
    final m = int.parse(dayPartFirst[3] ?? '0');
    final ampm = dayPartFirst[4];
    final minute = ampm == null
        ? _qualified(h, m, dayPartFirst[1]!)
        : (h >= 1 && h <= 12 && m <= 59)
            ? (h % 12 + (ampm == 'pm' ? 12 : 0)) * 60 + m
            : null;
    if (minute != null) {
      return (minute: minute, bareAm: false, rest: _cut(s, dayPartFirst));
    }
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

VoiceCommand _createHabit(String phrase, {bool isCallReminder = false}) {
  final time = _extractTime(phrase);
  // A start day isn't part of the name: "reading from tomorrow onwards".
  var s = _tidy(time.rest.replaceAll(
    RegExp(
      r'\b(?:(?:from|starting|beginning|start) )?(?:today|tomorrow|day after tomorrow|next week|next month|now)(?: onwards| on)?\b',
    ),
    ' ',
  ));
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
    '\\b(?:on |every )?($_day(?:(?:,? and |, | or | )$_day)*)\\b',
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
    isCallReminder: isCallReminder,
  );
}

VoiceCommand _reminderTask(
  String phrase, {
  required DateTime today,
  required int nowMinute,
  bool isCallReminder = false,
}) {
  // A redundant "and set a reminder/alarm" clause — any task with a time
  // already notifies — but keep the time/date words around it.
  phrase = _tidy(phrase.replaceAll(
    RegExp(
      r'\b(?:and |also )*(?:set|add|put|create|make)(?: up)?'
      r'(?: (?:a|an|the|me|one|new))* (?:reminder|alarm|alert|notification)s?'
      r'(?: (?:for me|for|to))?\b',
    ),
    ' ',
  ));
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

  // Strip any leftover date words (a second one like "today and also
  // tomorrow", which we can't honour on a single task) so they don't land
  // in the title. The date chip on the card is editable.
  s = _tidy(s.replaceAll(
    RegExp(
      r'\b(?:and |or )?(?:also )?(?:day after tomorrow|tomorrow|today|tonight|yesterday)\b',
    ),
    ' ',
  ));

  final name = _cleanName(s);
  if (name.isEmpty) return _unknown;
  return VoiceCommand(
    intent: VoiceIntent.createReminderTask,
    text: name,
    minuteOfDay: minute,
    date: date ?? today,
    isCallReminder: isCallReminder,
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

  final trigger = RegExp(r'\b(missed|miss|skipped|skiped|skip)\b').firstMatch(s) ??
      RegExp(
        r'\b(didnt do|did not do|didnt get to|didnt|did not|not did|not done'
        r'|couldnt do|couldnt able to|could not do|could not|couldnt'
        r'|cant do|cannot do|cant|cannot|wasnt able to|was not able to|not able to|unable to'
        r'|failed to|fail to|forgot to do|forgot to|forgot|forget to|forget)\b',
      ).firstMatch(s);
  if (trigger == null) return null;

  final after = s.substring(trigger.end).trim();
  final split = RegExp(r',|\b(?:because|since|as|due to|so)\b').firstMatch(after);
  var habitPhrase =
      _trimCommas(split == null ? after : after.substring(0, split.start));
  String? reason =
      split == null ? null : _trimCommas(after.substring(split.end));
  // Whatever came before the trigger, minus a trailing "so I" / "I".
  final before = _trimCommas(
    s
        .substring(0, trigger.start)
        .replaceFirst(RegExp(r'\s*\b(?:so|and|then)?\s*\bi\s*$'), '')
        .replaceFirst(RegExp(r'\s*\b(?:so|and|then)\s*$'), ''),
  );

  if (habitPhrase.isEmpty) {
    // "reading not done because busy" — the habit comes first.
    habitPhrase = before;
  } else if (reason == null || reason.isEmpty) {
    // "I was sick so I skipped the gym" — the reason comes first.
    reason = before;
  }
  reason = reason
      ?.replaceFirst(
        RegExp(r'^(?:i was feeling|i was|i am|im|i felt|i feel|feeling|it was|was|of|i had|had|i got|there was) '),
        '',
      )
      .trim();
  if (reason == null || reason.isEmpty || reason == 'i') reason = null;

  var key = reason == null ? null : reasonKeyFor(reason);
  if (key == null && trigger[1]!.startsWith('forg')) key = 'forgot';

  return VoiceCommand(
    intent: VoiceIntent.logMiss,
    text: habitPhrase,
    date: yesterday ? today.addDays(-1) : today,
    reasonKey: key,
    reasonText: reason,
  );
}

/// Drops "today", "already", "just now"… from the edges of a done-report.
String _stripDoneWhen(String s) => s
    .replaceFirst(RegExp(r'^(?:(?:today|just|also|finally|now) )+'), '')
    .replaceFirst(
      RegExp(r'(?:\s*\b(?:for today|today|just now|already|now|also|too|finally))+$'),
      '',
    )
    .trim();

/// Strict "I did it" grammar. The loose "I …" form lives in
/// [_byShape], after the task/habit guesses.
VoiceCommand? _complete(String input) {
  final s = _stripDoneWhen(input);
  const patterns = [
    r'^(?:mark|tick|check|set|make|put)(?: off)? (.+?) (?:as )?(?:done|complete|completed|finished|over)$',
    r'^(?:mark|tick off|check off|tick) (.+)$',
    r'^(?:done|did|finished|finish|completed|complete)(?: with| doing)? (.+)$',
    r'^(.+?) (?:is |was |are |has been |have been |got |also )?(?:done|complete|completed|finished|over)$',
    r'^i (?:(?:just|already|have|has|had|am|was|also|finally) )*'
        r'(?:did|do|done|finished|finish|completed|complete|went for|went to|went|ve done)(?: with| doing)? (.+)$',
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
  'a', 'an', 'habit', 'habits', 'called', 'named', 'of', 'for', 'my', 'your',
  'me', 'you', 'doing', 'go', 'going', 'new', 'with', 'that', 'is', 'also',
  'then', 'please',
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
  ('weather', RegExp(r'\b(?:rain\w*|weather|snow\w*|storm\w*|too hot|too cold|heat|humid)\b')),
  ('felt_sick', RegExp(r'\b(?:sick|ill|fever|flu|caught a cold|a cold|cough\w*|headache|migraine|unwell|not well|not feeling well|pain|injur\w*|hurt|stomach\w*|cramps)\b')),
  ('emergency', RegExp(r'\b(?:emergency|hospital|accident|urgent)\b')),
  ('burned_out', RegExp(r'\b(?:burned out|burnt out|burnout|exhausted)\b')),
  ('poor_sleep', RegExp(r'\b(?:slept badly|bad sleep|poor sleep|didnt sleep|couldnt sleep|no sleep|less sleep|insomnia|overslept|woke up late|slept late)\b')),
  ('low_energy', RegExp(r'\b(?:tired|tierd|low energy|no energy|sleepy|drained|fatigued|weak)\b')),
  ('needed_rest', RegExp(r'\b(?:needed rest|rest day|recover\w*)\b')),
  ('mental_break', RegExp(r'\b(?:mental break|mental health|needed a break)\b')),
  ('too_busy', RegExp(r'\b(?:busy|no time|no free time|ran out of time|exams?|assignments?|homework|classes)\b')),
  ('meetings', RegExp(r'\bmeetings?\b')),
  ('unexpected_work', RegExp(r'\b(?:work came up|deadlines?|overtime|office|work)\b')),
  ('family', RegExp(r'\b(?:family|kids|mom|dad|parents|wife|husband|partner|guests|relatives|baby)\b')),
  ('lost_motivation', RegExp(r'\b(?:motivation|unmotivated|didnt feel like|dont feel like|not in the mood|not in mood|no mood|bored|boring|not interested)\b')),
  ('procrastinated', RegExp(r'\b(?:procrastinat\w*|lazy|put it off|phone|scroll\w*|youtube|netflix|instagram)\b')),
  ('forgot', RegExp(r'\b(?:forgot|forget|forgotten|slipped my mind|didnt remember)\b')),
  ('felt_overwhelmed', RegExp(r'\b(?:overwhelm\w*|stress\w*|tense|tension|anxious|anxiety)\b')),
  ('couldnt_focus', RegExp(r'\b(?:focus\w*|distracted|concentrat\w*)\b')),
  ('traveling', RegExp(r'\b(?:travel\w*|trip|flight|airport|journey|out of town)\b')),
  ('no_equipment', RegExp(r'\b(?:equipment|gym was closed|no shoes|no mat)\b')),
  ('outside_home', RegExp(r'\b(?:away from home|not at home|not home|outside)\b')),
  ('personal_event', RegExp(r'\b(?:party|wedding|marriage|birthday|event|festival|function|ceremony|pooja|puja|friends?)\b')),
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
  'got', 'have', 've', 'just', 'already', 'habit', 'habits', 'this', 'is',
  'was', 'it', 'task', 'tasks', 'reminder', 'todo', 'from', 'about', 'also',
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
  if (short.length >= 4 && long.startsWith(short)) return true;
  // Typos ("excersise", "meditaton"). Only on longer words — at 4 letters
  // one edit turns "talk" into "walk", which matters most for delete.
  final limit = short.length >= 8 ? 2 : 1;
  if (short.length >= 5 && _editDistance(a, b, max: limit) <= limit) return true;
  // Sound-alike ASR mishearings that spell nothing alike ("knight"/"nite",
  // "write"/"right") — edit distance misses these, Soundex catches them.
  // Gated the same as the edit-distance check so short words ("talk"/
  // "walk") still can't collide: Soundex keys on the first letter, so those
  // two already differ (T.../W...), but e.g. "see"/"sea" wouldn't.
  return short.length >= 5 && _soundex(a) == _soundex(b);
}

/// Classic Soundex: first letter, then up to 3 digits for the consonant
/// groups that follow (vowels and h/w are skipped without resetting the
/// "last code seen", so doubled sounds across them still collapse).
String _soundex(String s) {
  if (s.isEmpty) return '';
  const groups = {
    'b': '1', 'f': '1', 'p': '1', 'v': '1',
    'c': '2', 'g': '2', 'j': '2', 'k': '2', 'q': '2', 's': '2', 'x': '2', 'z': '2',
    'd': '3', 't': '3',
    'l': '4',
    'm': '5', 'n': '5',
    'r': '6',
  };
  final buffer = StringBuffer(s[0].toUpperCase());
  var lastCode = groups[s[0]];
  for (var i = 1; i < s.length && buffer.length < 4; i++) {
    final c = s[i];
    final code = groups[c];
    if (code != null && code != lastCode) buffer.write(code);
    if (c != 'h' && c != 'w') lastCode = code;
  }
  while (buffer.length < 4) {
    buffer.write('0');
  }
  return buffer.toString();
}

/// Levenshtein distance, giving up early once it exceeds [max].
int _editDistance(String a, String b, {required int max}) {
  if ((a.length - b.length).abs() > max) return max + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    if (cur.reduce(math.min) > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}

/// Items whose name best matches the spoken [query]; empty when nothing is
/// close. ponytail: token overlap + light stemming + small edit distance —
/// no phonetic matching; add it if speech mishearings show up in real use.
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

/// Words that say nothing about what a habit *is* — "Evening journaling"
/// must not inherit Fitness from "Evening walk".
const _genericWords = {
  'morning', 'afternoon', 'evening', 'night', 'daily', 'day', 'days', 'week',
  'minute', 'minutes', 'min', 'mins', 'hour', 'hours', 'time', 'times',
  'early', 'late', 'quick', 'every', 'new', 'more', 'less', 'one', 'two',
  // Everyday verbs: "Take a walk" must not inherit Health from "Take vitamins".
  'take', 'takes', 'taking', 'practice', 'practise', 'practicing', 'play',
  'playing', 'make', 'making', 'get', 'getting', 'watch', 'watching', 'try',
  'keep', 'start', 'stop',
};

List<String> _topicTokens(String s) => [
      for (final t in s.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
        if (t.length > 1 &&
            int.tryParse(t) == null &&
            !_stopwords.contains(t) &&
            !_genericWords.contains(t))
          _stem(t),
    ];

/// The category the user filed a similar habit under, or null. [examples]
/// are (habit name, category id) pairs in priority order — the first wins
/// a tie. Learned from the user's own data, so it beats the keyword table.
int? learnedCategoryId(String habitName, Iterable<(String, int)> examples) {
  final q = _topicTokens(habitName);
  if (q.isEmpty) return null;
  int? bestId;
  var best = 0.0;
  for (final (name, categoryId) in examples) {
    final n = _topicTokens(name);
    final score = q.where((t) => n.any((u) => _tokenMatch(t, u))).length / q.length;
    if (score > best) {
      best = score;
      bestId = categoryId;
    }
  }
  return best >= 0.5 ? bestId : null;
}

/// Built-in category name that fits [habitName], or null.
String? suggestCategoryName(String habitName) {
  final words = habitName.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
  for (final (category, keywords) in _categoryKeywords) {
    if (words.any((w) => keywords.any(w.startsWith))) return category;
  }
  return null;
}
