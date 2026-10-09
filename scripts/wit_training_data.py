"""Training utterances for the Tracely Wit.ai app.

Each entry: (text, intent, [(entity_role, substring), ...])

Design: Wit.ai only has to find WHERE the name/time/reason is in the
sentence (span extraction) and WHICH action it is (intent) — both things a
trained statistical model is much better at than regex on broken English.
It does NOT have to understand the time itself. The extracted time_phrase
span gets handed to our existing, already-tested regex time parser
(lib/core/utils/voice_command_parser.dart) in the app. Smaller job for Wit,
no need to fight wit$datetime's built-in role-naming, fewer training
examples needed to get it reliable.

Entities (all free-text, created by wit_train.py before these are posted):
  habit_name   — what habit (create_habit, complete_habit, log_miss target)
  task_name    — what task  (create_task, complete_habit, log_miss target)
  time_phrase  — the date/time/recurrence chunk, handed to the regex parser
  reason       — why a habit/task was missed (log_miss only)

Call Reminder (full-screen ring, not a soft notification) is not a separate
intent — it is a modifier on create_habit/create_task, detected the same
way the app's own regex parser detects it (app's own
lib/core/utils/voice_command_parser.dart _callReminderRe): specific
multi-word trigger phrases only ("call reminder", "call remind me",
"ring me", "remind me by call"), never a bare "call" — "call mom" is a
completely ordinary task name and must not be mistaken for the trigger.
The call_reminder examples below are tagged the same way as their plain
counterparts above (habit_name/task_name/time_phrase); Wit.ai doesn't need
a 5th intent for this, the trigger phrase itself is the signal and the app
re-runs the same _callReminderRe check on the text Wit.ai returns.

Intents: create_habit, create_task, complete_habit, log_miss, delete_item

Broken-English coverage deliberately included per intent: dropped articles,
wrong tense, missing prepositions, run-on phrasing, phonetic misspellings a
speech recognizer commonly produces (e.g. "nine clock" for "9 o'clock").
"""

TRAINING_DATA = [
    # ---------------------------------------------------------------
    # create_habit
    # ---------------------------------------------------------------
    ("add habit read book every day at 9",
     "create_habit", [("habit_name", "read book"), ("time_phrase", "every day at 9")]),
    ("create a new habit for reading daily at 9am",
     "create_habit", [("habit_name", "reading"), ("time_phrase", "daily at 9am")]),
    ("start habit gym every monday wednesday friday at 6",
     "create_habit", [("habit_name", "gym"), ("time_phrase", "every monday wednesday friday at 6")]),
    ("i want track drinking water every day",
     "create_habit", [("habit_name", "drinking water"), ("time_phrase", "every day")]),
    ("make habit meditation everyday morning 7 clock",
     "create_habit", [("habit_name", "meditation"), ("time_phrase", "everyday morning 7 clock")]),
    ("new habit for walking on weekends at 8am",
     "create_habit", [("habit_name", "walking"), ("time_phrase", "on weekends at 8am")]),
    ("habit add journaling night 10pm daily",
     "create_habit", [("habit_name", "journaling"), ("time_phrase", "night 10pm daily")]),
    ("please track habit stretching every tuesday thursday",
     "create_habit", [("habit_name", "stretching"), ("time_phrase", "every tuesday thursday")]),
    ("create habit no sugar every day",
     "create_habit", [("habit_name", "no sugar"), ("time_phrase", "every day")]),
    ("add new habit learn spanish daily 9 in morning",
     "create_habit", [("habit_name", "learn spanish"), ("time_phrase", "daily 9 in morning")]),
    ("habit for sleeping early everyday 11 pm add",
     "create_habit", [("habit_name", "sleeping early"), ("time_phrase", "everyday 11 pm")]),
    ("i wanna habit cold shower every morning 6 oclock",
     "create_habit", [("habit_name", "cold shower"), ("time_phrase", "every morning 6 oclock")]),
    ("can you add habit running saturday sunday 7am",
     "create_habit", [("habit_name", "running"), ("time_phrase", "saturday sunday 7am")]),
    ("track my habit vitamins every day 8 morning",
     "create_habit", [("habit_name", "vitamins"), ("time_phrase", "every day 8 morning")]),
    ("habit reading book weekdays 9 night add it",
     "create_habit", [("habit_name", "reading book"), ("time_phrase", "weekdays 9 night")]),

    # ---------------------------------------------------------------
    # create_habit / create_task with a Call Reminder trigger phrase in the
    # sentence. The trigger itself is detected locally by the app's own
    # regex (not a Wit entity) — these examples only teach Wit to keep
    # habit_name/task_name/time_phrase spans clean when that phrase is
    # sitting in the middle of the sentence.
    # ---------------------------------------------------------------
    ("call remind me gym every day at 6",
     "create_habit", [("habit_name", "gym"), ("time_phrase", "every day at 6")]),
    ("set a call reminder for workout daily 7 morning",
     "create_habit", [("habit_name", "workout"), ("time_phrase", "daily 7 morning")]),
    ("ring me for meditation every day 9 night",
     "create_habit", [("habit_name", "meditation"), ("time_phrase", "every day 9 night")]),
    ("call reminder drink water every day",
     "create_habit", [("habit_name", "drink water"), ("time_phrase", "every day")]),
    ("remind me by call to take medicine every day 8am",
     "create_habit", [("habit_name", "take medicine"), ("time_phrase", "every day 8am")]),
    ("call remind me dentist appointment tomorrow 3pm",
     "create_task", [("task_name", "dentist appointment"), ("time_phrase", "tomorrow 3pm")]),
    ("set call reminder pay rent on 1st",
     "create_task", [("task_name", "pay rent"), ("time_phrase", "on 1st")]),
    ("ring me to call mom tomorrow at 5",
     "create_task", [("task_name", "call mom"), ("time_phrase", "tomorrow at 5")]),
    ("call alarm for meeting with client wednesday 2pm",
     "create_task", [("task_name", "meeting with client"), ("time_phrase", "wednesday 2pm")]),
    ("like a call reminder wake up 6 morning daily",
     "create_habit", [("habit_name", "wake up"), ("time_phrase", "6 morning daily")]),
    ("phone me for stretching every day 7 evening",
     "create_habit", [("habit_name", "stretching"), ("time_phrase", "every day 7 evening")]),
    ("ring alarm for yoga daily 6 morning",
     "create_habit", [("habit_name", "yoga"), ("time_phrase", "daily 6 morning")]),
    ("voice call reminder for running every monday wednesday friday",
     "create_habit", [("habit_name", "running"), ("time_phrase", "every monday wednesday friday")]),
    ("call notify me for vitamins every day 9am",
     "create_habit", [("habit_name", "vitamins"), ("time_phrase", "every day 9am")]),
    ("phone reminder for car service next week",
     "create_task", [("task_name", "car service"), ("time_phrase", "next week")]),
    ("ring reminder dentist appointment tomorrow 2pm",
     "create_task", [("task_name", "dentist appointment"), ("time_phrase", "tomorrow 2pm")]),
    ("phone me pay electricity bill by friday",
     "create_task", [("task_name", "pay electricity bill"), ("time_phrase", "by friday")]),

    # ---------------------------------------------------------------
    # create_task (one-off / reminder style)
    # ---------------------------------------------------------------
    ("remind me gym tmrw",
     "create_task", [("task_name", "gym"), ("time_phrase", "tmrw")]),
    ("add task call mom tomorrow at 5pm",
     "create_task", [("task_name", "call mom"), ("time_phrase", "tomorrow at 5pm")]),
    ("set reminder pay rent on 1st",
     "create_task", [("task_name", "pay rent"), ("time_phrase", "on 1st")]),
    ("task for dentist appointment friday 3 clock",
     "create_task", [("task_name", "dentist appointment"), ("time_phrase", "friday 3 clock")]),
    ("i need reminder submit report tonight 9",
     "create_task", [("task_name", "submit report"), ("time_phrase", "tonight 9")]),
    ("remind buy groceries today evening",
     "create_task", [("task_name", "buy groceries"), ("time_phrase", "today evening")]),
    ("add to tasks fix bike this weekend",
     "create_task", [("task_name", "fix bike"), ("time_phrase", "this weekend")]),
    ("new task email boss monday morning 10",
     "create_task", [("task_name", "email boss"), ("time_phrase", "monday morning 10")]),
    ("create task for car service next week",
     "create_task", [("task_name", "car service"), ("time_phrase", "next week")]),
    ("alert me meeting with client wednesday 2pm",
     "create_task", [("task_name", "meeting with client"), ("time_phrase", "wednesday 2pm")]),
    ("task renew passport before friday",
     "create_task", [("task_name", "renew passport"), ("time_phrase", "before friday")]),
    ("remind me for pick up laundry 6 evening",
     "create_task", [("task_name", "pick up laundry"), ("time_phrase", "6 evening")]),
    ("add task pay electricity bill day after tomorrow",
     "create_task", [("task_name", "pay electricity bill"), ("time_phrase", "day after tomorrow")]),
    ("task book flight tickets by sunday",
     "create_task", [("task_name", "book flight tickets"), ("time_phrase", "by sunday")]),
    ("set task clean house saturday 11 morning",
     "create_task", [("task_name", "clean house"), ("time_phrase", "saturday 11 morning")]),

    # ---------------------------------------------------------------
    # complete_habit (mark as done — habit or task, same intent, target
    # distinguished by which entity fired)
    # ---------------------------------------------------------------
    ("i completed workout yesterday",
     "complete_habit", [("habit_name", "workout"), ("time_phrase", "yesterday")]),
    ("mark gym as done",
     "complete_habit", [("habit_name", "gym")]),
    ("i did reading today",
     "complete_habit", [("habit_name", "reading"), ("time_phrase", "today")]),
    ("finished meditation already",
     "complete_habit", [("habit_name", "meditation")]),
    ("done with drinking water task",
     "complete_habit", [("task_name", "drinking water")]),
    ("i have done call mom",
     "complete_habit", [("task_name", "call mom")]),
    ("mark task pay rent complete",
     "complete_habit", [("task_name", "pay rent")]),
    ("habit stretching is done for today",
     "complete_habit", [("habit_name", "stretching"), ("time_phrase", "today")]),
    ("just finished running",
     "complete_habit", [("habit_name", "running")]),
    ("completed dentist appointment task",
     "complete_habit", [("task_name", "dentist appointment")]),
    ("i already did cold shower this morning",
     "complete_habit", [("habit_name", "cold shower"), ("time_phrase", "this morning")]),
    ("mark as complete journaling",
     "complete_habit", [("habit_name", "journaling")]),
    ("task email boss is finished",
     "complete_habit", [("task_name", "email boss")]),
    ("i over with vitamins habit",
     "complete_habit", [("habit_name", "vitamins")]),
    ("done gym yesterday night",
     "complete_habit", [("habit_name", "gym"), ("time_phrase", "yesterday night")]),

    # ---------------------------------------------------------------
    # log_miss (missed / skipped, with reason)
    # ---------------------------------------------------------------
    ("i missed gym yesterday because i was sick",
     "log_miss", [("habit_name", "gym"), ("time_phrase", "yesterday"), ("reason", "i was sick")]),
    ("skipped reading today was too tired",
     "log_miss", [("habit_name", "reading"), ("time_phrase", "today"), ("reason", "too tired")]),
    ("i miss meditation no time",
     "log_miss", [("habit_name", "meditation"), ("reason", "no time")]),
    ("didnt do workout yesterday had work",
     "log_miss", [("habit_name", "workout"), ("time_phrase", "yesterday"), ("reason", "had work")]),
    ("missed task call mom was busy",
     "log_miss", [("task_name", "call mom"), ("reason", "was busy")]),
    ("skip stretching this morning felt lazy",
     "log_miss", [("habit_name", "stretching"), ("time_phrase", "this morning"), ("reason", "felt lazy")]),
    ("i couldnt do cold shower today",
     "log_miss", [("habit_name", "cold shower"), ("time_phrase", "today")]),
    ("missed vitamins forgot completely",
     "log_miss", [("habit_name", "vitamins"), ("reason", "forgot completely")]),
    ("skipped gym yesterday because rain",
     "log_miss", [("habit_name", "gym"), ("time_phrase", "yesterday"), ("reason", "rain")]),
    ("i was not able to do running was injured",
     "log_miss", [("habit_name", "running"), ("reason", "was injured")]),
    ("missed dentist appointment task rescheduled",
     "log_miss", [("task_name", "dentist appointment"), ("reason", "rescheduled")]),
    ("habit journaling skipped no energy",
     "log_miss", [("habit_name", "journaling"), ("reason", "no energy")]),
    ("i missd gym bcoz tired",
     "log_miss", [("habit_name", "gym"), ("reason", "tired")]),
    ("missd workout today was sick",
     "log_miss", [("habit_name", "workout"), ("time_phrase", "today"), ("reason", "was sick")]),
    ("skiped yoga this morning no time",
     "log_miss", [("habit_name", "yoga"), ("time_phrase", "this morning"), ("reason", "no time")]),
    ("skipd gym bcoz lazy",
     "log_miss", [("habit_name", "gym"), ("reason", "lazy")]),
    ("i forgot to do reading today",
     "log_miss", [("habit_name", "reading"), ("time_phrase", "today")]),
    ("forgot habit drinking water yesterday",
     "log_miss", [("habit_name", "drinking water"), ("time_phrase", "yesterday")]),
    ("coudnt do meditation today was busy",
     "log_miss", [("habit_name", "meditation"), ("time_phrase", "today"), ("reason", "was busy")]),
    ("didnt do my running habit rain",
     "log_miss", [("habit_name", "running"), ("reason", "rain")]),
    ("havent done stretching today no energy",
     "log_miss", [("habit_name", "stretching"), ("time_phrase", "today"), ("reason", "no energy")]),
    ("missed task call mom was busy today",
     "log_miss", [("task_name", "call mom"), ("time_phrase", "today"), ("reason", "was busy")]),
    ("miss my cold shower habit this morning too cold",
     "log_miss", [("habit_name", "cold shower"), ("time_phrase", "this morning"), ("reason", "too cold")]),
    ("i not able to do workout yesterday bcoz injury",
     "log_miss", [("habit_name", "workout"), ("time_phrase", "yesterday"), ("reason", "injury")]),
    ("skip habit vitamins forgot completly",
     "log_miss", [("habit_name", "vitamins"), ("reason", "forgot completly")]),
    ("missed meditaton todey was tired",
     "log_miss", [("habit_name", "meditaton"), ("time_phrase", "todey"), ("reason", "was tired")]),
    ("couldnt complete task dentist appointment was busy",
     "log_miss", [("task_name", "dentist appointment"), ("reason", "was busy")]),

    # ---------------------------------------------------------------
    # delete_item
    # ---------------------------------------------------------------
    ("delete habit gym",
     "delete_item", [("habit_name", "gym")]),
    ("remove task call mom",
     "delete_item", [("task_name", "call mom")]),
    ("get rid of habit meditation",
     "delete_item", [("habit_name", "meditation")]),
    ("erase task pay rent",
     "delete_item", [("task_name", "pay rent")]),
    ("delete the reading habit",
     "delete_item", [("habit_name", "reading")]),
    ("remove reminder dentist appointment",
     "delete_item", [("task_name", "dentist appointment")]),
    ("delete habit cold shower please",
     "delete_item", [("habit_name", "cold shower")]),
    ("i want delete task buy groceries",
     "delete_item", [("task_name", "buy groceries")]),
]
