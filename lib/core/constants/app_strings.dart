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
  static const String appTagline = 'Build habits. Build yourself.';

  // ---------------------------------------------------------------------------
  // Greetings (time-based, pulled in by GreetingUtils)
  // ---------------------------------------------------------------------------

  static const String greetingMorning = 'Good Morning';
  static const String greetingAfternoon = 'Good Afternoon';
  static const String greetingEvening = 'Good Evening';

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  static const String dashboardTitle = 'Today';
  static const String sectionTodaysHabits = "Today's Habits";
  static const String sectionWeeklyProgress = 'This Week';
  static const String sectionRecentActivity = 'Recent Activity';

  // Progress card copy
  static const String progressFreshStart = 'A fresh start — take it one at a time.';
  static const String progressAllDone = 'All done — beautifully consistent.';
  static const String progressKeepGoing = 'Keep going — you\'re doing great.';

  // Motivation footer — rotated daily
  static const List<String> motivationFooter = [
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

  static const String emptyHabitsTitle = 'A blank page is full of possibility';
  static const String emptyHabitsBody =
      'Add a habit to begin your journey.';
  static const String emptyHabitsCta = 'Create a Habit';

  static const String emptyActivityTitle = 'Your story starts here';
  static const String emptyActivityBody =
      'Completed habits will appear here as you build momentum.';

  // ---------------------------------------------------------------------------
  // Habits
  // ---------------------------------------------------------------------------

  static const String habitsScreenTitle = 'Your Habits';
  static const String filterAll = 'All';
  static const String filterActive = 'Active';
  static const String filterArchived = 'Archived';

  // Add / Edit habit form
  static const String habitNameHint = 'What do you want to build?';
  static const String habitNameLabel = 'Habit name';
  static const String categoryLabel = 'Category';
  static const String frequencyLabel = 'Frequency';
  static const String reminderLabel = 'Gentle reminder';
  static const String emojiLabel = 'Pick an emoji';
  static const String saveHabitButton = 'Start Building';
  static const String updateHabitButton = 'Save Changes';
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
  // Statistics (Phase 3 — strings reserved here for consistency)
  // ---------------------------------------------------------------------------

  static const String statisticsTitle = 'Your Journey';
  static const String streakCurrentLabel = 'Current Streak';
  static const String streakLongestLabel = 'Longest Streak';
  static const String streakPersonalBest = 'Personal best!';
  static const String streakZeroMessage = 'Start a new streak today 🌱';
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
  // Navigation labels
  // ---------------------------------------------------------------------------

  static const String navDashboard = 'Home';
  static const String navHabits = 'Habits';
  static const String navStatistics = 'Statistics';
}
