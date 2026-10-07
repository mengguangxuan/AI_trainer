import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/agent_connection.dart';
import '../../../core/models/coach_memory.dart';
import '../../../core/models/coach_session_summary.dart';
import '../../../core/models/nutrition_advice.dart';
import '../../../core/models/privacy_flow.dart';
import '../../../core/models/session_result.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/user_profile_snapshot.dart';
import '../data/agent_coach_repository.dart';
import '../data/coach_chat_repository.dart';
import '../data/coach_repository.dart';
import '../data/local_product_repository.dart';
import '../data/template_coach_repository.dart';

class ProductController extends ChangeNotifier {
  ProductController(
    this._local,
    this._coach, {
    CoachChatRepository? chat,
    AgentConnection? initialConnection,
  }) : _chat = chat,
       connection = initialConnection ?? const AgentConnection();

  final LocalProductRepository _local;
  final CoachRepository _coach;
  final CoachChatRepository? _chat;
  final TemplateCoachRepository _fallback = TemplateCoachRepository();
  AgentConnection connection;
  UserProfileSnapshot? profile;
  List<SessionResult> history = [];
  bool loading = true;
  bool refreshing = false;
  bool planUsingFallback = false;
  bool nutritionUsingFallback = false;
  bool get usingFallback => planUsingFallback || nutritionUsingFallback;
  String? coachError;
  Map<String, dynamic>? weeklyProgress;
  TrainingPlan? plan;
  NutritionAdvice? nutrition;
  final Map<String, CoachSessionSummary> summaries = {};
  final Map<String, String> summaryErrors = {};
  final Set<String> summarizing = {};
  PrivacyFlowResult? privacyAnalysis;
  String? privacyFlowError;
  bool privacyFlowLoading = false;
  CoachMemorySnapshot? coachMemory;
  bool chatMemoryLoading = false;
  bool chatSending = false;
  String? chatError;
  int _revision = 0;
  int _contextRevision = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _localAdvice() {
    final current = profile;
    if (current == null) return;
    plan = _fallback.plan(current, history);
    nutrition = _fallback.nutrition(current);
    planUsingFallback = nutritionUsingFallback = true;
  }

  Future<void> refreshCoach() async {
    final current = profile;
    if (current == null) return;
    final revision = ++_revision;
    final records = List<SessionResult>.of(history);
    coachError = null;
    if (!connection.allowDataUpload) {
      _localAdvice();
      weeklyProgress = null;
      refreshing = false;
      _notify();
      return;
    }
    refreshing = true;
    _notify();
    // Two independent requests match the server's two-slot model capacity.
    await Future.wait([
      (() async {
        try {
          final value = current.hasCurrentDiscomfort
              ? _fallback.plan(current, records)
              : await _coach.fetchPlan(current, records);
          if (revision != _revision) return;
          plan = value;
          planUsingFallback = current.hasCurrentDiscomfort;
        } catch (error) {
          if (revision != _revision) return;
          plan = _fallback.plan(current, records);
          planUsingFallback = true;
          coachError ??= error.toString();
        }
      })(),
      (() async {
        try {
          final value = await _coach.fetchNutrition(current);
          if (revision != _revision) return;
          nutrition = value;
          nutritionUsingFallback = false;
        } catch (error) {
          if (revision != _revision) return;
          nutrition = _fallback.nutrition(current);
          nutritionUsingFallback = true;
          coachError ??= error.toString();
        }
      })(),
    ]);
    if (revision != _revision) return;
    refreshing = false;
    _notify();
  }

  Future<void> initialize() async {
    connection = await _local.loadConnection() ?? connection;
    if (_coach is AgentCoachRepository) {
      try {
        _coach.configure(connection);
      } catch (error) {
        coachError = error.toString();
      }
    }
    try {
      _chat?.configure(connection);
    } catch (error) {
      chatError = error.toString();
    }
    profile = await _local.loadProfile();
    history = await _local.loadHistory();
    for (final session in history) {
      final summary = await _local.loadSummary(session.sessionId);
      if (summary != null) summaries[session.sessionId] = summary;
    }
    _localAdvice();
    loading = false;
    _notify();
    unawaited(refreshCoach());
  }

  Future<void> saveProfile(UserProfileSnapshot value) async {
    ++_contextRevision;
    ++_revision;
    await _local.saveProfile(value);
    profile = value;
    _localAdvice();
    _notify();
    unawaited(refreshCoach());
  }

  Future<void> saveConnection(AgentConnection value) async {
    ++_contextRevision;
    if (_coach is AgentCoachRepository) _coach.configure(value);
    _chat?.configure(value);
    ++_revision;
    await _local.saveConnection(value);
    connection = value;
    weeklyProgress = null;
    _localAdvice();
    _notify();
    unawaited(refreshCoach());
  }

  Future<void> refreshChatMemory() async {
    final current = profile;
    final chat = _chat;
    if (current == null || chat == null) return;
    if (!connection.allowDataUpload) {
      chatError = '请先在 Agent 连接中允许传输训练数据。';
      coachMemory = null;
      _notify();
      return;
    }
    chatMemoryLoading = true;
    chatError = null;
    _notify();
    try {
      final installationId = await _local.loadOrCreateInstallationId();
      await chat.syncProfile(installationId, current);
      coachMemory = await chat.fetchMemory(installationId);
    } catch (error) {
      chatError = error.toString();
    } finally {
      chatMemoryLoading = false;
      _notify();
    }
  }

  Future<bool> sendChatMessage(String message) async {
    final current = profile;
    final chat = _chat;
    if (current == null || chat == null || chatSending) return false;
    if (!connection.allowDataUpload) {
      chatError = '请先在 Agent 连接中允许传输训练数据。';
      _notify();
      return false;
    }
    chatSending = true;
    chatError = null;
    _notify();
    try {
      final installationId = await _local.loadOrCreateInstallationId();
      await chat.syncProfile(installationId, current);
      await chat.sendMessage(
        installationId: installationId,
        message: message,
        profile: current,
        history: List.of(history),
        currentPlan: plan,
      );
      coachMemory = await chat.fetchMemory(installationId);
      return true;
    } catch (error) {
      chatError = error.toString();
      return false;
    } finally {
      chatSending = false;
      _notify();
    }
  }

  Future<void> deleteChatMemory() async {
    final chat = _chat;
    if (chat == null || chatMemoryLoading || chatSending) return;
    if (!connection.allowDataUpload) {
      chatError = '尚未允许访问 Agent 记忆。';
      _notify();
      return;
    }
    chatMemoryLoading = true;
    chatError = null;
    _notify();
    try {
      final installationId = await _local.loadOrCreateInstallationId();
      await chat.deleteMemory(installationId);
      coachMemory = CoachMemorySnapshot(
        userId: installationId,
        profile: const {},
        profileUpdatedAt: null,
        recentReports: const [],
        recentRecords: const [],
        chatMessages: const [],
        recordCounts: const {},
        storage: 'local_sqlite',
      );
    } catch (error) {
      chatError = error.toString();
    } finally {
      chatMemoryLoading = false;
      _notify();
    }
  }

  Future<Map<String, dynamic>> checkConnection(AgentConnection value) async {
    final client = AgentCoachRepository(
      baseUrl: Uri.parse(value.baseUrl),
      devToken: value.devToken,
    );
    try {
      client.configure(value);
      return await client.capabilities();
    } finally {
      client.close();
    }
  }

  Future<void> recordSession(SessionResult result) async {
    await _local.saveSession(result);
    history = await _local.loadHistory();
    _notify();
    // The training result screen never waits for a model call.
    unawaited(_afterSession(result));
  }

  Future<void> _afterSession(SessionResult result) async {
    try {
      if (result.source == 'real' && connection.allowDataUpload) {
        await retrySummary(result);
      }
      await refreshCoach();
    } catch (error) {
      coachError = error.toString();
      _notify();
    }
  }

  Future<void> retrySummary(SessionResult result) async {
    final current = profile;
    final id = result.sessionId;
    if (current == null ||
        result.source != 'real' ||
        summarizing.contains(id) ||
        summaries.containsKey(id)) {
      return;
    }
    if (!connection.allowDataUpload) {
      summaryErrors[id] = '尚未允许传输训练数据。';
      _notify();
      return;
    }
    final revision = _contextRevision;
    summarizing.add(id);
    summaryErrors.remove(id);
    _notify();
    try {
      final installationId = await _local.loadOrCreateInstallationId();
      if (_disposed ||
          revision != _contextRevision ||
          !connection.allowDataUpload) {
        return;
      }
      final summary = await _coach.fetchSummary(
        installationId: installationId,
        profile: current,
        session: result,
        history: List.of(history),
      );
      if (revision != _contextRevision || !connection.allowDataUpload) return;
      if (summary != null) {
        if (summary.sessionId != id) throw const FormatException('总结会话不匹配');
        await _local.saveSummary(summary);
        summaries[id] = summary;
      }
    } catch (error) {
      if (revision == _contextRevision) summaryErrors[id] = error.toString();
    } finally {
      summarizing.remove(id);
      _notify();
    }
  }

  Future<void> refreshWeeklyProgress() async {
    final current = profile;
    if (current == null || !connection.allowDataUpload) return;
    final revision = _revision;
    try {
      final value = await _coach.fetchWeeklyProgress(
        profile: current,
        history: List.of(history),
      );
      if (revision == _revision) weeklyProgress = value;
    } catch (error) {
      if (revision == _revision) coachError = error.toString();
    }
    _notify();
  }

  /// Runs the privacy-preserving edge-token flow without sending camera data.
  Future<PrivacyFlowResult?> analyzePrivacyFlow(
    PrivacyFlowRequest request,
  ) async {
    if (!connection.allowDataUpload) {
      privacyFlowError = '尚未允许传输端侧训练 token。';
      _notify();
      return null;
    }
    privacyFlowLoading = true;
    privacyFlowError = null;
    _notify();
    try {
      final result = await _coach.submitPrivacyFlow(request);
      privacyAnalysis = result;
      return result;
    } catch (error) {
      privacyFlowError = error.toString();
      return null;
    } finally {
      privacyFlowLoading = false;
      _notify();
    }
  }

  Future<void> deleteSummaries() async {
    ++_contextRevision;
    ++_revision;
    if (_coach is AgentCoachRepository) {
      await _coach.deleteCachedSummaries(
        await _local.loadOrCreateInstallationId(),
      );
    }
    await _local.clearSummaries();
    summaries.clear();
    summaryErrors.clear();
    _notify();
  }

  Future<CoachSessionSummary?> summaryFor(String sessionId) =>
      _local.loadSummary(sessionId);
  int get completedCount => history.where((e) => e.isCompleted).length;

  int get streak {
    final days = history.where((e) => e.isCompleted).map((e) {
      final day = e.finishedAt.toLocal();
      return DateTime(day.year, day.month, day.day);
    }).toSet();
    if (days.isEmpty) return 0;
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_contextRevision;
    ++_revision;
    if (_coach is AgentCoachRepository) _coach.close();
    _chat?.close();
    super.dispose();
  }
}
