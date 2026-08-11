import 'package:shared_preferences/shared_preferences.dart';

/// Persists the small pieces of state that should survive an app
/// restart — which items a student has marked complete, and their
/// dark-mode preference — using the platform's local key-value store
/// (SharedPreferences: UserDefaults on iOS/macOS, SharedPreferences on
/// Android, localStorage on web).
///
/// This is deliberately not where the study content itself lives —
/// that's the bundled assets/data/study_items.json, read fresh on
/// every launch. Only per-student, per-device state belongs here.
class PreferencesRepository {
  static const _darkModeKey = 'dark_mode';

  String _completedIdsKeyFor(String username) {
    return 'completed_item_ids_${username.trim().toLowerCase()}';
  }

  // Set<String>, not List<String>: completion is a membership question
  // ("is this id done?"), never order or duplicates, and callers check
  // membership per item every filter/render pass — O(1) vs O(n).
  Future<Set<String>> loadCompletedIds(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedIdsKeyFor(username)) ?? const [])
        .toSet();
  }

  Future<void> saveCompletedIds(String username, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_completedIdsKeyFor(username), ids.toList());
  }

  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }
}
