import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/session_result.dart';
import '../../../core/models/user_profile_snapshot.dart';

/// Small, local demo store. The team's persistence owner can replace this class.
class LocalProductRepository {
  LocalProductRepository(this._prefs);

  final SharedPreferencesAsync _prefs;
  static const _profileKey = 'd_profile_v1';
  static const _historyKey = 'd_history_v1';

  Future<UserProfileSnapshot?> loadProfile() async {
    final raw = await _prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return UserProfileSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(UserProfileSnapshot profile) =>
      _prefs.setString(_profileKey, jsonEncode(profile.toJson()));

  Future<List<SessionResult>> loadHistory() async {
    final raw = await _prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      final items = jsonDecode(raw) as List<dynamic>;
      return items
          .map((e) => SessionResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSession(SessionResult result) async {
    final history = await loadHistory();
    if (history.any((item) => item.sessionId == result.sessionId)) return;
    history.insert(0, result);
    final capped = history.take(30).map((e) => e.toJson()).toList();
    await _prefs.setString(_historyKey, jsonEncode(capped));
  }
}
