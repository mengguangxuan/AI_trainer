import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/models/agent_connection.dart';
import '../../../core/models/coach_session_summary.dart';
import '../../../core/models/nutrition_advice.dart';
import '../../../core/models/privacy_flow.dart';
import '../../../core/models/session_result.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/user_profile_snapshot.dart';
import 'coach_repository.dart';

class AgentCoachException implements Exception {
  const AgentCoachException(this.code, this.message, {this.retryable = false});
  final String code;
  final String message;
  final bool retryable;
  @override
  String toString() => '$message ($code)';
}

class AgentCoachRepository extends CoachRepository {
  AgentCoachRepository({
    required Uri baseUrl,
    HttpClient? httpClient,
    String? devToken,
    this.connectTimeout = const Duration(seconds: 5),
    this.responseTimeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? HttpClient() {
    _baseUrl = baseUrl.toString().endsWith('/')
        ? baseUrl
        : Uri.parse('$baseUrl/');
    _devToken = devToken ?? '';
  }

  late Uri _baseUrl;
  String _devToken = '';
  final HttpClient _http;
  final Duration connectTimeout;
  final Duration responseTimeout;

  static Uri validateConnection(AgentConnection value) {
    final uri = Uri.tryParse(value.baseUrl.trim());
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['http', 'https'].contains(uri.scheme)) {
      throw const AgentCoachException('INVALID_ENDPOINT', '请输入有效的服务地址。');
    }
    final local = ['127.0.0.1', 'localhost', '::1'].contains(uri.host);
    final bytes = InternetAddress.tryParse(uri.host)?.rawAddress;
    final private =
        bytes != null &&
        bytes.length == 4 &&
        (bytes[0] == 10 ||
            (bytes[0] == 192 && bytes[1] == 168) ||
            (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31));
    if (uri.scheme != 'https' && !(kDebugMode && (local || private))) {
      throw const AgentCoachException(
        'INSECURE_ENDPOINT',
        '正式服务必须使用 HTTPS；本地 HTTP 仅限调试版。',
      );
    }
    if (value.devToken.isNotEmpty && !kDebugMode) {
      throw const AgentCoachException('DEV_TOKEN_IN_RELEASE', '开发凭据只能用于调试版。');
    }
    if (!local && value.devToken.isEmpty && kDebugMode) {
      throw const AgentCoachException('TOKEN_REQUIRED', '远程联调需要开发访问凭据。');
    }
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/api/app/v1';
    if (path != '/api/app/v1') {
      throw const AgentCoachException(
        'INVALID_ENDPOINT',
        '服务路径必须为 /api/app/v1。',
      );
    }
    return uri.replace(path: '$path/');
  }

  void configure(AgentConnection value) {
    _baseUrl = validateConnection(value);
    _devToken = value.devToken;
  }

  static Map<String, Object?> projectProfile(UserProfileSnapshot profile) => {
    'schema_version': 1,
    'goal': profile.goal,
    'experience': profile.experience,
    'days_per_week': profile.daysPerWeek,
    'minutes_per_session': profile.minutesPerSession,
    'has_equipment': profile.hasEquipment,
    'diet_preference': profile.dietPreference,
  };

  // Retain the device calendar date and an explicit offset for strict v1 validation.
  static String zonedTime(DateTime stamp) {
    if (stamp.isUtc) return stamp.toIso8601String();
    final offset = stamp.timeZoneOffset.inMinutes;
    final hours = (offset.abs() ~/ 60).toString().padLeft(2, '0');
    final minutes = (offset.abs() % 60).toString().padLeft(2, '0');
    return '${stamp.toIso8601String()}${offset < 0 ? '-' : '+'}$hours:$minutes';
  }

  static Map<String, Object?> projectSession(SessionResult session) {
    if (session.source != 'real' ||
        session.agentSummary != null ||
        session.nextPlanChanged ||
        session.exercises.any(
          (e) => e.qualityTrend != null || e.mainErrorCode != null,
        )) {
      throw const AgentCoachException(
        'INVALID_SESSION',
        '只可提交未经改写的真实 Android v1 记录。',
      );
    }
    final original = session.finishedAtIso;
    final zonedOriginal =
        original != null && RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(original);
    return {
      ...session.toJson(),
      'finished_at': zonedOriginal
          ? original
          : zonedTime(session.finishedAt.toLocal()),
    };
  }

  static List<Map<String, Object?>> projectHistory(
    List<SessionResult> history, {
    String? excluding,
  }) {
    final seen = <String>{};
    final result = <Map<String, Object?>>[];
    for (final session in history) {
      if (session.source != 'real' ||
          session.sessionId == excluding ||
          !seen.add(session.sessionId)) {
        continue;
      }
      result.add(projectSession(session));
      if (result.length == 30) break;
    }
    return result;
  }

  Future<Map<String, dynamic>> capabilities() async {
    final data = await _request('GET', 'capabilities');
    if (data['contract'] != 'app_coach_v1' ||
        data['schema_version'] != 1 ||
        data['health_profile_upload'] != false ||
        data['max_sets'] != 1) {
      throw const AgentCoachException(
        'INCOMPATIBLE_CONTRACT',
        '该服务不是兼容的 App Coach v1。',
      );
    }
    return data;
  }

  @override
  Future<TrainingPlan> fetchPlan(
    UserProfileSnapshot profile,
    List<SessionResult> history,
  ) async {
    if (profile.hasCurrentDiscomfort) {
      throw const AgentCoachException(
        'LOCAL_TRAINING_PAUSED',
        '当前身体不适，已暂停自动安排。',
      );
    }
    final data = await _request('POST', 'plan', {
      'profile': projectProfile(profile),
      'history': projectHistory(history),
      'executable_exercises': ['squat'],
      'local_date': _localDate(),
    });
    try {
      final item = data['item'];
      if (item != null &&
          (item is! Map<String, dynamic> ||
              item['exercise_id'] != 'squat' ||
              item['target_sets'] != 1 ||
              item['target_reps'] is! int ||
              (item['target_reps'] as int) < 1 ||
              (item['target_reps'] as int) >
                  (profile.experience == '新手' ? 6 : 8) ||
              item['rest_seconds'] != 45)) {
        throw const FormatException('Non-executable plan');
      }
      return TrainingPlan(
        planId: data['plan_id'] as String,
        stageName: data['stage_name'] as String,
        headline: data['headline'] as String,
        reason: data['reason'] as String,
        source: _source(data),
        item: item == null
            ? null
            : TrainingPlanItem(
                id: item['id'] as String,
                exerciseId: item['exercise_id'] as String,
                title: item['title'] as String,
                targetSets: item['target_sets'] as int,
                targetReps: item['target_reps'] as int,
                restSeconds: item['rest_seconds'] as int,
              ),
      );
    } on TypeError {
      throw _invalidResponse;
    } on FormatException {
      throw _invalidResponse;
    }
  }

  @override
  Future<NutritionAdvice> fetchNutrition(UserProfileSnapshot profile) async {
    final data = await _request('POST', 'nutrition', {
      'profile': projectProfile(profile),
    });
    try {
      return NutritionAdvice(
        title: data['title'] as String,
        body: data['body'] as String,
        source: _source(data),
      );
    } on TypeError {
      throw _invalidResponse;
    }
  }

  @override
  Future<Map<String, dynamic>> fetchWeeklyProgress({
    required UserProfileSnapshot profile,
    required List<SessionResult> history,
  }) async {
    final data = await _request('POST', 'progress/weekly', {
      'profile': projectProfile(profile),
      'history': projectHistory(history),
      'local_date': _localDate(),
    });
    if (data['summary'] is! String ||
        data['next_step'] is! String ||
        data['quality_available'] != false) {
      throw _invalidResponse;
    }
    _source(data);
    return data;
  }

  @override
  Future<CoachSessionSummary?> fetchSummary({
    required String installationId,
    required UserProfileSnapshot profile,
    required SessionResult session,
    List<SessionResult> history = const [],
  }) async {
    final data = await _request('POST', 'sessions/summary', {
      'installation_id': installationId,
      'profile': projectProfile(profile),
      'session': projectSession(session),
      'history': projectHistory(history, excluding: session.sessionId),
    });
    if (data['session_id'] != session.sessionId ||
        data['source'] != 'agent' ||
        data['next_plan_changed'] != false ||
        data['updated_plan'] != null ||
        data['quality_trend'] != null ||
        data['main_error_code'] != null) {
      throw _invalidResponse;
    }
    try {
      return CoachSessionSummary.fromJson(data);
    } on TypeError {
      throw _invalidResponse;
    }
  }

  Future<Map<String, dynamic>> deleteCachedSummaries(String installationId) =>
      _request('POST', 'data/delete', {'installation_id': installationId});

  /// Sends edge-extracted semantic tokens only. The request model has no
  /// fields for media bytes, raw landmarks, or a raw URDF document.
  @override
  Future<PrivacyFlowResult> submitPrivacyFlow(PrivacyFlowRequest payload) async {
    final data = await _request('POST', 'privacy/flow', payload.toJson());
    try {
      final result = PrivacyFlowResult.fromJson(data);
      if (result.flowId != payload.flowId ||
          result.sessionId != payload.sessionId) {
        throw const FormatException('privacy flow identity mismatch');
      }
      return result;
    } on TypeError {
      throw _invalidResponse;
    } on FormatException {
      throw _invalidResponse;
    }
  }

  static const _invalidResponse = AgentCoachException(
    'INVALID_RESPONSE',
    '服务返回不兼容的数据。',
  );
  String _source(Map<String, dynamic> data) {
    if (!['agent', 'template'].contains(data['source'])) throw _invalidResponse;
    return data['source'] as String;
  }

  String _localDate() => DateTime.now().toIso8601String().substring(0, 10);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, Object?>? payload,
  ]) async {
    HttpClientRequest? request;
    try {
      final baseUrl = validateConnection(
        AgentConnection(baseUrl: _baseUrl.toString(), devToken: _devToken),
      );
      final devToken = _devToken;
      _http.connectionTimeout = connectTimeout;
      request = await _http
          .openUrl(method, baseUrl.resolve(path))
          .timeout(connectTimeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (devToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $devToken',
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
        final error = detail is Map<String, dynamic>
            ? detail
            : const <String, dynamic>{};
        throw AgentCoachException(
          error['code'] as String? ?? 'HTTP_${response.statusCode}',
          error['message'] as String? ?? '服务暂不可用。',
          retryable: error['retryable'] == true,
        );
      }
      return decoded;
    } on AgentCoachException {
      rethrow;
    } on TimeoutException {
      request?.abort();
      throw const AgentCoachException(
        'NETWORK_TIMEOUT',
        '请求超时，可稍后重试。',
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

  void close() => _http.close(force: true);
}
