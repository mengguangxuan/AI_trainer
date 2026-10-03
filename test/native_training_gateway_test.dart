import 'package:ai_fitness_d_starter/core/models/training_launch_args.dart';
import 'package:ai_fitness_d_starter/features/training_contract/native_training_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai_fitness/training_v1');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const args = TrainingLaunchArgs(
    planItemId: 'squat_01',
    trainingMode: 'planned',
    exercises: [
      LaunchExercise(
        exerciseId: 'squat',
        targetSets: 1,
        targetReps: 6,
        restSeconds: 45,
      ),
    ],
  );

  // docs/contracts/training_bridge_v1_frozen.md §3 的合法返回样例工厂。
  // StandardMessageCodec 解码嵌套 Kotlin Map 得到 Map<Object?, Object?>，
  // 这里刻意用它模拟真实桥返回。
  Map<Object?, Object?> replyFor({
    required String status,
    List<Object?> exercises = const [],
    int durationSeconds = 35,
    Object? source,
  }) =>
      <Object?, Object?>{
        'schema_version': 1,
        'session_id': 'real_1',
        'status': status,
        'finished_at': '2026-10-01T20:00:00+08:00',
        'duration_seconds': durationSeconds,
        'exercises': exercises,
        'agent_summary': null,
        'next_plan_changed': false,
        'source': source ?? 'real',
      };

  Map<Object?, Object?> squatExercise({
    required int reps,
    required int sets,
    Object? errorCode,
  }) =>
      <Object?, Object?>{
        'exercise_id': 'squat',
        'completed_sets': sets,
        'completed_reps': reps,
        'quality_trend': null,
        'main_error_code': errorCode,
      };

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: _CaptureContext()));
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('passes plan to Android and decodes real completion',
      (tester) async {
    await pumpHost(tester);
    final BuildContext context = _CaptureContext.last!;
    var checkedPlan = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'startTraining');
      final plan = Map<Object?, Object?>.from(call.arguments as Map);
      expect(plan['schema_version'], 1);
      expect((plan['exercises'] as List).first is Map, isTrue);
      checkedPlan = true;
      return replyFor(
        status: 'completed',
        exercises: [squatExercise(reps: 6, sets: 1)],
      );
    });
    final result =
        await NativeTrainingGateway(channel: channel).start(context, args);
    expect(checkedPlan, isTrue);
    expect(result?.isCompleted, isTrue);
    expect(result?.exercises.single.completedReps, 6);
    expect(result?.source, 'real');
  });

  testWidgets('cancelled keeps real counts but is not completed',
      (tester) async {
    await pumpHost(tester);
    final BuildContext context = _CaptureContext.last!;
    // 协议 §4：取消返回真实次数（部分完成），D 端不得计为完成。
    messenger.setMockMethodCallHandler(channel, (call) async => replyFor(
          status: 'cancelled',
          durationSeconds: 18,
          exercises: [squatExercise(reps: 3, sets: 0)],
        ));
    final result =
        await NativeTrainingGateway(channel: channel).start(context, args);
    expect(result, isNotNull);
    expect(result!.isCompleted, isFalse);
    expect(result.status, 'cancelled');
    expect(result.exercises.single.completedSets, 0);
    expect(result.exercises.single.completedReps, 3);
  });

  testWidgets('interrupted before start may return empty exercise list',
      (tester) async {
    await pumpHost(tester);
    final BuildContext context = _CaptureContext.last!;
    // 协议 §3：训练开始前中断可返回空列表。
    messenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            replyFor(status: 'interrupted', durationSeconds: 0));
    final result =
        await NativeTrainingGateway(channel: channel).start(context, args);
    expect(result, isNotNull);
    expect(result!.isCompleted, isFalse);
    expect(result.status, 'interrupted');
    expect(result.exercises, isEmpty);
  });

  testWidgets('propagates invalid_arguments PlatformException from native',
      (tester) async {
    await pumpHost(tester);
    final BuildContext context = _CaptureContext.last!;
    // 协议 §4：参数非法时原生抛 PlatformException(invalid_arguments)。
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'invalid_arguments');
    });
    await expectLater(
      NativeTrainingGateway(channel: channel).start(context, args),
      throwsA(isA<PlatformException>()),
    );
  });

  testWidgets('rejects malformed completion before history can save it',
      (tester) async {
    await pumpHost(tester);
    final BuildContext context = _CaptureContext.last!;
    messenger.setMockMethodCallHandler(channel, (call) async => replyFor(
          status: 'completed',
          durationSeconds: 0,
          exercises: const [],
        ));
    await expectLater(
      NativeTrainingGateway(channel: channel).start(context, args),
      throwsFormatException,
    );
  });

  testWidgets('rejects unknown status and non-real source', (tester) async {
    await pumpHost(tester);
    final BuildContext context = _CaptureContext.last!;
    // 未知 status 必须拒绝。
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => replyFor(
              status: 'finished',
              exercises: [squatExercise(reps: 6, sets: 1)],
            ));
    await expectLater(
      NativeTrainingGateway(channel: channel).start(context, args),
      throwsFormatException,
    );

    // 原生桥不得返回 source=mock；D 侧校验拒绝。
    messenger.setMockMethodCallHandler(
        channel,
        (call) async => replyFor(
              status: 'completed',
              exercises: [squatExercise(reps: 6, sets: 1)],
              source: 'mock',
            ));
    await expectLater(
      NativeTrainingGateway(channel: channel).start(context, args),
      throwsFormatException,
    );
  });

  testWidgets('rejects negative counters in exercise result', (tester) async {
    await pumpHost(tester);
    final BuildContext context = _CaptureContext.last!;
    messenger.setMockMethodCallHandler(channel,
        (call) async => replyFor(status: 'completed', exercises: [
              squatExercise(reps: 6, sets: -1),
            ]));
    await expectLater(
      NativeTrainingGateway(channel: channel).start(context, args),
      throwsFormatException,
    );
  });

  testWidgets('rejects a null response because back must return cancelled',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    await expectLater(
      NativeTrainingGateway(channel: channel).start(context, args),
      throwsFormatException,
    );
  });
}

/// 捕获一个可用的 BuildContext 供非组件代码调用 gateway.start()。
class _CaptureContext extends StatefulWidget {
  const _CaptureContext();

  static BuildContext? last;

  @override
  State<_CaptureContext> createState() => _CaptureContextState();
}

class _CaptureContextState extends State<_CaptureContext> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _CaptureContext.last = context;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
