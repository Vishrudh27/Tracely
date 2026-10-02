/// All user-facing strings for Tracely.
///
/// Rules:
/// - Never write inline strings in widget files.
/// - Always use AppStrings.* for any displayed text.
/// - All copy is positively framed — never punishing or guilt-inducing.
final class AppStrings {
  AppStrings._();

  // ---------------------------------------------------------------------------
  // App
  // ---------------------------------------------------------------------------

  static const String appName = 'Tracely';
  /// Stitch's splash wordmark line — the brand promise, not a slogan.
  static const String appTagline = 'Know why, not just what';

  // ---------------------------------------------------------------------------
  // Greetings (time-based, pulled in by GreetingUtils)
  // ---------------------------------------------------------------------------

  static const String greetingMorning = 'Good Morning';
  static const String greetingAfternoon = 'Good Afternoon';
  static const String greetingEvening = 'Good Evening';

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------

  static const String onboarding1Headline = 'Every tracker shows what you missed.';
  static const String onboarding1Body =
      'None of them show why. That blank space is the whole reason Tracely exists.';

  static const String onboarding2Headline =
      'When you miss a day, we ask one gentle question.';
  static const String onboarding2Body =
      'One tap. Always skippable. Never a guilt trip.';

  static const String onboarding3Headline = 'Start with one habit.';
  static const String onboarding3Body =
      'Not ten. One you could do tomorrow even on a bad day.';

  static const String onboardingNext = 'Next';
  static const String onboardingSkip = 'Skip';
  static const String onboardingCreateFirstHabit = 'Create my first habit';

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  static const String dashboardTitle = 'Today';
  static const String sectionTodaysHabits = "Today's Habits";
  static const String sectionTodaysTasks = "Today's Tasks";
  static const String sectionWeeklyProgress = 'This Week';
  static const String sectionRecentActivity = 'Recent Activity';

  // Progress card copy — headline + subtitle pair, keyed off habits remaining
  static const String progressAllDoneHeadline = 'All completed';
  static const String progressAllDoneSubtitle = 'Quiet rest ahead';
  static const String progressAlmostHeadline = 'Almost there';
  static const String progressAlmostSubtitle = '1 habit left';
  static const String progressNormalHeadline = 'Nicely paced';

  // Motivation footer — rotated daily
  static const List<String> motivationFooter = [
    'Progress is the sum of small wins.',
    'Small steps, every day.',
    'Consistency over perfection.',
    'Show up — the rest follows.',
    'Progress, not perfection.',
    'One habit at a time.',
    'Every day is a new beginning.',
    'You\'re building something real.',
    'Patience is a habit too.',
  ];

  // ---------------------------------------------------------------------------
  // Empty States — always warm, never blunt
  // ---------------------------------------------------------------------------

  static const String emptyDashboardTitle = 'Ready when you are';
  static const String emptyDashboardBody =
      'Add your first habit and start building.';
  static const String emptyDashboardCta = 'Add First Habit';
  static const String emptyDashboardSubtitle = 'Fresh start ahead.';
  // Quote reuses motivationFooter[0] — see DashboardEmptyView.
  static const String emptyDashboardTipTitle = 'A quiet ritual';
  static const String emptyDashboardTipBody =
      'Start small. Even two minutes of reading or a morning glass of '
      'water counts.';

  // Rest day — habits exist but none are scheduled today (not in Stitch).
  static const String restDayGreetingSubtitle = 'Enjoy the rest.';
  static const String restDayTitle = 'Nothing due today';
  static const String restDayBody =
      "Your habits aren't scheduled today. Take the day off.";

  static const String emptyHabitsTitle = 'A blank page is full of possibility';
  static const String emptyHabitsBody =
      'Add a habit to begin your journey.';
  static const String emptyHabitsCta = 'Create a Habit';

  static const String emptyActivityTitle = 'Your story starts here';
  static const String emptyActivityBody =
      'Completed habits will appear here as you build momentum.';

  // ---------------------------------------------------------------------------
  // Error States
  // ---------------------------------------------------------------------------

  static const String errorDashboardTitle = "Couldn't load today";
  static const String errorDashboardBody =
      'Something went wrong reading your habits. Your data is safe.';
  static const String errorDashboardCta = 'Try Again';

  // ---------------------------------------------------------------------------
  // Habits
  // ---------------------------------------------------------------------------

  static const String habitsScreenTitle = 'Your Habits';
  static const String filterAll = 'All';
  static const String filterActive = 'Active';
  static const String filterArchived = 'Archived';

  // Add / Edit habit form
  static const String habitNameHint = 'Morning walk';
  static const String habitNameLabel = 'Name';
  static const String categoryLabel = 'Category';
  static const String frequencyLabel = 'Frequency';
  static const String reminderLabel = 'Gentle reminder';
  static const String reminderAdd = 'Add a reminder time';
  static const String notificationsOff =
      'Notifications are off for Tracely. Turn them on in system settings.';
  static const String habitReminderBody = 'A gentle nudge — whenever you’re ready.';
  static const String taskReminderBody = 'Your task is due now.';
  static const String iconLabel = 'Icon';
  static const String saveHabitButton = 'Save';
  static const String updateHabitButton = 'Save';
  static const String archiveHabitButton = 'Archive this habit';

  static const String archiveConfirmTitle = 'Archive this habit?';
  static const String archiveConfirmBody =
      'You can bring it back anytime from the Archived filter.';
  static const String archiveConfirmCta = 'Archive';
  static const String archiveCancelCta = 'Keep it';

  // Frequency options
  static const String frequencyDaily = 'Daily';
  static const String frequencySpecificDays = 'Specific days';
  static const String frequencyXPerWeek = 'Times per week';

  // Day abbreviations
  static const List<String> dayAbbreviations = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];
  static const List<String> dayFullNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  static const String tasksScreenTitle = 'Tasks';
  static const String taskFilterToday = 'Today';
  static const String taskFilterUpcoming = 'Upcoming';
  static const String taskFilterOverdue = 'Overdue';
  static const String taskFilterDone = 'Done';

  static const String taskGroupOverdue = 'OVERDUE';
  static const String taskGroupToday = 'TODAY';
  static const String taskGroupTomorrow = 'TOMORROW';

  static const String emptyTasksTitle = 'Nothing on your plate';
  static const String emptyTasksBody =
      'Add a task for the things that only need doing once.';
  static const String emptyTasksCta = 'Add a Task';

  // Add Task form
  static const String addTaskTitle = 'New Task';
  static const String taskNameLabel = 'What needs doing?';
  static const String taskNameHint = 'Finish the assignment';
  static const String taskDueLabel = 'Due';
  static const String taskDueDateToday = 'Today';
  static const String taskPriorityLabel = 'Priority';
  static const String taskPriorityLow = 'Low';
  static const String taskPriorityNormal = 'Normal';
  static const String taskPriorityHigh = 'High';
  static const String taskNotesLabel = 'Notes (optional)';
  static const String taskNotesHint = 'Anything worth remembering...';
  static const String saveTaskButton = 'Save';

  // ---------------------------------------------------------------------------
  // Statistics (Phase 3 — strings reserved here for consistency)
  // ---------------------------------------------------------------------------

  static const String statisticsTitle = 'Your Journey';
  static const String streakCurrentLabel = 'Current Streak';
  static const String streakLongestLabel = 'Longest Streak';
  static const String streakPersonalBest = 'Personal best!';
  static const String streakZeroMessage = 'Start a new streak today';
  static const String weeklyInsightTitle = 'This Week';

  // ---------------------------------------------------------------------------
  // General UI
  // ---------------------------------------------------------------------------

  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String done = 'Done';
  static const String edit = 'Edit';
  static const String back = 'Back';
  static const String continueLabel = 'Continue';
  static const String completedLabel = 'Completed';
  static const String todayLabel = 'Today';
  static const String yesterdayLabel = 'Yesterday';
  static const String daysAgoLabel = 'd ago';

  // ---------------------------------------------------------------------------
  // Voice — Talk to Tracely
  // ---------------------------------------------------------------------------

  static const String voiceTitle = 'Talk to Tracely';
  static const String voiceFabTooltip = 'Talk to Tracely';
  static const String voiceListening = 'Listening…';
  static const String voiceHint = 'Tap the mic and say what you’d like to do.';
  static const String voiceTypeHint = 'Or type it here';
  static const String voiceDidntHear =
      'Didn’t catch anything — try again, or type it.';
  static const String voiceMicUnavailable =
      'Microphone isn’t available — type it instead.';
  static const String voiceRecognizerFailed =
      'Speech recognition isn’t available right now — type it instead.';
  static const String voiceSaveFailed = 'Couldn’t save that. Please try again.';
  static const String voiceUnknownTitle =
      'Not sure what to do with that. Try something like:';
  static const List<String> voiceExamples = [
    'Add running every morning at 6',
    'Remind me to study at 9 PM',
    'Mark meditation as done',
    'I missed my workout because I was tired',
  ];
  static const String voiceConfirm = 'Confirm';
  static const String voiceClose = 'Close';
  static const String voiceWhichOne = 'Which one?';
  static const String voiceNoReason =
      'Add a reason — e.g. “…because I was tired”.';
  static const String voiceAddTime = 'Add a time';
  static const String voiceAlreadyDone = 'Already done today.';
  static const String voiceMissSaved = 'Noted. Tomorrow is a fresh start.';
  static const String voiceOnlineNotice =
      'Using Google’s online speech — install offline English for '
      'on-device recognition.';

  // ---------------------------------------------------------------------------
  // Insights — Smart suggestions
  // ---------------------------------------------------------------------------

  static const String smartSuggestionTitle = 'A small suggestion';
  static const String smartSuggestionsSetting = 'Smart suggestions';
  static const String insightMoveReminder = 'Move reminder';
  static const String insightDismiss = 'Dismiss suggestion';
  static const String usuallyDoneAround = 'Usually done around';

  // ---------------------------------------------------------------------------
  // Navigation labels
  // ---------------------------------------------------------------------------

  static const String navDashboard = 'Home';
  static const String navHabits = 'Habits';
  static const String navTasks = 'Tasks';
  static const String navStatistics = 'Statistics';
}
