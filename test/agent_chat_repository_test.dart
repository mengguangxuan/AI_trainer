import 'dart:convert';
import 'dart:io';

import 'package:ai_fitness_d_starter/core/models/agent_connection.dart';
import 'package:ai_fitness_d_starter/core/models/session_result.dart';
import 'package:ai_fitness_d_starter/core/models/training_plan.dart';
import 'package:ai_fitness_d_starter/core/models/user_profile_snapshot.dart';
import 'package:ai_fitness_d_starter/features/product/data/agent_chat_repository.dart';
import 'package:ai_fitness_d_starter/features/product/data/agent_coach_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const profile = UserProfileSnapshot(
  goal: '提升力量',
  experience: '新手',
  daysPerWeek: 3,
  minutesPerSession: 20,
  hasEquipment: false,
  hasCurrentDiscomfort: true,
  dietPreference: '素食',
);

void main() {
  test('memory profile projection excludes discomfort and medical guesses', () {
    final projected = AgentChatRepository.projectMemoryProfile(profile);
    expect(projected['goal'], 'strength');
    expect(projected['experience'], 'beginner');
    expect(projected['dietary_preferences'], ['vegetarian']);
    expect(projected.containsKey('has_current_discomfort'), isFalse);
    expect(projected['medical_conditions'], isEmpty);
  });

  group('real HTTP chat and memory serialization', () {
    late HttpServer server;
    late AgentChatRepository repository;
    late List<Map<String, dynamic>> requests;
    late int chatStatus;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      requests = [];
      chatStatus = 200;
      repository = AgentChatRepository(
        appBaseUrl: Uri.parse('http://127.0.0.1:${server.port}/api/app/v1/'),
        devToken: 'dev-token',
      );
      server.listen((request) async {
        final text = await utf8.decoder.bind(request).join();
        requests.add({
          'path': request.uri.path,
          'query': request.uri.query,
          'authorization': request.headers.value(
            HttpHeaders.authorizationHeader,
          ),
          if (text.isNotEmpty) 'body': jsonDecode(text),
        });
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/memory/profile')) {
          request.response.write(jsonEncode({'profile': {}}));
        } else if (request.uri.path.endsWith('/chat')) {
          request.response.statusCode = chatStatus;
          request.response.write(
            jsonEncode(
              chatStatus == 200
                  ? {
                      'reply': '建议保持当前训练频率。',
                      'source_ids': <String>[],
                      'sources': <String>[],
                      'memory_used': ['profile.goal'],
                      'agent': {'model_called': true},
                    }
                  : {'detail': '尚未配置模型。'},
            ),
          );
        } else if (request.method == 'GET') {
          request.response.write(
            jsonEncode({
              'user_id': 'installation-1234',
              'profile': {'goal': 'strength'},
              'profile_updated_at': null,
              'recent_reports': <Object>[],
              'recent_records': <Object>[],
              'chat_messages': [
                {'role': 'user', 'content': '怎么安排？'},
                {'role': 'assistant', 'content': '保持当前频率。'},
              ],
              'record_counts': {'plan': 1},
              'storage': 'local_sqlite',
            }),
          );
        } else {
          request.response.write(jsonEncode({'deleted': true}));
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      repository.close();
      await server.close(force: true);
    });

    test(
      'uses legacy API paths with installation id and bounded context',
      () async {
        const installationId = 'installation-1234';
        await repository.syncProfile(installationId, profile);
        final reply = await repository.sendMessage(
          installationId: installationId,
          message: ' 怎么安排？ ',
          profile: profile,
          history: [
            SessionResult(
              sessionId: 'real-one',
              status: 'completed',
              finishedAt: DateTime.utc(2026, 10, 7),
              durationSeconds: 30,
              exercises: const [
                SessionExercise(
                  exerciseId: 'squat',
                  completedSets: 1,
                  completedReps: 6,
                ),
              ],
              source: 'real',
            ),
            SessionResult(
              sessionId: 'mock-one',
              status: 'completed',
              finishedAt: DateTime.utc(2026, 10, 7),
              durationSeconds: 30,
              exercises: const [],
              source: 'mock',
            ),
          ],
          currentPlan: const TrainingPlan(
            planId: 'p1',
            stageName: '适应期',
            headline: '基础训练',
            reason: '保持规律',
            source: 'agent',
            item: TrainingPlanItem(
              id: 'i1',
              exerciseId: 'squat',
              title: '徒手深蹲',
              targetSets: 1,
              targetReps: 6,
              restSeconds: 45,
            ),
          ),
        );
        final memory = await repository.fetchMemory(installationId);
        await repository.deleteMemory(installationId);

        expect(reply.reply, contains('训练频率'));
        expect(reply.modelCalled, isTrue);
        expect(memory.chatMessages, hasLength(2));
        expect(requests.map((request) => request['path']), [
          '/api/memory/profile',
          '/api/chat',
          '/api/memory',
          '/api/memory/delete',
        ]);
        expect(
          requests.every((r) => r['authorization'] == 'Bearer dev-token'),
          isTrue,
        );
        final chatBody = requests[1]['body'] as Map<String, dynamic>;
        expect(chatBody['user_id'], installationId);
        expect(chatBody['message'], '怎么安排？');
        final context = chatBody['context'] as Map<String, dynamic>;
        expect(context.containsKey('has_current_discomfort'), isFalse);
        expect(
          (context['app_profile'] as Map).containsKey('has_current_discomfort'),
          isFalse,
        );
        expect(context['recent_sessions'], hasLength(1));
      },
    );

    test('preserves a legacy string error message', () async {
      chatStatus = 503;
      await expectLater(
        repository.sendMessage(
          installationId: 'installation-1234',
          message: '你好',
          profile: profile,
          history: const [],
        ),
        throwsA(
          isA<AgentCoachException>()
              .having((error) => error.code, 'code', 'HTTP_503')
              .having((error) => error.message, 'message', '尚未配置模型。'),
        ),
      );
    });
  });

  test('connection reuses the App Coach endpoint validation', () {
    final repository = AgentChatRepository(
      appBaseUrl: Uri.parse('http://127.0.0.1:8000/api/app/v1/'),
    );
    addTearDown(repository.close);
    expect(
      () => repository.configure(
        const AgentConnection(baseUrl: 'http://127.0.0.1:8000/wrong'),
      ),
      throwsA(isA<AgentCoachException>()),
    );
  });

  final live = Platform.environment['APP_AGENT_LIVE_URL'];
  test(
    'live Agent persists and deletes an APP chat exchange',
    () async {
      final repository = AgentChatRepository(appBaseUrl: Uri.parse(live!));
      const installationId = 'installation_chat_live_contract';
      try {
        await repository.syncProfile(installationId, profile);
        final reply = await repository.sendMessage(
          installationId: installationId,
          message: 'chest_pain',
          profile: profile,
          history: const [],
        );
        expect(reply.modelCalled, isFalse);
        final memory = await repository.fetchMemory(installationId);
        expect(memory.chatMessages, hasLength(2));
      } finally {
        await repository.deleteMemory(installationId);
        repository.close();
      }
    },
    skip: live == null
        ? 'Set APP_AGENT_LIVE_URL for live chat contract testing'
        : false,
  );
}
