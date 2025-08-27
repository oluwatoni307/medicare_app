import 'package:shared_preferences/shared_preferences.dart';

class AppStateManager {
  static const String _hasSeenOnboarding = 'has_seen_onboarding';
  
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboarding) ?? false;
  }
  
  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboarding, true);
  }
}