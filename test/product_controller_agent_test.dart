import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ai_fitness_d_starter/core/models/agent_connection.dart';
import 'package:ai_fitness_d_starter/core/models/coach_session_summary.dart';
import 'package:ai_fitness_d_starter/core/models/coach_memory.dart';
import 'package:ai_fitness_d_starter/core/models/nutrition_advice.dart';
import 'package:ai_fitness_d_starter/core/models/session_result.dart';
import 'package:ai_fitness_d_starter/core/models/training_plan.dart';
import 'package:ai_fitness_d_starter/core/models/user_profile_snapshot.dart';
import 'package:ai_fitness_d_starter/features/product/data/coach_repository.dart';
import 'package:ai_fitness_d_starter/features/product/data/coach_chat_repository.dart';
import 'package:ai_fitness_d_starter/features/product/data/local_product_repository.dart';
import 'package:ai_fitness_d_starter/features/product/data/template_coach_repository.dart';
import 'package:ai_fitness_d_starter/features/product/domain/product_controller.dart';

const profile = UserProfileSnapshot(
  goal: '建立运动习惯',
  experience: '新手',
  daysPerWeek: 2,
  minutesPerSession: 15,
  hasEquipment: false,
  hasCurrentDiscomfort: false,
  dietPreference: '无特别偏好',
);
const consent = AgentConnection(allowDataUpload: true);

class MemoryLocal extends LocalProductRepository {
  MemoryLocal() : super(SharedPreferencesAsync());
  UserProfileSnapshot value = profile;
  List<SessionResult> records = [];
  Map<String, CoachSessionSummary> stored = {};
  @override
  Future<UserProfileSnapshot?> loadProfile() async => value;
  @override
  Future<void> saveProfile(UserProfileSnapshot profile) async {
    value = profile;
  }

  @override
  Future<AgentConnection?> loadConnection() async => null;
  @override
  Future<void> saveConnection(AgentConnection value) async {}
  @override
  Future<List<SessionResult>> loadHistory() async => List.of(records);
  @override
  Future<void> saveSession(SessionResult result) async {
    records.insert(0, result);
  }

  @override
  Future<String> loadOrCreateInstallationId() async =>
      'install_controller_test';
  @override
  Future<void> saveSummary(CoachSessionSummary summary) async {
    stored[summary.sessionId] = summary;
  }

  @override
  Future<CoachSessionSummary?> loadSummary(String sessionId) async =>
      stored[sessionId];
}

class FakeCoach extends CoachRepository {
  final pending = Completer<CoachSessionSummary?>();
  bool nutritionFails = false;
  int summaryCalls = 0;
  int planCalls = 0;
  Future<TrainingPlan> Function(UserProfileSnapshot)? planHandler;
  @override
  Future<TrainingPlan> fetchPlan(
    UserProfileSnapshot current,
    List<SessionResult> history,
  ) async {
    planCalls++;
    if (planHandler != null) return planHandler!(current);
    final plan = TemplateCoachRepository().plan(current, history);
    return TrainingPlan(
      planId: 'agent',
      stageName: plan.stageName,
      headline: current.goal,
      reason: plan.reason,
      item: plan.item,
      source: 'agent',
    );
  }

  @override
  Future<NutritionAdvice> fetchNutrition(UserProfileSnapshot current) async {
    if (nutritionFails) throw StateError('nutrition unavailable');
    return const NutritionAdvice(title: 'Agent', body: '建议', source: 'agent');
  }

  @override
  Future<CoachSessionSummary?> fetchSummary({
    required String installationId,
    required UserProfileSnapshot profile,
    required SessionResult session,
    List<SessionResult> history = const [],
  }) {
    summaryCalls++;
    return pending.future;
  }
}

class FakeChat implements CoachChatRepository {
  int syncCalls = 0;
  int fetchCalls = 0;
  int sendCalls = 0;
  int deleteCalls = 0;
  String? lastInstallationId;
  List<SessionResult> sentHistory = const [];

  @override
  void configure(AgentConnection connection) {}

  @override
  Future<void> syncProfile(
    String installationId,
    UserProfileSnapshot profile,
  ) async {
    syncCalls++;
    lastInstallationId = installationId;
  }

  @override
  Future<CoachMemorySnapshot> fetchMemory(String installationId) async {
    fetchCalls++;
    return CoachMemorySnapshot(
      userId: installationId,
      profile: const {'goal': 'general_fitness'},
      profileUpdatedAt: null,
      recentReports: const [],
      recentRecords: const [],
      chatMessages: const [CoachChatMessage(role: 'assistant', content: '已记录')],
      recordCounts: const {},
      storage: 'local_sqlite',
    );
  }

  @override
  Future<CoachChatReply> sendMessage({
    required String installationId,
    required String message,
    required UserProfileSnapshot profile,
    required List<SessionResult> history,
    TrainingPlan? currentPlan,
  }) async {
    sendCalls++;
    sentHistory = history;
    return const CoachChatReply(
      reply: '已记录',
      sourceIds: [],
      sources: [],
      memoryUsed: [],
      modelCalled: true,
    );
  }

  @override
  Future<void> deleteMemory(String installationId) async {
    deleteCalls++;
  }

  @override
  void close() {}
}

SessionResult result(String id, {String source = 'real'}) => SessionResult(
  sessionId: id,
  status: 'completed',
  finishedAt: DateTime.now(),
  durationSeconds: 30,
  exercises: const [
    SessionExercise(exerciseId: 'squat', completedSets: 1, completedReps: 6),
  ],
  source: source,
);
CoachSessionSummary summary(String id) => CoachSessionSummary(
  sessionId: id,
  agentSummary: '训练已记录',
  source: 'agent',
  nextPlanChanged: false,
  facts: const {},
  limitations: const [],
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test('without consent initialize and training stay entirely local', () async {
    final coach = FakeCoach();
    final controller = ProductController(MemoryLocal(), coach);
    await controller.initialize();
    await controller.recordSession(result('local'));
    await settle();
    expect(controller.history, hasLength(1));
    expect(coach.planCalls, 0);
    expect(coach.summaryCalls, 0);
    controller.dispose();
  });
  test('nutrition failure does not discard a successful Agent plan', () async {
    final coach = FakeCoach()..nutritionFails = true;
    final controller = ProductController(
      MemoryLocal(),
      coach,
      initialConnection: consent,
    );
    await controller.initialize();
    await controller.refreshCoach();
    expect(controller.plan!.source, 'agent');
    expect(controller.planUsingFallback, isFalse);
    expect(controller.nutritionUsingFallback, isTrue);
    controller.dispose();
  });
  test(
    'save and return before the model; cached summary is separate and keyed',
    () async {
      final local = MemoryLocal();
      final coach = FakeCoach();
      final controller = ProductController(
        local,
        coach,
        initialConnection: consent,
      );
      await controller.initialize();
      await controller.refreshCoach();
      final original = result('one');
      await controller
          .recordSession(original)
          .timeout(const Duration(seconds: 1));
      await settle();
      expect(local.records.single, same(original));
      expect(controller.summarizing, contains('one'));
      await controller.retrySummary(original);
      expect(coach.summaryCalls, 1);
      coach.pending.complete(summary('one'));
      await settle();
      expect(controller.summaries['one']!.agentSummary, '训练已记录');
      expect(local.records.single.agentSummary, isNull);
      controller.dispose();
    },
  );
  test('mock record is saved but never submitted', () async {
    final coach = FakeCoach();
    final controller = ProductController(
      MemoryLocal(),
      coach,
      initialConnection: consent,
    );
    await controller.initialize();
    await controller.recordSession(result('mock', source: 'mock'));
    await settle();
    expect(coach.summaryCalls, 0);
    controller.dispose();
  });
  test(
    'summary failure is visible without losing the training record',
    () async {
      final coach = FakeCoach();
      final controller = ProductController(
        MemoryLocal(),
        coach,
        initialConnection: consent,
      );
      await controller.initialize();
      await controller.recordSession(result('fail'));
      await settle();
      coach.pending.completeError(StateError('model unavailable'));
      await settle();
      expect(controller.history.single.sessionId, 'fail');
      expect(controller.summaryErrors['fail'], contains('model unavailable'));
      expect(controller.summarizing, isEmpty);
      controller.dispose();
    },
  );
  test('late old-profile response cannot overwrite the new profile', () async {
    final pending = Completer<TrainingPlan>();
    final coach = FakeCoach()
      ..planHandler = (current) async {
        if (current.goal == profile.goal) return pending.future;
        return TrainingPlan(
          planId: 'new',
          stageName: '新',
          headline: current.goal,
          reason: '新档案',
          item: null,
          source: 'agent',
        );
      };
    final controller = ProductController(
      MemoryLocal(),
      coach,
      initialConnection: consent,
    );
    await controller.initialize();
    await controller.saveProfile(
      UserProfileSnapshot.fromJson({...profile.toJson(), 'goal': '提升力量'}),
    );
    await settle();
    pending.complete(
      const TrainingPlan(
        planId: 'old',
        stageName: '旧',
        headline: '旧',
        reason: '旧档案',
        item: null,
        source: 'agent',
      ),
    );
    await settle();
    expect(controller.plan!.planId, 'new');
    controller.dispose();
  });
  test('discomfort locally blocks a remote plan even with consent', () async {
    final coach = FakeCoach();
    final local = MemoryLocal()
      ..value = UserProfileSnapshot.fromJson({
        ...profile.toJson(),
        'has_current_discomfort': true,
      });
    final controller = ProductController(
      local,
      coach,
      initialConnection: consent,
    );
    await controller.initialize();
    await controller.refreshCoach();
    expect(coach.planCalls, 0);
    expect(controller.plan!.item, isNull);
    controller.dispose();
  });
  test('chat uses installation identity and refreshes server memory', () async {
    final local = MemoryLocal()..records = [result('recent')];
    final chat = FakeChat();
    final controller = ProductController(
      local,
      FakeCoach(),
      chat: chat,
      initialConnection: consent,
    );
    await controller.initialize();
    await controller.refreshChatMemory();
    expect(chat.syncCalls, 1);
    expect(chat.lastInstallationId, 'install_controller_test');
    expect(controller.coachMemory!.chatMessages.single.content, '已记录');

    expect(await controller.sendChatMessage('下一次怎么练？'), isTrue);
    expect(chat.sendCalls, 1);
    expect(chat.sentHistory.single.sessionId, 'recent');
    expect(chat.fetchCalls, 2);

    await controller.deleteChatMemory();
    expect(chat.deleteCalls, 1);
    expect(controller.coachMemory!.chatMessages, isEmpty);
    controller.dispose();
  });

  test('chat remains local until data sharing is enabled', () async {
    final chat = FakeChat();
    final controller = ProductController(
      MemoryLocal(),
      FakeCoach(),
      chat: chat,
    );
    await controller.initialize();
    expect(await controller.sendChatMessage('你好'), isFalse);
    expect(chat.syncCalls, 0);
    expect(chat.sendCalls, 0);
    expect(controller.chatError, contains('允许传输'));
    controller.dispose();
  });
}
