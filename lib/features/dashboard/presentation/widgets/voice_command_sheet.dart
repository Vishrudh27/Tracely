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
import '../../../../data/services/reminder_service.dart';
import '../../../analytics/presentation/widgets/most_common_reasons_card.dart';
import '../../../habits/presentation/widgets/category_picker.dart';
import '../../../habits/presentation/widgets/frequency_selector.dart';
import '../../../habits/presentation/widgets/reminder_time_field.dart';

/// "Talk to Tracely" — speak (or type) a command, check the parsed result,
/// confirm. Nothing is written until Confirm.
///
/// Speech uses the phone's own recognizer, on-device first. If the offline
/// pack is missing it retries once online; typing always works.
class VoiceCommandSheet extends ConsumerStatefulWidget {
  const VoiceCommandSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
      builder: (_) => const VoiceCommandSheet._(),
    );
  }

  @override
  ConsumerState<VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

enum _Phase { idle, listening, parsed, error, saving }

class _VoiceCommandSheetState extends ConsumerState<VoiceCommandSheet> {
  // Speech timeouts, not animations — AppDurations would collapse these to
  // zero under Reduce motion and stop listening instantly.
  static const _listenFor = Duration(seconds: 20);
  static const _pauseFor = Duration(seconds: 3);

  /// Errors that mean "on-device recognition can't do this here" — worth one
  /// retry with the online recognizer. Below API 31 `onDevice` only *prefers*
  /// offline, so a missing pack shows up as a network/server error.
  static const _fallbackErrors = {
    'error_language_not_supported',
    'error_language_unavailable',
    'error_network',
    'error_network_timeout',
    'error_server',
    'error_server_disconnected',
    'error_too_many_requests',
  };

  /// Ended without words — not a failure worth a scary message.
  static const _silentErrors = {
    'error_no_match',
    'error_speech_timeout',
    'error_client',
  };

  // ponytail: session-only memory that the offline pack is missing; persist
  // it if users complain about the first on-device attempt each launch.
  static bool _preferOnline = false;

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

  bool _listenersBound = false;
  bool _onDeviceAttempt = false;
  bool _retrying = false;
  bool _usedOnline = false;
  String? _localeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startListening();
    });
  }

  @override
  void dispose() {
    if (_speech.isListening) _speech.cancel();
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

  Future<void> _startListening() async {
    FocusScope.of(context).unfocus();
    // Mic tap = a new command; a stale transcript would otherwise be
    // re-parsed on a silent listen and wipe the card's edits.
    _input.clear();
    setState(() {
      _cmd = null;
      _phase = _Phase.listening;
      _message = null;
      _retrying = false;
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
      if (!ok) return _fail(AppStrings.voiceMicUnavailable);
      _localeId ??= await _englishLocaleId();
      if (!mounted) return;
      await _listen(onDevice: !_preferOnline);
    } catch (e) {
      debugPrint('Voice: start failed: $e');
      _fail(AppStrings.voiceMicUnavailable);
    }
  }

  /// The phone's locale when it's an English one (en_IN, en_GB…) — forcing
  /// en_US can fail when only another English pack is installed offline.
  Future<String> _englishLocaleId() async {
    final id = (await _speech.systemLocale())?.localeId;
    return id != null && id.toLowerCase().startsWith('en') ? id : 'en_US';
  }

  Future<void> _listen({required bool onDevice}) {
    _onDeviceAttempt = onDevice;
    return _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        onDevice: onDevice,
        partialResults: true,
        // Off on purpose: the plugin cancels *after* calling the error
        // listener, which would kill the online retry started from it.
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
        localeId: _localeId,
        listenFor: _listenFor,
        pauseFor: _pauseFor,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted || _phase != _Phase.listening) return;
    _input.text = r.recognizedWords;
    if (r.finalResult) _parse();
  }

  void _onError(SpeechRecognitionError e) {
    if (!mounted) return;
    // A "done" status can beat the error here and drop us to idle first.
    final active = _phase == _Phase.listening ||
        (_phase == _Phase.idle && _input.text.trim().isEmpty);
    if (!active) return;
    debugPrint('Voice: ${e.errorMsg} (onDevice: $_onDeviceAttempt)');

    if (_onDeviceAttempt && _fallbackErrors.contains(e.errorMsg)) {
      _preferOnline = true;
      setState(() {
        _usedOnline = true;
        _retrying = true;
        _phase = _Phase.listening;
      });
      _speech
          .cancel()
          .then((_) => _listen(onDevice: false))
          .catchError((Object _) => _fail(AppStrings.voiceRecognizerFailed));
      return;
    }

    _speech.cancel();
    if (e.errorMsg == 'error_permission') {
      return _fail(AppStrings.voiceMicUnavailable);
    }
    if (_silentErrors.contains(e.errorMsg)) {
      return _input.text.trim().isNotEmpty
          ? _parse()
          : _fail(AppStrings.voiceDidntHear);
    }
    _fail(AppStrings.voiceRecognizerFailed);
  }

  void _onStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.listeningStatus) _retrying = false;
    if (status == SpeechToText.doneStatus &&
        _phase == _Phase.listening &&
        !_retrying) {
      if (_input.text.trim().isEmpty) {
        setState(() => _phase = _Phase.idle);
      } else {
        _parse();
      }
    }
  }

  void _toggleMic() {
    if (_phase == _Phase.listening) {
      _speech.stop();
    } else {
      _startListening();
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _cmd == null ? _Phase.error : _Phase.parsed;
      _message = message;
    });
  }

  // ---------------------------------------------------------------------------
  // Parse → editable slots
  // ---------------------------------------------------------------------------

  void _parse() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (_speech.isListening) _speech.cancel();
    final now = DateTime.now();
    _apply(parseVoiceCommand(
      text,
      today: ref.read(currentDateProvider),
      nowMinute: now.hour * 60 + now.minute,
    ));
  }

  void _apply(VoiceCommand cmd) {
    final habits = ref.read(activeHabitsProvider).asData?.value ?? <Habit>[];
    final tasks = (ref.read(todaysTasksProvider).asData?.value ??
            <TaskWithCategory>[])
        .where((t) => !t.isDone)
        .toList();
    final categories =
        ref.read(categoriesProvider).asData?.value ?? <Category>[];

    setState(() {
      _cmd = cmd;
      _phase = _Phase.parsed;
      _message = null;
      _name.text = cmd.text;
      _frequencyType = cmd.frequencyType;
      _days = [...cmd.specificDays];
      _minute = cmd.minuteOfDay;
      _date = cmd.date;
      _category = null;
      _habitId = null;
      _taskId = null;
      _habitChoices = [];
      _taskChoices = [];
      _noMatch = false;

      switch (cmd.intent) {
        case VoiceIntent.createHabit:
          _category = _suggestCategory(cmd.text, categories);
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
        case VoiceIntent.createReminderTask:
        case VoiceIntent.unknown:
          break;
      }
    });
  }

  static Category? _suggestCategory(String name, List<Category> categories) {
    final builtIns = categories.where((c) => c.isBuiltIn);
    final suggested = suggestCategoryName(name);
    return builtIns.where((c) => c.name == suggested).firstOrNull ??
        builtIns.firstOrNull ??
        categories.firstOrNull;
  }

  /// "No habit called X" → offer to create it instead.
  void _switchToCreate() {
    final text = _cmd?.text ?? '';
    final name = text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
    _apply(VoiceCommand(intent: VoiceIntent.createHabit, text: name));
  }

  bool get _canConfirm {
    final cmd = _cmd;
    if (cmd == null || _phase != _Phase.parsed) return false;
    return switch (cmd.intent) {
      VoiceIntent.createHabit => _name.text.trim().isNotEmpty &&
          _category != null &&
          (_frequencyType != 'specific_days' || _days.isNotEmpty),
      VoiceIntent.createReminderTask =>
        _name.text.trim().isNotEmpty && _date != null,
      VoiceIntent.completeHabit => _habitId != null || _taskId != null,
      VoiceIntent.logMiss => _habitId != null &&
          (cmd.reasonKey != null || (cmd.reasonText?.isNotEmpty ?? false)),
      VoiceIntent.unknown => false,
    };
  }

  // ---------------------------------------------------------------------------
  // Confirm → write
  // ---------------------------------------------------------------------------

  Future<void> _confirm() async {
    final cmd = _cmd;
    if (cmd == null || !_canConfirm) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final habits = ref.read(habitRepositoryProvider);
    final tasks = ref.read(taskRepositoryProvider);
    final reflections = ref.read(reflectionDaoProvider);
    final today = ref.read(currentDateProvider);
    final name = _name.text.trim();
    final minute = _minute;
    setState(() => _phase = _Phase.saving);

    try {
      final wantsReminder = minute != null &&
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
                _frequencyType == 'specific_days' ? '[${days.join(",")}]' : null,
              ),
              reminderEnabled: drift.Value(minute != null),
              reminderTime:
                  drift.Value(minute == null ? null : formatHhMm(minute)),
            ),
          );
          message = '“$name” added$at.';
        case VoiceIntent.createReminderTask:
          await tasks.addTask(
            title: name,
            dueDate: _date!.startOfDay,
            dueTime: minute == null ? null : formatHhMm(minute),
          );
          message = '“$name” added to ${_dateLabel(_date!)}$at.';
        case VoiceIntent.completeHabit:
          if (_habitId != null) {
            await habits.setCompleted(_habitId!, today);
            message = '“${_habitName(_habitId!)}” done for today.';
          } else {
            await tasks.setTaskDone(_taskId!, true);
            message = '“${_taskChoices.firstWhere((t) => t.id == _taskId).title}” done.';
          }
        case VoiceIntent.logMiss:
          await reflections.createHabitReflection(
            habitId: _habitId!,
            missedDate: _date ?? today,
            reason: cmd.reasonKey ?? 'custom',
            followUpAnswer: cmd.reasonKey == null ? cmd.reasonText : null,
          );
          message = AppStrings.voiceMissSaved;
        case VoiceIntent.unknown:
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

  String _habitName(int id) =>
      _habitChoices.where((h) => h.id == id).firstOrNull?.name ?? '';

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
    final categories =
        ref.watch(categoriesProvider).asData?.value ?? <Category>[];
    final doneToday = <int>{
      for (final h in ref.watch(todaysHabitsProvider).asData?.value ??
          <HabitWithCompletion>[])
        if (h.isCompletedToday) h.habitId,
    };

    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final preferred = media.size.height * 0.85;
    final available = media.size.height - keyboardInset - media.padding.top;

    return Padding(
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
                    onPressed: () => Navigator.of(context).pop(),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Center(child: _buildMic()),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _phase == _Phase.listening
                          ? AppStrings.voiceListening
                          : _message ?? AppStrings.voiceHint,
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
        if (_phase == _Phase.listening) {
          _speech.cancel();
          setState(() => _phase = _cmd == null ? _Phase.idle : _Phase.parsed);
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
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.sm,
        ),
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
            style: context.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ] else if (single && _taskId != null)
        Text(
          'Mark task “${_taskChoices.single.title}” as done',
          style: context.textTheme.titleMedium,
        )
      else ...[
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
      ],
    ];
  }

  List<Widget> _missFields() {
    final cmd = _cmd!;
    final today = ref.read(currentDateProvider);
    final reason = cmd.reasonKey != null
        ? reasonDisplayInfo(cmd.reasonKey!).label
        : (cmd.reasonText?.isNotEmpty ?? false)
            ? '“${cmd.reasonText}”'
            : null;
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
      Text(
        reason ?? AppStrings.voiceNoReason,
        style: context.textTheme.bodyLarge?.copyWith(
          color: reason == null ? AppColors.textSecondary : null,
        ),
      ),
    ];
  }

  static String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _buildFooter() {
    final saving = _phase == _Phase.saving;
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
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
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
                    AppStrings.voiceConfirm,
                    style: context.textTheme.titleMedium
                        ?.copyWith(color: AppColors.textOnPrimary),
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
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
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
              Expanded(
                child: Text(label, style: context.textTheme.bodyLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
