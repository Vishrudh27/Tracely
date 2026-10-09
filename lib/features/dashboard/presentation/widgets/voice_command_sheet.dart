import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../app/theme/theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/providers/current_date_provider.dart';
import '../../../../core/utils/habit_schedule.dart';
import '../../../../core/utils/voice_command_parser.dart';
import '../../../../data/database/app_database.dart';
import '../../../../data/models/habit_models.dart';
import '../../../../data/models/task_models.dart';
import '../../../../data/repositories/habit_repository.dart';
import '../../../../data/repositories/task_repository.dart';
import '../../../../data/services/category_memory_service.dart';
import '../../../../data/services/reminder_service.dart';
import '../../../analytics/presentation/widgets/most_common_reasons_card.dart';
import '../../../habits/presentation/widgets/category_picker.dart';
import '../../../habits/presentation/widgets/frequency_selector.dart';
import '../../../habits/presentation/widgets/reminder_time_field.dart';

/// "Talk to Tracely" — speak (or type) a command, check the parsed result,
/// confirm. Nothing is written until Confirm.
///
/// Speech uses the phone's own recognizer, online first for accuracy. If
/// that fails (e.g. offline) it falls back to on-device recognition for the
/// rest of this sheet's session — and back to online once that works again;
/// typing always works.
class VoiceCommandSheet extends ConsumerStatefulWidget {
  const VoiceCommandSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      // Above the shell's bottom nav, not inside its tab navigator.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => const VoiceCommandSheet._(),
    );
  }

  /// Warms up the speech engine when the Dashboard loads so the first mic
  /// tap is instant. Only when permission is already granted — otherwise it
  /// would pop the mic prompt at app launch.
  static Future<void> prewarm() async {
    try {
      final speech = SpeechToText();
      if (speech.isAvailable || !await speech.hasPermission) return;
      await speech.initialize(options: [SpeechToText.androidNoBluetooth]);
    } catch (e) {
      debugPrint('Voice: prewarm skipped: $e');
    }
  }

  @override
  ConsumerState<VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

enum _Phase { idle, listening, parsed, error, saving }

class _VoiceCommandSheetState extends ConsumerState<VoiceCommandSheet> {
  // Speech timings, not animations — AppDurations would collapse them to
  // zero under Reduce motion.
  //
  // Android ends a recognition session at the first pause, which cut
  // "add the habit of reading … every day at 9" in half. So one listening
  // *run* is a chain of sessions (segments): after a segment that heard
  // words the recognizer restarts, and the run only ends after [_silence]
  // with no new words, or when the user taps stop. No plugin `pauseFor`:
  // it counts from listen start and cut off slow first words.
  static const _silence = Duration(seconds: 2);

  /// No words at all since the segment started — stop early instead of
  /// waiting out the full [_listenFor] cap. Longer than [_silence]: give
  /// the user time to start speaking, not just to pause mid-sentence.
  static const _noSpeech = Duration(seconds: 4);

  /// How long to wait for a final result after the mic closes — Android
  /// sometimes sends it late, sometimes never.
  static const _grace = Duration(milliseconds: 800);

  /// Per-segment safety cap.
  static const _listenFor = Duration(seconds: 30);

  /// Network/recognizer errors from the online recognizer — fall back to
  /// on-device (the phone is probably offline).
  static const _fallbackErrors = {
    'error_language_not_supported',
    'error_language_unavailable',
    'error_network',
    'error_network_timeout',
    'error_server',
    'error_server_disconnected',
    'error_too_many_requests',
  };

  /// Ended without words — not a failure worth a scary message, and safe to
  /// restart after.
  static const _silentErrors = {
    'error_no_match',
    'error_speech_timeout',
    'error_client',
  };

  // Online first — the cloud recognizer is far more accurate. On a real
  // failure (not just silence) it falls back to the other mode — on-device
  // if we were online, online if we were on-device — and sticks with that
  // for the rest of this sheet's session.
  // ponytail: instance field, not static — each sheet starts online again,
  // even if an earlier sheet this launch had to fall back.
  bool _preferOffline = false;

  /// At most one fallback switch per listening run — otherwise a phone with
  /// no offline pack and no network would ping-pong online↔on-device
  /// forever. Reset each time a fresh run starts.
  bool _fellBack = false;

  final _speech = SpeechToText();
  final _input = TextEditingController();
  final _name = TextEditingController();

  _Phase _phase = _Phase.idle;
  String? _message;
  VoiceCommand? _cmd;

  String _frequencyType = 'daily';
  List<int> _days = [];
  int? _minute;
  DateTime? _date;
  Category? _category;
  int? _habitId;
  int? _taskId;
  List<Habit> _habitChoices = [];
  List<TaskWithCategory> _taskChoices = [];
  bool _noMatch = false;

  /// What the card guessed — a different pick on Confirm is a correction
  /// worth remembering.
  int? _suggestedCategoryId;
  List<(String, int)> _corrections = const [];

  /// Mutable mirror of [VoiceCommand.reasonKey] for the miss card — lets the
  /// user pick a reason when the parser couldn't find one.
  String? _reasonKey;

  bool _listenersBound = false;
  bool _usedOnline = false;
  String? _localeId;

  // Listening run state. Bumping [_run] orphans every callback and await
  // from the run before it.
  int _run = 0;
  String _heard = ''; // text from earlier segments of this run
  bool _segmentLive = false;
  bool _onDeviceAttempt = false;
  bool _segmentHeard = false;
  bool _micClosed = false;
  bool _gotFinal = false;
  String? _segmentError;

  /// True once this segment's native recognizer has actually confirmed it
  /// started (the `listening` status). An error that arrives before that is
  /// likely a straggler from the *previous* segment, not this one.
  bool _segmentConfirmed = false;

  /// Guards against `listen()` silently no-op'ing (already busy, or not
  /// initialized) without ever firing a result, status or error — the
  /// plugin swallows that failure, which otherwise hangs on "Listening…"
  /// forever. One retry; cancelled by any real sign of life.
  Timer? _watchdogTimer;
  bool _watchdogRetrying = false;

  /// Other transcriptions the recognizer considered for the most recent
  /// final result (Android asks for up to 10), most confident first — [0]
  /// is always what's already in [_input]. [_altPrefix] is a snapshot of
  /// [_heard] taken at that same moment, so a later segment's words can't
  /// silently invalidate the pairing. [_parse] only trusts these when
  /// nothing has been appended since (checked against [_input.text]).
  List<String> _segmentAlternates = [];
  String _altPrefix = '';
  Timer? _silenceTimer;
  Timer? _graceTimer;
  Timer? _noSpeechTimer;

  @override
  void initState() {
    super.initState();
    // Only read at parse time, long after this lands — no rebuild needed.
    CategoryMemoryService.load().then((c) => _corrections = c).catchError((
      Object e,
    ) {
      debugPrint('Voice: category memory unavailable: $e');
      return _corrections;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startListening();
    });
  }

  @override
  void dispose() {
    _stopRun();
    if (_listenersBound) {
      _speech.errorListener = null;
      _speech.statusListener = null;
    }
    _input.dispose();
    _name.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Speech
  // ---------------------------------------------------------------------------

  /// [append] keeps whatever is already in the box and dictates onto the
  /// end of it — tapping the mic again to add to a draft. A fresh start
  /// (first open, or the examples) clears it so a stale transcript can't be
  /// re-parsed over the card's edits.
  Future<void> _startListening({bool append = false}) async {
    FocusScope.of(context).unfocus();
    _stopRun();
    final run = _run;
    _fellBack = false;
    if (!append) _input.clear();
    setState(() {
      _cmd = null;
      _phase = _Phase.listening;
      _message = null;
    });
    try {
      final ok = await _speech.initialize(
        options: [SpeechToText.androidNoBluetooth],
      );
      if (!mounted) return;
      // SpeechToText is a singleton and initialize() only binds callbacks on
      // its first success, so rebind for this sheet every time.
      _speech.errorListener = _onError;
      _speech.statusListener = _onStatus;
      _listenersBound = true;
      if (run != _run) return;
      if (!ok) return _fail(AppStrings.voiceMicUnavailable);
      _localeId ??= await _englishLocaleId();
      if (!mounted || run != _run) return;
      await _startSegment(onDevice: _preferOffline);
    } catch (e) {
      debugPrint('Voice: start failed: $e');
      if (mounted && run == _run) _fail(AppStrings.voiceMicUnavailable);
    }
  }

  /// The phone's locale when it's an English one (en_IN, en_GB…) — forcing
  /// en_US can fail when only another English pack is installed offline.
  Future<String> _englishLocaleId() async {
    final id = (await _speech.systemLocale())?.localeId;
    return id != null && id.toLowerCase().startsWith('en') ? id : 'en_US';
  }

  /// Starts one recognizer session; its words are appended to [_heard].
  Future<void> _startSegment({required bool onDevice}) async {
    final run = _run;
    _onDeviceAttempt = onDevice;
    _heard = _input.text.trim();
    try {
      // Also clears the plugin's timers left by the previous segment.
      await _speech.cancel();
      if (!mounted || run != _run) return;
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          onDevice: onDevice,
          partialResults: true,
          // Off on purpose: the plugin cancels *after* calling the error
          // listener, which would kill a restart started from it.
          cancelOnError: false,
          // ponytail: the plugin only rebuilds its native recognizer Intent
          // (and so actually picks up a changed onDevice) when listenMode,
          // language, partialResults or pauseFor differ from the previous
          // call — onDevice alone is ignored (SpeechToTextPlugin.kt
          // setupRecognizerIntent). Tying listenMode to onDevice forces that
          // rebuild exactly when the mode actually flips.
          listenMode: onDevice ? ListenMode.dictation : ListenMode.confirmation,
          localeId: _localeId,
          listenFor: _listenFor,
        ),
      );
    } catch (e) {
      debugPrint('Voice: listen failed: $e');
      if (!mounted || run != _run) return;
      return _heard.isEmpty
          ? _fail(AppStrings.voiceRecognizerFailed)
          : _parse();
    }
    if (!mounted || run != _run) return;
    // Live only now: stragglers from the previous segment that arrived
    // during cancel()/listen() were dropped.
    _segmentHeard = false;
    _micClosed = false;
    _gotFinal = false;
    _segmentError = null;
    _segmentConfirmed = false;
    _segmentLive = true;
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(
      const Duration(seconds: 3),
      () => _onWatchdog(onDevice),
    );
    if (!onDevice && !_usedOnline) setState(() => _usedOnline = true);
    // Don't arm the silence timer here: a run that heard words already has
    // one running (it persists across the restart), and arming it on a
    // fresh append would cut the user off before they start speaking.
    //
    // Do arm the no-speech timer: a fresh segment that never hears a word
    // would otherwise sit open for the full 30s _listenFor cap (no pauseFor
    // is set, so the recognizer itself won't cut it short).
    _noSpeechTimer?.cancel();
    _noSpeechTimer = Timer(_noSpeech, _onNoSpeech);
  }

  void _onResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords.trim();
    debugPrint('Voice: result "$words" final: ${r.finalResult}');
    if (!mounted || !_segmentLive) return;
    _cancelWatchdog();
    // Android often sends an empty result (frequently the final one); it
    // must not wipe the words already shown.
    if (words.isNotEmpty) {
      _segmentHeard = true;
      _noSpeechTimer?.cancel();
      _input.text = _heard.isEmpty ? words : '$_heard $words';
      _armSilence();
    }
    if (r.finalResult) {
      _gotFinal = true;
      _altPrefix = _heard;
      _segmentAlternates = [
        for (final alt in r.alternates)
          if (alt.recognizedWords.trim().isNotEmpty) alt.recognizedWords.trim(),
      ];
      if (_micClosed) _endSegment();
    }
  }

  void _onStatus(String status) {
    debugPrint('Voice: status $status');
    if (!mounted || !_segmentLive) return;
    _cancelWatchdog();
    if (status == SpeechToText.listeningStatus) {
      _segmentConfirmed = true;
      return;
    }
    if (status != SpeechToText.notListeningStatus) return;
    _micClosed = true;
    if (_gotFinal) return _endSegment();
    _graceTimer?.cancel();
    _graceTimer = Timer(_grace, _endSegment);
  }

  void _onError(SpeechRecognitionError e) {
    debugPrint('Voice: error ${e.errorMsg} (onDevice: $_onDeviceAttempt)');
    if (!mounted || !_segmentLive) return;
    // A straggler from the *previous* segment, delivered after this one's
    // listen() already resolved, would otherwise be misattributed as this
    // segment's own error. Only trust an error once this segment has
    // actually confirmed it started — and leave the watchdog running when
    // we don't, so a genuine fast failure still gets caught by it instead
    // of being silently dropped with nothing left to recover it.
    // Partial fix, not complete: the plugin reports `listening` eagerly
    // (synchronously inside its native startListening, before any real
    // readiness callback), so _segmentConfirmed usually flips true almost
    // immediately — a straggler that arrives *after* that point still gets
    // through. Narrows the window; doesn't close it.
    if (!_segmentConfirmed) {
      debugPrint(
        'Voice: ignoring error before listening confirmed (stale?): '
        '${e.errorMsg}',
      );
      return;
    }
    _cancelWatchdog();
    // Native posts the error after the mic-closed statuses, so it's always
    // the last event of a segment.
    _segmentError = e.errorMsg;
    _endSegment();
  }

  /// Any genuine sign of life from the current segment — a result, a
  /// status, or an error — proves `listen()` didn't silently no-op, and
  /// resets the one-retry budget for the next time it might.
  void _cancelWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogRetrying = false;
  }

  void _onWatchdog(bool onDevice) {
    if (!mounted || !_segmentLive) return;
    debugPrint('Voice: watchdog — no response from recognizer');
    _segmentLive = false;
    if (_watchdogRetrying) {
      _watchdogRetrying = false;
      _stopRun();
      _fail(AppStrings.voiceMicBusy);
      return;
    }
    _watchdogRetrying = true;
    _startSegment(onDevice: onDevice);
  }

  /// One recognizer session is over: keep listening, retry online, parse,
  /// or give up.
  void _endSegment() {
    if (!mounted || !_segmentLive) return;
    _segmentLive = false;
    _graceTimer?.cancel();
    _noSpeechTimer?.cancel();
    final error = _segmentError;
    final benign = error == null || _silentErrors.contains(error);
    final hasText = _input.text.trim().isNotEmpty;

    if (error == 'error_permission') {
      return _fail(AppStrings.voiceMicUnavailable);
    }
    // A real failure with no text yet: switch to the other recognition mode
    // and stick with it for the rest of this sheet's session. Capped at one
    // switch — otherwise a phone with neither network nor an offline pack
    // would bounce between the two modes forever.
    if (!hasText && !_fellBack && _fallbackErrors.contains(error)) {
      _fellBack = true;
      _preferOffline = !_onDeviceAttempt;
      _startSegment(onDevice: _preferOffline);
      return;
    }
    if (!hasText) {
      return _fail(
        benign ? AppStrings.voiceDidntHear : AppStrings.voiceRecognizerFailed,
      );
    }
    // New words this segment → the user may be mid-command. Keep
    // listening; the silence timer decides when they're done. A segment
    // that heard nothing can't loop (error_client/error_busy restarts).
    if (_segmentHeard && benign) {
      _startSegment(onDevice: _preferOffline);
      return;
    }
    _parse();
  }

  void _armSilence() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silence, _finish);
  }

  /// Segment never heard a word — stop the mic instead of waiting out the
  /// full [_listenFor] cap.
  Future<void> _onNoSpeech() async {
    if (!mounted || !_segmentLive || _segmentHeard) return;
    debugPrint('Voice: no speech, stopping segment early');
    final run = _run;
    _segmentLive = false;
    _watchdogTimer?.cancel();
    _graceTimer?.cancel();
    // Awaited, not fire-and-forget: a mic tap right after this must not
    // race a still-in-flight cancel(), or the plugin's listen() silently
    // no-ops (looks like the mic "turns off" instead of restarting).
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('Voice: cancel failed: $e');
    }
    if (!mounted || run != _run) return;
    if (_input.text.trim().isNotEmpty) return _parse();
    _stopRun();
    setState(() => _phase = _Phase.idle);
  }

  /// Stop tapped, or the user went quiet: use what's in the box.
  void _finish() {
    if (!mounted || _phase != _Phase.listening) return;
    if (_input.text.trim().isNotEmpty) return _parse();
    _stopRun();
    setState(() => _phase = _Phase.idle);
  }

  /// Ends the listening run. Unconditional cancel(): after Android closes
  /// the mic itself the plugin still holds a timer only cancel() clears.
  void _stopRun() {
    _run++;
    _segmentLive = false;
    _silenceTimer?.cancel();
    _graceTimer?.cancel();
    _watchdogTimer?.cancel();
    _noSpeechTimer?.cancel();
    _watchdogRetrying = false;
    unawaited(
      _speech.cancel().catchError((Object e) {
        debugPrint('Voice: cancel failed: $e');
      }),
    );
    _segmentAlternates = [];
    _altPrefix = '';
  }

  void _toggleMic() {
    if (_phase == _Phase.listening) {
      _finish();
    } else {
      // Resuming with a draft on screen adds to it; otherwise start clean.
      _startListening(append: _input.text.trim().isNotEmpty);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    _stopRun();
    setState(() {
      // _cmd is always null here: _startListening clears it before any
      // path that can reach _fail runs.
      _phase = _Phase.error;
      _message = message;
    });
  }

  // ---------------------------------------------------------------------------
  // Parse → editable slots
  // ---------------------------------------------------------------------------

  void _parse() {
    if (_phase == _Phase.saving) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    // Snapshot before _stopRun() clears them.
    final prefix = _altPrefix;
    final alts = _segmentAlternates;
    _stopRun();
    final today = ref.read(currentDateProvider);
    final now = DateTime.now();
    final nowMinute = now.hour * 60 + now.minute;

    // The top transcription first (already in [text]), then the other
    // alternates the recognizer offered for the last segment — but only if
    // nothing was appended after that segment (a later segment's words
    // would make [prefix] stale).
    final expectedTop = alts.isEmpty
        ? null
        : (prefix.isEmpty ? alts.first : '$prefix ${alts.first}');
    final candidates = [
      text,
      if (expectedTop == text)
        for (final alt in alts.skip(1))
          if (alt.isNotEmpty) prefix.isEmpty ? alt : '$prefix $alt',
    ];
    var best = parseVoiceCommand(
      candidates.first,
      today: today,
      nowMinute: nowMinute,
    );
    for (final candidate in candidates.skip(1)) {
      if (best.intent != VoiceIntent.unknown) break;
      final cmd = parseVoiceCommand(
        candidate,
        today: today,
        nowMinute: nowMinute,
      );
      if (cmd.intent != VoiceIntent.unknown) best = cmd;
    }
    if (best.intent == VoiceIntent.unknown) {
      // ponytail: local-only, grep `adb logcat | grep Voice:` for real
      // failures to grow the parser's rules from actual use, not guesses.
      debugPrint('Voice: unknown command: "$text"');
    }
    _apply(best, isQuestion: _looksLikeQuestion(text));
  }

  /// A question ("did I...", "is X done?") must never be silently applied —
  /// the user is asking, not telling. Checked against the raw spoken/typed
  /// text, before the parser strips punctuation.
  ///
  /// "is"/"are" and the wh-words are unambiguous on their own. The
  /// auxiliaries (did/was/were/…) are not — "was sick so I skipped gym" and
  /// "did my workout" are statements, not questions — so those only count
  /// when immediately followed by a subject pronoun ("did I...", "was
  /// it...", "were we...").
  ///
  /// can/could/would/will are deliberately excluded even with a pronoun:
  /// "can you", "could you", "would you" and "will you" are politeness the
  /// parser already strips as filler ([_fillerRe] in voice_command_parser),
  /// not questions — "can you mark reading done" is a plain command.
  static final _questionWordRe = RegExp(
    r'^(?:what|when|where|who|why|how|is|are)\b',
  );
  static final _questionAuxPronounRe = RegExp(
    r'^(?:did|does|do|was|were|has|have|had|should)\b'
    r'\s+(?:i|you|we|it)\b',
  );

  static bool _looksLikeQuestion(String text) {
    final t = text.trim().toLowerCase();
    return t.endsWith('?') ||
        _questionWordRe.hasMatch(t) ||
        _questionAuxPronounRe.hasMatch(t);
  }

  void _apply(VoiceCommand cmd, {bool isQuestion = false}) {
    final habits = ref.read(activeHabitsProvider).asData?.value ?? <Habit>[];
    // Any unfinished task, not just today's — "mark pay rent done" should
    // still find it even if it's overdue or due later.
    final tasks =
        (ref.read(tasksProvider).asData?.value ?? <TaskWithCategory>[])
            .where((t) => !t.isDone)
            .toList();
    final categories =
        ref.read(categoriesProvider).asData?.value ?? <Category>[];

    // Reversible, unambiguous actions skip the confirm card and apply at
    // once with an Undo — one less tap for the common "mark done" / "missed".
    // Never for a question ("did I...", "is X done?") — the user is asking,
    // not telling.
    if (!isQuestion && cmd.intent == VoiceIntent.completeHabit) {
      final h = bestNameMatches(cmd.text, habits, (x) => x.name);
      final t = h.isEmpty
          ? bestNameMatches(cmd.text, tasks, (x) => x.title)
          : const <TaskWithCategory>[];
      if (h.length == 1) {
        _autoComplete(habit: h.single);
        return;
      }
      if (h.isEmpty && t.length == 1) {
        _autoComplete(task: t.single);
        return;
      }
    } else if (!isQuestion &&
        cmd.intent == VoiceIntent.logMiss &&
        (cmd.reasonKey != null || (cmd.reasonText?.isNotEmpty ?? false))) {
      final m = bestNameMatches(cmd.text, habits, (x) => x.name);
      if (m.length == 1) {
        _autoMiss(cmd, m.single);
        return;
      }
    }

    setState(() {
      _cmd = cmd;
      _phase = _Phase.parsed;
      _message = null;
      _name.text = cmd.text;
      _frequencyType = cmd.frequencyType;
      _days = [...cmd.specificDays];
      _minute = cmd.minuteOfDay;
      _date = cmd.date;
      _reasonKey = cmd.reasonKey;
      _category = null;
      _habitId = null;
      _taskId = null;
      _habitChoices = [];
      _taskChoices = [];
      _noMatch = false;

      switch (cmd.intent) {
        case VoiceIntent.createHabit:
          _category = _suggestCategory(cmd.text, categories);
          _suggestedCategoryId = _category?.id;
        case VoiceIntent.completeHabit:
          _habitChoices = bestNameMatches(cmd.text, habits, (h) => h.name);
          if (_habitChoices.isEmpty) {
            _taskChoices = bestNameMatches(cmd.text, tasks, (t) => t.title);
          }
          _noMatch = _habitChoices.isEmpty && _taskChoices.isEmpty;
          if (_habitChoices.length == 1) {
            _habitId = _habitChoices.single.id;
          } else if (_habitChoices.isEmpty && _taskChoices.length == 1) {
            _taskId = _taskChoices.single.id;
          }
        case VoiceIntent.logMiss:
          final matched = bestNameMatches(cmd.text, habits, (h) => h.name);
          _habitChoices = matched.isEmpty ? habits : matched;
          if (matched.length == 1) _habitId = matched.single.id;
        case VoiceIntent.deleteItem:
          // Any task, done or not — only habits/tasks the user named.
          final allTasks =
              ref.read(tasksProvider).asData?.value ?? <TaskWithCategory>[];
          if (cmd.target != 'task') {
            _habitChoices = bestNameMatches(cmd.text, habits, (h) => h.name);
          }
          if (cmd.target != 'habit') {
            _taskChoices = bestNameMatches(cmd.text, allTasks, (t) => t.title);
          }
          _noMatch = _habitChoices.isEmpty && _taskChoices.isEmpty;
          if (_habitChoices.length + _taskChoices.length == 1) {
            _habitId = _habitChoices.firstOrNull?.id;
            _taskId = _taskChoices.firstOrNull?.id;
          }
        case VoiceIntent.createReminderTask:
        case VoiceIntent.unknown:
          break;
      }
    });
  }

  /// The user's own choices first: a similar habit they already have (most
  /// recently edited wins, so a later re-file counts), then a remembered
  /// correction, then the keyword table, then the first built-in.
  Category? _suggestCategory(String name, List<Category> categories) {
    final habits = ref.read(allHabitsProvider).asData?.value ?? <Habit>[];
    final learned = learnedCategoryId(name, [
      for (final h in habits) (h.name, h.categoryId),
      ..._corrections,
    ]);
    // A custom category can be deleted after it was learned.
    final fromUser = categories.where((c) => c.id == learned).firstOrNull;
    if (fromUser != null) return fromUser;

    final builtIns = categories.where((c) => c.isBuiltIn);
    final suggested = suggestCategoryName(name);
    return builtIns.where((c) => c.name == suggested).firstOrNull ??
        builtIns.firstOrNull ??
        categories.firstOrNull;
  }

  // ---------------------------------------------------------------------------
  // Auto-apply (reversible) — write now, offer Undo, no confirm card
  // ---------------------------------------------------------------------------

  Future<void> _autoComplete({Habit? habit, TaskWithCategory? task}) async {
    final habits = ref.read(habitRepositoryProvider);
    final tasks = ref.read(taskRepositoryProvider);
    final today = ref.read(currentDateProvider);
    _stopRun();
    setState(() => _phase = _Phase.saving);
    try {
      if (habit != null) {
        if (await habits.isCompletedOn(habit.id, today)) {
          _finishAuto('“${habit.name}” is already done today.');
          return;
        }
        await habits.setCompleted(habit.id, today);
        _finishAuto(
          '“${habit.name}” done.',
          undo: () => habits.clearCompleted(habit.id, today),
        );
      } else {
        await tasks.setTaskDone(task!.id, true);
        _finishAuto(
          '“${task.title}” done.',
          undo: () => tasks.setTaskDone(task.id, false),
        );
      }
    } catch (e) {
      debugPrint('Voice: complete failed: $e');
      _failAuto();
    }
  }

  Future<void> _autoMiss(VoiceCommand cmd, Habit habit) async {
    final reflections = ref.read(reflectionDaoProvider);
    final today = ref.read(currentDateProvider);
    final date = cmd.date ?? today;
    final reason = cmd.reasonKey ?? 'custom';
    _stopRun();
    setState(() => _phase = _Phase.saving);
    try {
      // Only offer Undo when we actually added it — a reason already logged
      // for today must survive the Undo.
      final existed = await reflections.hasHabitReflection(
        habit.id,
        date,
        reason,
      );
      await reflections.createHabitReflection(
        habitId: habit.id,
        missedDate: date,
        reason: reason,
        followUpAnswer: cmd.reasonKey == null ? cmd.reasonText : null,
      );
      _finishAuto(
        AppStrings.voiceMissSaved,
        undo: existed
            ? null
            : () => reflections.removeHabitReflection(habit.id, date, reason),
      );
    } catch (e) {
      debugPrint('Voice: miss failed: $e');
      _failAuto();
    }
  }

  /// Pop the sheet and show the result, with an Undo action when reversible.
  void _finishAuto(String message, {Future<void> Function()? undo}) {
    if (!mounted) return;
    // Still mounted but no longer the current route: don't pop or show a
    // snackbar over whatever's on top now, but don't leave the sheet stuck
    // on "saving" (Close disabled, back blocked) either.
    if (ModalRoute.of(context)?.isCurrent != true) {
      setState(() => _phase = _Phase.idle);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: undo == null
              ? null
              : SnackBarAction(
                  label: AppStrings.voiceUndo,
                  onPressed: () => undo().catchError(
                    (Object e) => debugPrint('Voice: undo failed: $e'),
                  ),
                ),
        ),
      );
  }

  void _failAuto() {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _message = AppStrings.voiceSaveFailed;
    });
  }

  /// "No habit called X" → offer to create it instead.
  void _switchToCreate() {
    final text = _cmd?.text ?? '';
    final name = text.isEmpty
        ? text
        : text[0].toUpperCase() + text.substring(1);
    _apply(VoiceCommand(intent: VoiceIntent.createHabit, text: name));
  }

  bool get _canConfirm {
    final cmd = _cmd;
    if (cmd == null || _phase != _Phase.parsed) return false;
    return switch (cmd.intent) {
      VoiceIntent.createHabit =>
        _name.text.trim().isNotEmpty &&
            _category != null &&
            (_frequencyType != 'specific_days' || _days.isNotEmpty),
      VoiceIntent.createReminderTask =>
        _name.text.trim().isNotEmpty && _date != null,
      VoiceIntent.completeHabit ||
      VoiceIntent.deleteItem => _habitId != null || _taskId != null,
      VoiceIntent.logMiss =>
        _habitId != null &&
            (_reasonKey != null || (cmd.reasonText?.isNotEmpty ?? false)),
      VoiceIntent.unknown => false,
    };
  }

  // ---------------------------------------------------------------------------
  // Confirm → write
  // ---------------------------------------------------------------------------

  Future<void> _confirm() async {
    // Re-entry guard: a double tap can land before the first tap's setState
    // rebuilds the button as disabled.
    if (_phase == _Phase.saving) return;
    final cmd = _cmd;
    if (cmd == null || !_canConfirm) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final habits = ref.read(habitRepositoryProvider);
    final tasks = ref.read(taskRepositoryProvider);
    final reflections = ref.read(reflectionDaoProvider);
    final today = ref.read(currentDateProvider);
    final name = _name.text.trim();
    final minute = _minute;
    setState(() => _phase = _Phase.saving);

    try {
      final wantsReminder =
          minute != null &&
          (cmd.intent == VoiceIntent.createHabit ||
              cmd.intent == VoiceIntent.createReminderTask);
      final notificationsOff =
          wantsReminder && !await ReminderService.requestPermission();
      final at = minute == null ? '' : ' — reminder at ${clockLabel(minute)}';

      final String message;
      switch (cmd.intent) {
        case VoiceIntent.createHabit:
          final days = [..._days]..sort();
          await habits.createHabit(
            HabitsCompanion.insert(
              name: name,
              categoryId: _category!.id,
              frequencyType: drift.Value(_frequencyType),
              frequencyConfig: drift.Value(
                _frequencyType == 'specific_days'
                    ? '[${days.join(",")}]'
                    : null,
              ),
              reminderEnabled: drift.Value(minute != null),
              reminderTime: drift.Value(
                minute == null ? null : formatHhMm(minute),
              ),
              isAlarmReminder: drift.Value(minute != null && cmd.isCallReminder),
            ),
          );
          if (_category!.id != _suggestedCategoryId) {
            await _rememberCorrection(name, _category!.id);
          }
          message = '“$name” added$at.';
        case VoiceIntent.createReminderTask:
          await tasks.addTask(
            title: name,
            dueDate: _date!.startOfDay,
            dueTime: minute == null ? null : formatHhMm(minute),
            isAlarmReminder: cmd.isCallReminder,
          );
          message = '“$name” added to ${_dateLabel(_date!)}$at.';
        case VoiceIntent.completeHabit:
          if (_habitId != null) {
            await habits.setCompleted(_habitId!, today);
            message = '“${_habitName(_habitId!)}” done for today.';
          } else {
            await tasks.setTaskDone(_taskId!, true);
            message = '“${_taskTitle(_taskId!)}” done.';
          }
        case VoiceIntent.deleteItem:
          if (_habitId != null) {
            message = '“${_habitName(_habitId!)}” deleted.';
            await habits.deleteHabit(_habitId!);
          } else {
            message = '“${_taskTitle(_taskId!)}” deleted.';
            await tasks.deleteTask(_taskId!);
          }
        case VoiceIntent.logMiss:
          await reflections.createHabitReflection(
            habitId: _habitId!,
            missedDate: _date ?? today,
            reason: _reasonKey ?? 'custom',
            followUpAnswer: _reasonKey == null ? cmd.reasonText : null,
          );
          message = AppStrings.voiceMissSaved;
        case VoiceIntent.unknown:
          return;
      }

      // The sheet may have been closed — or another route pushed on top of
      // it — while the write above was in flight. `mounted` alone survives
      // a pop's own closing animation, so check the route is still the one
      // on top before popping it again or showing a snackbar over it. Still
      // mounted but no longer current: leave "saving" so the sheet doesn't
      // get stuck with Close disabled and back blocked once it's current
      // again.
      if (!mounted) return;
      if (route?.isCurrent != true) {
        setState(() => _phase = _Phase.idle);
        return;
      }
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              notificationsOff
                  ? '$message ${AppStrings.notificationsOff}'
                  : message,
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      debugPrint('Voice: save failed: $e');
      if (!mounted) return;
      setState(() {
        _phase = _Phase.parsed;
        _message = AppStrings.voiceSaveFailed;
      });
    }
  }

  /// Never fails the save: the habit already exists, and an error here would
  /// invite a second Confirm — a duplicate habit.
  static Future<void> _rememberCorrection(String name, int categoryId) async {
    try {
      await CategoryMemoryService.remember(name, categoryId);
    } catch (e) {
      debugPrint('Voice: could not remember category: $e');
    }
  }

  String _habitName(int id) =>
      _habitChoices.where((h) => h.id == id).firstOrNull?.name ?? '';

  String _taskTitle(int id) =>
      _taskChoices.where((t) => t.id == id).firstOrNull?.title ?? '';

  String _dateLabel(DateTime date) {
    final today = ref.read(currentDateProvider);
    if (date.startOfDay == today) return AppStrings.todayLabel.toLowerCase();
    if (date.startOfDay == today.addDays(1)) return 'tomorrow';
    return DateFormat('EEE, MMM d').format(date);
  }

  Future<void> _pickDate() async {
    final today = ref.read(currentDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.addDays(365 * 2),
    );
    if (picked != null) setState(() => _date = picked.startOfDay);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Watched so matching data is loaded by the time a result arrives.
    ref.watch(activeHabitsProvider);
    ref.watch(todaysTasksProvider);
    ref.watch(tasksProvider);
    ref.watch(allHabitsProvider);
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? <Category>[];
    final doneToday = <int>{
      for (final h
          in ref.watch(todaysHabitsProvider).asData?.value ??
              <HabitWithCompletion>[])
        if (h.isCompletedToday) h.habitId,
    };

    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final preferred = media.size.height * 0.85;
    final available = media.size.height - keyboardInset - media.padding.top;

    return PopScope(
      canPop: _phase != _Phase.saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Container(
          height: preferred < available ? preferred : available,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.voiceTitle,
                        style: context.textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: _phase == _Phase.saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text(AppStrings.voiceClose),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      Center(child: _buildMic()),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        switch (_phase) {
                          _Phase.listening => AppStrings.voiceListening,
                          _ => _message ?? AppStrings.voiceHint,
                        },
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: _phase == _Phase.error || _message != null
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (_usedOnline) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          AppStrings.voiceOnlineNotice,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _buildInput(),
                      const SizedBox(height: AppSpacing.lg),
                      if (_cmd != null)
                        _buildCard(categories, doneToday)
                      else
                        _buildExamples(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMic() {
    final listening = _phase == _Phase.listening;
    return Semantics(
      button: true,
      label: listening ? 'Stop listening' : 'Start listening',
      child: GestureDetector(
        onTap: _phase == _Phase.saving ? null : _toggleMic,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: listening ? AppColors.primary : AppColors.surfaceVariant,
            boxShadow: AppShadows.sm,
          ),
          child: Icon(
            listening ? Icons.stop_rounded : Icons.mic_rounded,
            size: AppSizes.iconLg,
            color: listening ? AppColors.textOnPrimary : AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return TextField(
      controller: _input,
      textInputAction: TextInputAction.send,
      onTap: () {
        // _cmd is always null here — the sheet is only ever listening with
        // no parsed command on screen.
        if (_phase == _Phase.listening) {
          _stopRun();
          setState(() => _phase = _Phase.idle);
        }
      },
      onSubmitted: (_) => _parse(),
      style: context.textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: AppStrings.voiceTypeHint,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: 'Send',
          icon: Icon(Icons.send_rounded, color: AppColors.primary),
          onPressed: _parse,
        ),
      ),
    );
  }

  Widget _buildExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final example in AppStrings.voiceExamples)
          _ExampleRow(
            text: example,
            onTap: () {
              _input.text = example;
              _parse();
            },
          ),
      ],
    );
  }

  Widget _buildCard(List<Category> categories, Set<int> doneToday) {
    final cmd = _cmd!;
    final children = switch (cmd.intent) {
      VoiceIntent.createHabit => _createHabitFields(categories),
      VoiceIntent.createReminderTask => _taskFields(),
      VoiceIntent.completeHabit => _completeFields(doneToday),
      VoiceIntent.logMiss => _missFields(),
      VoiceIntent.deleteItem => _deleteFields(),
      VoiceIntent.unknown => [
        Text(AppStrings.voiceUnknownTitle, style: context.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        _buildExamples(),
      ],
    };
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
    child: Text(
      text,
      style: context.textTheme.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _nameField({required int maxLength}) => TextField(
    controller: _name,
    onChanged: (_) => setState(() {}),
    inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
    style: context.textTheme.bodyLarge,
    decoration: InputDecoration(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: AppRadius.input,
        borderSide: BorderSide.none,
      ),
    ),
  );

  List<Widget> _createHabitFields(List<Category> categories) => [
    Text('New habit', style: context.textTheme.titleMedium),
    _label(AppStrings.habitNameLabel),
    _nameField(maxLength: 100),
    _label(AppStrings.categoryLabel),
    CategoryPicker(
      categories: categories,
      selected: _category,
      onSelected: (c) => setState(() => _category = c),
    ),
    _label(AppStrings.frequencyLabel),
    FrequencySelector(
      frequencyType: _frequencyType,
      specificDays: _days,
      onFrequencyTypeChanged: (v) => setState(() => _frequencyType = v),
      onSpecificDaysChanged: (v) => setState(() => _days = v),
    ),
    _label(AppStrings.reminderLabel),
    ReminderTimeField(
      minuteOfDay: _minute,
      onChanged: (v) => setState(() => _minute = v),
    ),
  ];

  List<Widget> _taskFields() => [
    Text('New task', style: context.textTheme.titleMedium),
    _label('Title'),
    _nameField(maxLength: 200),
    _label('Due'),
    GestureDetector(
      onTap: _pickDate,
      child: Container(
        height: AppSizes.inputHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.input,
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_rounded,
              size: AppSizes.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _date == null ? 'Pick a date' : _capitalized(_dateLabel(_date!)),
              style: context.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: AppSpacing.sm),
    ReminderTimeField(
      minuteOfDay: _minute,
      emptyLabel: AppStrings.voiceAddTime,
      onChanged: (v) => setState(() => _minute = v),
    ),
  ];

  List<Widget> _completeFields(Set<int> doneToday) {
    if (_noMatch) {
      return [
        Text(
          'No habit or task called “${_cmd!.text}” today.',
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _switchToCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text('Create habit “${_cmd!.text}”'),
          ),
        ),
      ];
    }
    final single = _habitChoices.length + _taskChoices.length == 1;
    final selectedHabit = _habitId;
    return [
      if (single && selectedHabit != null) ...[
        Text(
          'Mark “${_habitName(selectedHabit)}” as done for today',
          style: context.textTheme.titleMedium,
        ),
        if (doneToday.contains(selectedHabit)) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.voiceAlreadyDone,
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ] else if (single && _taskId != null)
        Text(
          'Mark task “${_taskChoices.single.title}” as done',
          style: context.textTheme.titleMedium,
        )
      else
        ..._whichOne(),
    ];
  }

  /// A pick-one list over the matched habits and tasks.
  List<Widget> _whichOne() => [
    Text(AppStrings.voiceWhichOne, style: context.textTheme.titleMedium),
    const SizedBox(height: AppSpacing.sm),
    for (final h in _habitChoices)
      _ChoiceRow(
        label: h.name,
        selected: _habitId == h.id,
        onTap: () => setState(() {
          _habitId = h.id;
          _taskId = null;
        }),
      ),
    for (final t in _taskChoices)
      _ChoiceRow(
        label: 'Task: ${t.title}',
        selected: _taskId == t.id,
        onTap: () => setState(() {
          _taskId = t.id;
          _habitId = null;
        }),
      ),
  ];

  List<Widget> _deleteFields() {
    if (_noMatch) {
      return [
        Text(
          'No habit or task called “${_cmd!.text}”.',
          style: context.textTheme.bodyMedium,
        ),
      ];
    }
    final single = _habitChoices.length + _taskChoices.length == 1;
    final habitId = _habitId;
    return [
      if (!single)
        ..._whichOne()
      else if (habitId != null)
        Text(
          'Delete habit “${_habitName(habitId)}”?',
          style: context.textTheme.titleMedium,
        )
      else
        Text(
          'Delete task “${_taskTitle(_taskId!)}”?',
          style: context.textTheme.titleMedium,
        ),
      if (habitId != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.voiceDeleteHabitNote,
          style: context.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ];
  }

  /// Atomic reason keys `reasonDisplayInfo` has a real label for — excludes
  /// its legacy bare-category fallbacks (energy/time/mind/…).
  static const _kMissReasonKeys = [
    'low_energy',
    'poor_sleep',
    'felt_sick',
    'burned_out',
    'too_busy',
    'unexpected_work',
    'meetings',
    'family',
    'lost_motivation',
    'procrastinated',
    'forgot',
    'felt_overwhelmed',
    'couldnt_focus',
    'traveling',
    'weather',
    'no_equipment',
    'outside_home',
    'needed_rest',
    'mental_break',
    'personal_event',
    'emergency',
  ];

  List<Widget> _missFields() {
    final cmd = _cmd!;
    final today = ref.read(currentDateProvider);
    final reasonKey = _reasonKey;
    return [
      Text('Log a missed habit', style: context.textTheme.titleMedium),
      if (_habitChoices.length == 1 && _habitId != null) ...[
        _label('Habit'),
        Text(_habitName(_habitId!), style: context.textTheme.bodyLarge),
      ] else ...[
        _label(AppStrings.voiceWhichOne),
        for (final h in _habitChoices)
          _ChoiceRow(
            label: h.name,
            selected: _habitId == h.id,
            onTap: () => setState(() => _habitId = h.id),
          ),
      ],
      _label('When'),
      Text(
        _date == today.addDays(-1)
            ? AppStrings.yesterdayLabel
            : AppStrings.todayLabel,
        style: context.textTheme.bodyLarge,
      ),
      _label('Why'),
      if (reasonKey != null)
        Text(
          reasonDisplayInfo(reasonKey).label,
          style: context.textTheme.bodyLarge,
        )
      else if (cmd.reasonText?.isNotEmpty ?? false)
        Text('“${cmd.reasonText}”', style: context.textTheme.bodyLarge)
      else ...[
        Text(
          AppStrings.voiceNoReason,
          style: context.textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [for (final key in _kMissReasonKeys) _reasonChip(key)],
        ),
      ],
    ];
  }

  Widget _reasonChip(String key) {
    final info = reasonDisplayInfo(key);
    final selected = _reasonKey == key;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: () => setState(() => _reasonKey = key),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: AppRadius.input,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            info.label,
            style: context.textTheme.bodySmall?.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  static String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildFooter() {
    final saving = _phase == _Phase.saving;
    final deleting = _cmd?.intent == VoiceIntent.deleteItem;
    final color = deleting ? AppColors.error : AppColors.primary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: ElevatedButton(
            onPressed: _canConfirm ? _confirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: AppColors.textOnPrimary,
              disabledBackgroundColor: color.withValues(alpha: 0.5),
              disabledForegroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
            ),
            child: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    deleting ? AppStrings.voiceDelete : AppStrings.voiceConfirm,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.input,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: AppSizes.iconMd,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '“$text”',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.input,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: AppSizes.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(label, style: context.textTheme.bodyLarge)),
            ],
          ),
        ),
      ),
    );
  }
}
