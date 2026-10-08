import 'dart:io';

import 'package:ai_fitness_d_starter/core/models/agent_connection.dart';
import 'package:ai_fitness_d_starter/core/models/coach_memory.dart';
import 'package:ai_fitness_d_starter/core/models/nutrition_advice.dart';
import 'package:ai_fitness_d_starter/core/models/session_result.dart';
import 'package:ai_fitness_d_starter/core/models/training_launch_args.dart';
import 'package:ai_fitness_d_starter/core/models/training_plan.dart';
import 'package:ai_fitness_d_starter/core/models/user_profile_snapshot.dart';
import 'package:ai_fitness_d_starter/core/theme/app_theme.dart';
import 'package:ai_fitness_d_starter/features/product/data/coach_chat_repository.dart';
import 'package:ai_fitness_d_starter/features/product/data/coach_repository.dart';
import 'package:ai_fitness_d_starter/features/product/data/local_product_repository.dart';
import 'package:ai_fitness_d_starter/features/product/domain/product_controller.dart';
import 'package:ai_fitness_d_starter/features/product/presentation/product_shell.dart';
import 'package:ai_fitness_d_starter/features/training_contract/training_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late ThemeData previewTheme;

  setUpAll(() async {
    final fontBytes = File(r'C:\Windows\Fonts\msyh.ttc').readAsBytesSync();
    final fontLoader = FontLoader('UiPreviewChinese')
      ..addFont(Future.value(ByteData.sublistView(fontBytes)));
    final iconBytes = File(
      r'E:\dev\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconBytes)));
    await Future.wait([fontLoader.load(), iconLoader.load()]);
    final baseTheme = AppTheme.light;
    previewTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'UiPreviewChinese'),
      primaryTextTheme: baseTheme.primaryTextTheme.apply(
        fontFamily: 'UiPreviewChinese',
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        titleTextStyle: baseTheme.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'UiPreviewChinese',
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: baseTheme.filledButtonTheme.style?.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'UiPreviewChinese',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: baseTheme.outlinedButtonTheme.style?.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'UiPreviewChinese',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: baseTheme.textButtonTheme.style?.copyWith(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'UiPreviewChinese',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('render UI refresh previews', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final local = LocalProductRepository(SharedPreferencesAsync());
    await local.saveProfile(
      const UserProfileSnapshot(
        goal: '建立运动习惯',
        experience: '新手',
        daysPerWeek: 3,
        minutesPerSession: 20,
        hasEquipment: false,
        hasCurrentDiscomfort: false,
        dietPreference: '无特别偏好',
      ),
    );
    await local.saveConnection(const AgentConnection(allowDataUpload: true));
    await local.saveSession(
      SessionResult(
        sessionId: 'ui-preview-session',
        status: 'completed',
        finishedAt: DateTime.now(),
        durationSeconds: 68,
        source: 'real',
        exercises: const [
          SessionExercise(
            exerciseId: 'squat',
            completedSets: 1,
            completedReps: 6,
          ),
        ],
      ),
    );
    final controller = ProductController(
      local,
      _PreviewCoach(),
      chat: _PreviewChat(),
      initialConnection: const AgentConnection(allowDataUpload: true),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('prototype'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: previewTheme,
          home: ProductShell(
            controller: controller,
            training: _PreviewTraining(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/home.png'),
    );

    await tester.tap(find.text('自由训练'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/training-picker.png'),
    );
    Navigator.of(tester.element(find.text('选择自由训练动作'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/plan.png'),
    );

    await tester.tap(find.text('饮食'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/nutrition.png'),
    );

    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/history.png'),
    );

    await tester.tap(find.text('已完成训练'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/summary.png'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('教练'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/coach.png'),
    );

    await tester.tap(find.text('AI 私教'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/memory.png'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Agent 连接'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/settings.png'),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('修改档案'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('prototype')),
      matchesGoldenFile('../docs/ui-prototype/profile.png'),
    );
  });
}

class _PreviewCoach extends CoachRepository {
  @override
  Future<TrainingPlan> fetchPlan(
    UserProfileSnapshot profile,
    List<SessionResult> history,
  ) async => const TrainingPlan(
    planId: 'preview-plan',
    stageName: '适应期',
    headline: '今天从深蹲开始',
    reason: '保持稳定节奏，完成一组基础练习。',
    item: TrainingPlanItem(
      id: 'preview-item',
      exerciseId: 'squat',
      title: '徒手深蹲',
      targetSets: 1,
      targetReps: 6,
      restSeconds: 45,
    ),
    source: 'agent',
  );

  @override
  Future<NutritionAdvice> fetchNutrition(UserProfileSnapshot profile) async =>
      const NutritionAdvice(
        title: '训练日均衡搭配',
        body: '主食搭配蔬菜和一份蛋白质来源，按饥饿感调整份量。',
        source: 'agent',
      );
}

class _PreviewChat implements CoachChatRepository {
  @override
  void configure(AgentConnection connection) {}

  @override
  Future<void> syncProfile(
    String installationId,
    UserProfileSnapshot profile,
  ) async {}

  @override
  Future<CoachMemorySnapshot> fetchMemory(String installationId) async =>
      CoachMemorySnapshot(
        userId: installationId,
        profile: const {'goal': 'general_fitness'},
        profileUpdatedAt: DateTime.now().toIso8601String(),
        recentReports: const [
          {'session_id': 'ui-preview-session'},
        ],
        recentRecords: const [],
        chatMessages: const [
          CoachChatMessage(role: 'user', content: '今天适合练什么？'),
          CoachChatMessage(
            role: 'assistant',
            content: '今天可以按计划完成 1 组徒手深蹲，共 6 次。先充分热身，保持稳定节奏；如有不适请停止。',
          ),
        ],
        recordCounts: const {'workout': 1},
        storage: 'local_sqlite',
      );

  @override
  Future<CoachChatReply> sendMessage({
    required String installationId,
    required String message,
    required UserProfileSnapshot profile,
    required List<SessionResult> history,
    TrainingPlan? currentPlan,
  }) async => const CoachChatReply(
    reply: '继续保持稳定节奏。',
    sourceIds: [],
    sources: [],
    memoryUsed: [],
    modelCalled: true,
  );

  @override
  Future<void> deleteMemory(String installationId) async {}

  @override
  void close() {}
}

class _PreviewTraining implements TrainingGateway {
  @override
  Future<SessionResult?> start(
    BuildContext context,
    TrainingLaunchArgs args,
  ) async => null;
}
