import 'package:shared_preferences/shared_preferences.dart';

/// Controls whether the first-launch Onboarding flow should be shown.
///
/// Onboarding is shown at most once ever, on the very first app open.
/// Never throws — if preferences are unreadable, onboarding is skipped
/// rather than blocking startup or trapping the user on the same screen.
class OnboardingGateService {
  static const _kCompletedKey = 'onboarding_completed';

  /// Returns true if onboarding has already been completed or skipped.
  static Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kCompletedKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Mark onboarding as done — via Skip or via finishing the last page.
  /// Either path means the user should never see it again.
  static Future<void> markCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kCompletedKey, true);
    } catch (_) {
      // Worst case onboarding shows again on the next open.
    }
  }
}
