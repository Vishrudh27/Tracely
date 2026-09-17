/// Pool of motivational quotes shown on the ReflectionScreen.
///
/// Quotes are selected deterministically based on day-of-year so the user
/// sees a different quote each day but the same quote on the same day
/// (reproducible, not random).
final class QuoteConstants {
  QuoteConstants._();

  static const List<({String text, String author})> quotes = [
    (
      text:
          '"Small disciplines repeated with consistency lead to remarkable achievements."',
      author: '— John C. Maxwell',
    ),
    (
      text: '"We are what we repeatedly do. Excellence, then, is not an act, but a habit."',
      author: '— Aristotle',
    ),
    (
      text: '"Success is the sum of small efforts, repeated day in and day out."',
      author: '— Robert Collier',
    ),
    (
      text: '"Motivation is what gets you started. Habit is what keeps you going."',
      author: '— Jim Ryun',
    ),
    (
      text: '"The secret of your future is hidden in your daily routine."',
      author: '— Mike Murdock',
    ),
    (
      text: '"You\'ll never change your life until you change something you do daily."',
      author: '— John C. Maxwell',
    ),
    (
      text: '"First, forget inspiration. Habit is more dependable."',
      author: '— Octavia Butler',
    ),
    (
      text: '"The chains of habit are too light to be felt until they are too heavy to be broken."',
      author: '— Warren Buffett',
    ),
    (
      text: '"A year from now you may wish you had started today."',
      author: '— Karen Lamb',
    ),
    (
      text: '"Consistency is the true foundation of trust."',
      author: '— Roy T. Bennett',
    ),
    (
      text: '"Begin with the end in mind — but start with today\'s action."',
      author: '— Stephen Covey',
    ),
    (
      text: '"The man who moves a mountain begins by carrying away small stones."',
      author: '— Confucius',
    ),
    (
      text: '"It does not matter how slowly you go as long as you do not stop."',
      author: '— Confucius',
    ),
    (
      text: '"Start where you are. Use what you have. Do what you can."',
      author: '— Arthur Ashe',
    ),
    (
      text: '"Little by little, a little becomes a lot."',
      author: '— Tanzanian Proverb',
    ),
    (
      text: '"An ounce of practice is worth more than tons of preaching."',
      author: '— Mahatma Gandhi',
    ),
    (
      text: '"Progress is the sum of small wins."',
      author: '— Tracely',
    ),
    (
      text: '"The only bad workout is the one that didn\'t happen."',
      author: '— Unknown',
    ),
    (
      text: '"Showing up is half the work. Doing it every day is the other half."',
      author: '— Tracely',
    ),
    (
      text: '"Small wins compound. Trust the process."',
      author: '— Tracely',
    ),
  ];

  /// Returns the quote for [date] (default: today), selected by day-of-year.
  ///
  /// The day index is derived from the calendar date alone. The previous
  /// version subtracted two separate `DateTime.now()` reads as a Duration,
  /// which meant a daylight-saving shift could repeat or skip a day's quote.
  static ({String text, String author}) todaysQuote([DateTime? date]) {
    return quotes[dayOfYear(date ?? DateTime.now()) % quotes.length];
  }

  /// Zero-based day index within [date]'s year.
  ///
  /// Computed in UTC so it counts calendar days, never elapsed hours.
  static int dayOfYear(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(date.year, 1, 1))
        .inDays;
  }
}
