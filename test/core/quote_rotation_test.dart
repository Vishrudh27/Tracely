import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/quote_constants.dart';
import 'package:habit_tracker/core/utils/greeting_utils.dart';

/// The quote is picked by day-of-year. That index used to be the difference
/// between two separate `DateTime.now()` reads expressed as a Duration, so a
/// daylight-saving shift could hand two consecutive days the same index (or
/// skip one). Run under `TZ=America/New_York` to exercise the real transition.
void main() {
  group('day-of-year', () {
    test('advances by exactly one across a spring-forward', () {
      expect(
        QuoteConstants.dayOfYear(DateTime(2026, 3, 9)) -
            QuoteConstants.dayOfYear(DateTime(2026, 3, 8)),
        1,
      );
    });

    test('advances by exactly one across a fall-back', () {
      expect(
        QuoteConstants.dayOfYear(DateTime(2026, 11, 2)) -
            QuoteConstants.dayOfYear(DateTime(2026, 11, 1)),
        1,
      );
    });

    test('starts at zero on 1 January', () {
      expect(QuoteConstants.dayOfYear(DateTime(2026, 1, 1)), 0);
    });

    test('counts the leap day', () {
      expect(QuoteConstants.dayOfYear(DateTime(2028, 3, 1)), 60);
    });
  });

  group('quote selection', () {
    test('is stable within a day and changes the next day', () {
      final day = DateTime(2026, 5, 4);
      final next = DateTime(2026, 5, 5);

      expect(
        QuoteConstants.todaysQuote(day),
        QuoteConstants.todaysQuote(DateTime(2026, 5, 4, 23, 59)),
      );
      expect(
        QuoteConstants.todaysQuote(day),
        isNot(QuoteConstants.todaysQuote(next)),
      );
    });

    test('every day of a year resolves to a real quote', () {
      for (var i = 0; i < 366; i++) {
        final date = DateTime(2028, 1, 1 + i);
        final quote = QuoteConstants.todaysQuote(date);
        expect(quote.text, isNotEmpty);
        expect(quote.author, isNotEmpty);
      }
    });
  });

  group('motivation footer', () {
    test('rotates with the day and tolerates an empty pool', () {
      const pool = ['a', 'b', 'c'];
      expect(
        GreetingUtils.motivationFooter(pool, DateTime(2026, 5, 4)),
        isNot(GreetingUtils.motivationFooter(pool, DateTime(2026, 5, 5))),
      );
      expect(GreetingUtils.motivationFooter(const [], DateTime(2026, 5, 4)), '');
    });
  });
}
