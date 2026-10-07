import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_d_starter/core/models/agent_connection.dart';
import 'package:ai_fitness_d_starter/core/models/privacy_flow.dart';
import 'package:ai_fitness_d_starter/core/models/session_result.dart';
import 'package:ai_fitness_d_starter/core/models/user_profile_snapshot.dart';
import 'package:ai_fitness_d_starter/features/product/data/agent_coach_repository.dart';

const profile = UserProfileSnapshot(
  goal: '建立运动习惯',
  experience: '新手',
  daysPerWeek: 2,
  minutesPerSession: 15,
  hasEquipment: false,
  hasCurrentDiscomfort: false,
  dietPreference: '有过敏或特殊限制',
);

SessionResult session(String id, {String source = 'real'}) => SessionResult(
  sessionId: id,
  status: 'completed',
  finishedAt: DateTime(2026, 10, 7, 22),
  durationSeconds: 30,
  source: source,
  exercises: const [
    SessionExercise(exerciseId: 'squat', completedSets: 1, completedReps: 6),
  ],
);

void main() {
  test('profile never uploads the local health field', () {
    expect(
      AgentCoachRepository.projectProfile(
        profile,
      ).containsKey('has_current_discomfort'),
      isFalse,
    );
  });
  test('local and UTC timestamps include a zone and retain the instant', () {
    for (final stamp in [
      DateTime(2026, 10, 7, 22),
      DateTime.utc(2026, 10, 7, 22),
    ]) {
      final encoded = AgentCoachRepository.zonedTime(stamp);
      expect(encoded, matches(RegExp(r'(Z|[+-]\d{2}:\d{2})$')));
      expect(DateTime.parse(encoded).isAtSameMomentAs(stamp), isTrue);
    }
    final projected = AgentCoachRepository.projectSession(session('one'));
    expect(projected['finished_at'], matches(RegExp(r'[+-]\d{2}:\d{2}$')));
  });
  test('mock sessions are rejected, history is capped and deduplicated', () {
    expect(
      () =>
          AgentCoachRepository.projectSession(session('mock', source: 'mock')),
      throwsA(isA<AgentCoachException>()),
    );
    final records = [
      session('one'),
      session('one'),
      session('current'),
      session('mock', source: 'mock'),
      ...List.generate(40, (i) => session('id_$i')),
    ];
    final projected = AgentCoachRepository.projectHistory(
      records,
      excluding: 'current',
    );
    expect(projected, hasLength(30));
    expect(projected.map((s) => s['session_id']).toSet(), hasLength(30));
    expect(projected.any((s) => s['session_id'] == 'current'), isFalse);
  });
  test(
    'persisted native timestamp preserves offset and idempotency spelling',
    () {
      final input = {
        ...session('native').toJson(),
        'finished_at': '2026-10-07T22:00:00+08:00',
      };
      final record = SessionResult.fromJson(input);
      expect(record.toJson()['finished_at'], input['finished_at']);
      final reloaded = SessionResult.fromJson(
        record.toJson().cast<String, dynamic>(),
      );
      expect(
        AgentCoachRepository.projectSession(reloaded)['finished_at'],
        input['finished_at'],
      );
    },
  );
  test('endpoint normalization and development boundaries', () {
    expect(
      AgentCoachRepository.validateConnection(const AgentConnection()).path,
      '/api/app/v1/',
    );
    expect(
      AgentCoachRepository.validateConnection(
        const AgentConnection(baseUrl: 'http://localhost:8000'),
      ).path,
      '/api/app/v1/',
    );
    expect(
      () => AgentCoachRepository.validateConnection(
        const AgentConnection(baseUrl: 'http://example.com'),
      ),
      throwsA(isA<AgentCoachException>()),
    );
    expect(
      () => AgentCoachRepository.validateConnection(
        const AgentConnection(baseUrl: 'http://192.168.1.5:8000'),
      ),
      throwsA(isA<AgentCoachException>()),
    );
  });

  group('real HTTP serialization', () {
    late HttpServer server;
    late AgentCoachRepository client;
    late List<Map<String, dynamic>> received;
    late Map<String, dynamic> response;
    late int status;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      client = AgentCoachRepository(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}/api/app/v1/'),
        devToken: 'test-token',
      );
      received = [];
      status = 200;
      response = {};
      server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-token',
        );
        final text = await utf8.decoder.bind(request).join();
        received.add({
          'path': request.uri.path,
          if (text.isNotEmpty) 'body': jsonDecode(text),
        });
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
    });
    tearDown(() async {
      client.close();
      await server.close(force: true);
    });

    test('no-item rest plan is a successful server template', () async {
      response = {
        'plan_id': 'rest',
        'stage_name': '本周安排',
        'headline': '今天安排休息',
        'reason': '已完成',
        'item': null,
        'source': 'template',
      };
      final result = await client.fetchPlan(profile, [session('one')]);
      expect(result.item, isNull);
      expect(result.source, 'template');
      expect(received.single['path'], '/api/app/v1/plan');
      final body = received.single['body'] as Map;
      expect(
        (body['profile'] as Map).containsKey('has_current_discomfort'),
        isFalse,
      );
      expect(body['executable_exercises'], ['squat']);
    });
    test(
      'summary has matching identity and never overwrites native records',
      () async {
        response = {
          'session_id': 'one',
          'agent_summary': '已记录训练，不能评价质量。',
          'source': 'agent',
          'quality_trend': null,
          'main_error_code': null,
          'next_plan_changed': false,
          'updated_plan': null,
          'facts': {},
          'limitations': [],
        };
        final original = session('one');
        final result = await client.fetchSummary(
          installationId: 'install_contract_test',
          profile: profile,
          session: original,
          history: [original, session('two'), session('two')],
        );
        expect(result!.sessionId, 'one');
        expect(original.agentSummary, isNull);
        expect((received.single['body'] as Map)['history'], hasLength(1));
        response['session_id'] = 'wrong';
        await expectLater(
          client.fetchSummary(
            installationId: 'install_contract_test',
            profile: profile,
            session: original,
          ),
          throwsA(isA<AgentCoachException>()),
        );
      },
    );
    test('privacy flow sends tokens and never sends media or raw URDF', () async {
      response = {
        'contract': 'app_privacy_flow_v1',
        'schema_version': 1,
        'flow_id': 'flow-one',
        'session_id': 'one',
        'status': 'completed',
        'privacy': {
          'token_only': true,
          'raw_video_received': false,
          'raw_pixels_received': false,
        },
        'routing': {},
        'analysis': {'action': 'squat'},
        'overlay': {'available': true},
        'coach': {'source': 'rules'},
      };
      const payload = PrivacyFlowRequest(
        flowId: 'flow-one',
        sessionId: 'one',
        exerciseId: 'squat',
        startedAt: '2026-10-07T18:00:00+08:00',
        finishedAt: '2026-10-07T18:01:00+08:00',
        provider: 'edge_catalog_v1',
        algorithm: 'provider_opaque',
        videoModelVersion: 'edge-test',
        videoTokens: [
          PrivacyToken(
            kind: 'action',
            value: 'pt1_c1c9a36a4b98bc4beabbd846eec8a5151117befe',
            confidence: 0.96,
          ),
        ],
        skeletonProvider: 'mediapipe_urdf_adapter',
        skeletonModelVersion: 'pose-test',
        urdfToken: 'pt1_c1c9a36a4b98bc4beabbd846eec8a5151117befe',
        trajectoryToken: 'pt1_3d1eaeac08bf62672cb5c00938ac9a585728e1e4',
        jointCount: 17,
        frameCount: 60,
        durationMs: 1000,
        stateTokens: [],
      );
      final result = await client.submitPrivacyFlow(payload);
      expect(result.flowId, 'flow-one');
      expect(result.status, 'completed');
      final body = received.single['body'] as Map;
      expect(body['contract'], 'app_privacy_flow_v1');
      expect(body.containsKey('video_base64'), isFalse);
      expect((body['skeleton'] as Map).containsKey('urdf'), isFalse);
      expect((body['privacy'] as Map)['raw_media_uploaded'], isFalse);
    });
    test('structured 503 preserves error code and retryability', () async {
      status = 503;
      response = {
        'detail': {
          'code': 'MODEL_NOT_CONFIGURED',
          'message': '模型未配置',
          'retryable': false,
        },
      };
      await expectLater(
        client.fetchNutrition(profile),
        throwsA(
          isA<AgentCoachException>()
              .having((e) => e.code, 'code', 'MODEL_NOT_CONFIGURED')
              .having((e) => e.retryable, 'retryable', false),
        ),
      );
    });
    test('capability check rejects the wrong contract', () async {
      response = {'contract': 'action_report_v2', 'schema_version': 2};
      await expectLater(
        client.capabilities(),
        throwsA(
          isA<AgentCoachException>().having(
            (e) => e.code,
            'code',
            'INCOMPATIBLE_CONTRACT',
          ),
        ),
      );
    });
    test('invalid plan cannot start an unadvertised exercise', () async {
      response = {
        'plan_id': 'p',
        'stage_name': 'x',
        'headline': 'x',
        'reason': 'x',
        'source': 'agent',
        'item': {
          'id': 'i',
          'exercise_id': 'push_up',
          'title': '俯卧撑',
          'target_sets': 1,
          'target_reps': 6,
          'rest_seconds': 45,
        },
      };
      await expectLater(
        client.fetchPlan(profile, []),
        throwsA(isA<AgentCoachException>()),
      );
    });
  });

  final live = Platform.environment['APP_AGENT_LIVE_URL'];
  test(
    'live Agent accepts the Dart payload without schema disagreement',
    () async {
      final client = AgentCoachRepository(baseUrl: Uri.parse(live!));
      try {
        expect((await client.capabilities())['contract'], 'app_coach_v1');
        expect((await client.fetchNutrition(profile)).source, 'template');
        final record = SessionResult(
          sessionId: 'dart_live_contract',
          status: 'completed',
          finishedAt: DateTime.now(),
          durationSeconds: 30,
          source: 'real',
          exercises: const [
            SessionExercise(
              exerciseId: 'squat',
              completedSets: 1,
              completedReps: 6,
            ),
          ],
        );
        final plan = await client.fetchPlan(profile, [record]);
        expect(plan.item, isNull);
        expect(plan.source, 'template');
        final progress = await client.fetchWeeklyProgress(
          profile: profile,
          history: [record],
        );
        expect(progress['completed_training_days'], 1);
        expect(progress['total_reps'], 6);
        await expectLater(
          client.fetchSummary(
            installationId: 'install_dart_live_contract',
            profile: profile,
            session: record,
          ),
          throwsA(
            isA<AgentCoachException>().having(
              (e) => e.code,
              'code',
              'MODEL_NOT_CONFIGURED',
            ),
          ),
        );
        final privacy = const PrivacyFlowRequest(
          flowId: 'dart-live-privacy-flow',
          sessionId: 'dart_live_contract',
          exerciseId: 'squat',
          startedAt: '2026-10-07T18:00:00+08:00',
          finishedAt: '2026-10-07T18:01:00+08:00',
          provider: 'edge_catalog_v1',
          algorithm: 'provider_opaque',
          videoModelVersion: 'edge-vlm-demo-1',
          videoTokens: [
            PrivacyToken(
              kind: 'action',
              value: EdgePrivacyTokenCatalog.actionSquat,
              confidence: 0.96,
            ),
          ],
          skeletonProvider: 'mediapipe_urdf_adapter',
          skeletonModelVersion: 'pose-landmarker-lite-1',
          urdfToken: EdgePrivacyTokenCatalog.actionSquat,
          trajectoryToken: EdgePrivacyTokenCatalog.phaseUp,
          jointCount: 17,
          frameCount: 60,
          durationMs: 1000,
          stateTokens: [],
        );
        final privacyResult = await client.submitPrivacyFlow(privacy);
        expect(privacyResult.status, 'completed');
        expect(privacyResult.overlay['available'], isTrue);
        expect(
          (await client.deleteCachedSummaries(
            'install_dart_live_contract',
          ))['deleted'],
          isTrue,
        );
      } finally {
        client.close();
      }
    },
    skip: live == null
        ? 'Set APP_AGENT_LIVE_URL for live service contract testing'
        : false,
  );
}
