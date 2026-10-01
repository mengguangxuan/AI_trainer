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

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('passes plan to Android and decodes real completion',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'startTraining');
      final plan = Map<String, dynamic>.from(call.arguments as Map);
      expect(plan['schema_version'], 1);
      expect((plan['exercises'] as List).first['exercise_id'], 'squat');
      return {
        'schema_version': 1,
        'session_id': 'real_1',
        'status': 'completed',
        'finished_at': '2026-10-01T20:00:00+08:00',
        'duration_seconds': 35,
        'exercises': [
          <Object?, Object?>{
            'exercise_id': 'squat',
            'completed_sets': 1,
            'completed_reps': 6,
            'quality_trend': null,
            'main_error_code': null,
          },
        ],
        'agent_summary': null,
        'next_plan_changed': false,
        'source': 'real',
      };
    });
    final result = await NativeTrainingGateway(channel: channel)
        .start(context, args);
    expect(result?.isCompleted, isTrue);
    expect(result?.exercises.single.completedReps, 6);
    expect(result?.source, 'real');
  });

  testWidgets('rejects malformed completion before history can save it',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const SizedBox();
    })));
    messenger.setMockMethodCallHandler(channel, (call) async => {
          'schema_version': 1,
          'session_id': 'bad_1',
          'status': 'completed',
          'finished_at': '2026-10-01T20:00:00+08:00',
          'duration_seconds': 0,
          'exercises': [],
          'source': 'real',
        });
    await expectLater(
      NativeTrainingGateway(channel: channel).start(context, args),
      throwsFormatException,
    );
  });
}
