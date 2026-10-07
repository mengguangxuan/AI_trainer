import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/session_result.dart';
import '../../../core/models/agent_connection.dart';
import '../../../core/models/coach_session_summary.dart';
import '../../../core/models/user_profile_snapshot.dart';

/// Small, local demo store. The team's persistence owner can replace this class.
class LocalProductRepository {
  LocalProductRepository(this._prefs);

  final SharedPreferencesAsync _prefs;
  Future<void> _writes = Future.value();
  Future<String>? _installationId;

  Future<void> _serialize(Future<void> Function() write) {
    final result = _writes.then((_) => write());
    _writes = result.catchError((Object _) {});
    return result;
  }

  static const _profileKey = 'd_profile_v1';
  static const _historyKey = 'd_history_v1';
  static const _summaryKey = 'd_agent_summaries_v1';
  static const _installationKey = 'd_installation_id_v1';
  static const _connectionKey = 'd_agent_connection_v1';

  Future<AgentConnection?> loadConnection() async {
    final raw = await _prefs.getString(_connectionKey);
    if (raw == null) return null;
    try {
      return AgentConnection.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConnection(AgentConnection value) =>
      _prefs.setString(_connectionKey, jsonEncode(value.toJson()));

  Future<void> clearSummaries() => _serialize(() => _prefs.remove(_summaryKey));

  Future<UserProfileSnapshot?> loadProfile() async {
    final raw = await _prefs.getString(_profileKey);
    if (raw == null) return null;
    try {
      return UserProfileSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
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

  Future<void> saveSession(SessionResult result) => _serialize(() async {
    final history = await loadHistory();
    if (history.any((item) => item.sessionId == result.sessionId)) return;
    history.insert(0, result);
    final capped = history.take(30).map((e) => e.toJson()).toList();
    await _prefs.setString(_historyKey, jsonEncode(capped));
  });

  Future<String> loadOrCreateInstallationId() =>
      _installationId ??= _loadOrCreateInstallationId();

  Future<String> _loadOrCreateInstallationId() async {
    final existing = await _prefs.getString(_installationKey);
    if (existing != null && existing.length >= 16) return existing;
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _prefs.setString(_installationKey, id);
    return id;
  }

  Future<void> saveSummary(CoachSessionSummary summary) => _serialize(() async {
    final raw = await _prefs.getString(_summaryKey);
    final summaries = <String, dynamic>{};
    if (raw != null) {
      try {
        summaries.addAll(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        summaries.clear();
      }
    }
    summaries[summary.sessionId] = summary.toJson();
    final kept = summaries.entries.toList().reversed.take(30).toList().reversed;
    await _prefs.setString(_summaryKey, jsonEncode(Map.fromEntries(kept)));
  });

  Future<CoachSessionSummary?> loadSummary(String sessionId) async {
    final raw = await _prefs.getString(_summaryKey);
    if (raw == null) return null;
    try {
      final summaries = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final value = summaries[sessionId];
      return value is Map<String, dynamic>
          ? CoachSessionSummary.fromJson(value)
          : null;
    } catch (_) {
      return null;
    }
  }
}
