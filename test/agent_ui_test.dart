import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ai_fitness_d_starter/core/models/agent_connection.dart';
import 'package:ai_fitness_d_starter/core/models/session_result.dart';
import 'package:ai_fitness_d_starter/core/models/training_plan.dart';
import 'package:ai_fitness_d_starter/core/models/user_profile_snapshot.dart';
import 'package:ai_fitness_d_starter/core/theme/app_theme.dart';
import 'package:ai_fitness_d_starter/features/product/data/local_product_repository.dart';
import 'package:ai_fitness_d_starter/features/product/data/template_coach_repository.dart';
import 'package:ai_fitness_d_starter/features/product/domain/product_controller.dart';
import 'package:ai_fitness_d_starter/features/product/presentation/agent_settings_page.dart';
import 'package:ai_fitness_d_starter/features/product/presentation/coach_chat_page.dart';
import 'package:ai_fitness_d_starter/features/product/presentation/home_page.dart';
import 'package:ai_fitness_d_starter/features/product/presentation/session_summary_page.dart';

void main() {
  late ProductController controller;
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final local = LocalProductRepository(SharedPreferencesAsync());
    await local.saveProfile(
      const UserProfileSnapshot(
        goal: '建立运动习惯',
        experience: '新手',
        daysPerWeek: 2,
        minutesPerSession: 15,
        hasEquipment: false,
        hasCurrentDiscomfort: false,
        dietPreference: '无特别偏好',
      ),
    );
    controller = ProductController(local, TemplateCoachRepository());
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    testWidgets('connection screen fits $size and consent defaults off', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AgentSettingsPage(controller: controller),
        ),
      );
      expect(find.text('Agent 连接'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.ensureVisible(find.text('保存配置'));
      await tester.tap(find.text('保存配置'));
      await tester.pumpAndSettle();
      expect(controller.connection.allowDataUpload, isFalse);
      expect(find.text('配置已保存，当前使用本地模式。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('rest plan is not mislabelled as a health warning', (
    tester,
  ) async {
    // A no-item response can be scheduled rest, not just local discomfort.
    controller.plan = const TrainingPlan(
      planId: 'rest',
      stageName: '本周安排',
      headline: '今天安排休息',
      reason: '今天已记录完成训练',
      item: null,
      source: 'template',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HomePage(
            controller: controller,
            onStart: () async {},
            onStartFree: () async {},
            onEditProfile: () {},
            busy: false,
          ),
        ),
      ),
    );
    expect(find.text('今天安排休息'), findsOneWidget);
    expect(find.text('先处理当前不适'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('chat page keeps data sharing opt-in', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CoachChatPage(controller: controller)),
      ),
    );
    await tester.pump();
    expect(find.text('聊天与记忆尚未启用'), findsOneWidget);
    expect(find.textContaining('允许 Agent 使用训练数据'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed Agent summary retains saved counts and retry entry', (
    tester,
  ) async {
    controller.connection = const AgentConnection(allowDataUpload: true);
    final record = SessionResult(
      sessionId: 'ui_summary',
      status: 'completed',
      finishedAt: DateTime.now(),
      durationSeconds: 25,
      source: 'real',
      exercises: const [
        SessionExercise(
          exerciseId: 'squat',
          completedSets: 1,
          completedReps: 6,
        ),
      ],
    );
    controller.summaryErrors[record.sessionId] = '模型未配置';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SessionSummaryPage(result: record, controller: controller),
      ),
    );
    expect(find.text('本次训练已完成'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    await tester.ensureVisible(find.text('重试教练总结'));
    expect(find.text('模型未配置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
