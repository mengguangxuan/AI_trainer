import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/models/agent_connection.dart';
import '../../../core/models/coach_memory.dart';
import '../../../core/models/session_result.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/user_profile_snapshot.dart';
import 'agent_coach_repository.dart';
import 'coach_chat_repository.dart';

class AgentChatRepository implements CoachChatRepository {
  AgentChatRepository({
    required Uri appBaseUrl,
    HttpClient? httpClient,
    String? devToken,
    this.connectTimeout = const Duration(seconds: 5),
    this.responseTimeout = const Duration(seconds: 90),
  }) : _http = httpClient ?? HttpClient() {
    _appBaseUrl = appBaseUrl;
    _devToken = devToken ?? '';
  }

  late Uri _appBaseUrl;
  String _devToken = '';
  final HttpClient _http;
  final Duration connectTimeout;
  final Duration responseTimeout;

  @override
  void configure(AgentConnection connection) {
    _appBaseUrl = AgentCoachRepository.validateConnection(connection);
    _devToken = connection.devToken;
  }

  Uri _apiBase() {
    final validated = AgentCoachRepository.validateConnection(
      AgentConnection(baseUrl: _appBaseUrl.toString(), devToken: _devToken),
    );
    return validated.replace(path: '/api/', query: null, fragment: null);
  }

  static Map<String, Object?> projectMemoryProfile(
    UserProfileSnapshot profile,
  ) => {
    'goal': switch (profile.goal) {
      '提升力量' => 'strength',
      '改善体能' => 'endurance',
      _ => 'general_fitness',
    },
    'experience': profile.experience == '有规律运动' ? 'intermediate' : 'beginner',
    'days_per_week': profile.daysPerWeek,
    'minutes_per_session': profile.minutesPerSession,
    'equipment': const ['bodyweight'],
    'limitations': const <String>[],
    'dietary_preferences': switch (profile.dietPreference) {
      '素食' => const ['vegetarian'],
      '有过敏或特殊限制' => const ['special_restrictions_not_uploaded'],
      _ => const <String>[],
    },
    'allergies': const <String>[],
    'medical_conditions': const <String>[],
    'preferred_language': 'zh-CN',
  };

  static List<Map<String, Object?>> projectRecentSessions(
    List<SessionResult> history,
  ) => history
      .where((session) => session.source == 'real')
      .take(10)
      .map(
        (session) => <String, Object?>{
          'session_id': session.sessionId,
          'status': session.status,
          'finished_at':
              session.finishedAtIso ?? session.finishedAt.toIso8601String(),
          'duration_seconds': session.durationSeconds,
          'exercises': session.exercises
              .map(
                (exercise) => <String, Object?>{
                  'exercise_id': exercise.exerciseId,
                  'completed_sets': exercise.completedSets,
                  'completed_reps': exercise.completedReps,
                },
              )
              .toList(growable: false),
        },
      )
      .toList(growable: false);

  static Map<String, Object?>? projectPlan(TrainingPlan? plan) {
    if (plan == null) return null;
    final item = plan.item;
    return {
      'stage_name': plan.stageName,
      'headline': plan.headline,
      if (item != null)
        'item': {
          'exercise_id': item.exerciseId,
          'target_sets': item.targetSets,
          'target_reps': item.targetReps,
        },
    };
  }

  @override
  Future<void> syncProfile(
    String installationId,
    UserProfileSnapshot profile,
  ) async {
    await _request('POST', 'memory/profile', {
      'user_id': installationId,
      'profile': projectMemoryProfile(profile),
    });
  }

  @override
  Future<CoachMemorySnapshot> fetchMemory(String installationId) async {
    final data = await _request(
      'GET',
      'memory?user_id=${Uri.encodeQueryComponent(installationId)}',
    );
    try {
      return CoachMemorySnapshot.fromJson(data);
    } on FormatException {
      throw _invalidResponse;
    }
  }

  @override
  Future<CoachChatReply> sendMessage({
    required String installationId,
    required String message,
    required UserProfileSnapshot profile,
    required List<SessionResult> history,
    TrainingPlan? currentPlan,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) {
      throw const AgentCoachException('INVALID_MESSAGE', '请输入 1 到 2000 个字符。');
    }
    final data = await _request('POST', 'chat', {
      'user_id': installationId,
      'message': trimmed,
      'context': {
        'app_profile': AgentCoachRepository.projectProfile(profile),
        'current_plan': projectPlan(currentPlan),
        'recent_sessions': projectRecentSessions(history),
      },
    });
    try {
      return CoachChatReply.fromJson(data);
    } on FormatException {
      throw _invalidResponse;
    }
  }

  @override
  Future<void> deleteMemory(String installationId) async {
    final data = await _request('POST', 'memory/delete', {
      'user_id': installationId,
    });
    if (data['deleted'] != true) throw _invalidResponse;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, Object?>? payload,
  ]) async {
    HttpClientRequest? request;
    try {
      _http.connectionTimeout = connectTimeout;
      request = await _http
          .openUrl(method, _apiBase().resolve(path))
          .timeout(connectTimeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_devToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_devToken',
        );
      }
      if (payload != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(payload));
      }
      final response = await request.close().timeout(responseTimeout);
      final bytes = await response
          .fold<List<int>>([], (data, chunk) {
            if (data.length + chunk.length > 1000000) throw _invalidResponse;
            return data..addAll(chunk);
          })
          .timeout(responseTimeout);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw _invalidResponse;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded['detail'];
        final structured = detail is Map<String, dynamic>
            ? detail
            : const <String, dynamic>{};
        throw AgentCoachException(
          structured['code'] as String? ?? 'HTTP_${response.statusCode}',
          structured['message'] as String? ??
              (detail is String ? detail : '聊天服务暂不可用。'),
          retryable: structured['retryable'] == true,
        );
      }
      return decoded;
    } on AgentCoachException {
      rethrow;
    } on TimeoutException {
      request?.abort();
      throw const AgentCoachException(
        'NETWORK_TIMEOUT',
        '聊天请求超时，可稍后重试。',
        retryable: true,
      );
    } on SocketException {
      throw const AgentCoachException(
        'NETWORK_UNAVAILABLE',
        '无法连接 Agent，请检查服务地址。',
        retryable: true,
      );
    } on FormatException {
      throw _invalidResponse;
    } on TypeError {
      throw _invalidResponse;
    } on HttpException {
      throw const AgentCoachException(
        'NETWORK_UNAVAILABLE',
        'HTTP 连接失败。',
        retryable: true,
      );
    }
  }

  static const _invalidResponse = AgentCoachException(
    'INVALID_RESPONSE',
    '聊天服务返回不兼容的数据。',
  );

  @override
  void close() => _http.close(force: true);
}
