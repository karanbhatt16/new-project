import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for search/discover filter preferences.
///
/// Stores the user's selected interest filters so they persist across sessions.
/// Uses SharedPreferences for simple, permission-free storage.
class LocalFilterPreferences {
  LocalFilterPreferences();

  String _interestsKey(String uid) => 'filter_interests_$uid';
  String _filterVisibleKey(String uid) => 'filter_visible_$uid';

  /// Load saved interest filters for a user.
  Future<Set<String>> loadSelectedInterests(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_interestsKey(uid));
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  /// Save selected interest filters for a user.
  Future<void> saveSelectedInterests(String uid, Set<String> interests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _interestsKey(uid),
      jsonEncode(interests.toList()..sort()),
    );
  }

  /// Load whether the filter panel should be visible.
  Future<bool> loadFilterVisible(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_filterVisibleKey(uid)) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Save whether the filter panel should be visible.
  Future<void> saveFilterVisible(String uid, bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_filterVisibleKey(uid), visible);
  }

  /// Clear all filter preferences for a user.
  Future<void> clearFilters(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_interestsKey(uid));
    await prefs.remove(_filterVisibleKey(uid));
  }
}
