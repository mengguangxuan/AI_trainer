import 'package:flutter/material.dart';

import '../core/models/session_result.dart';
import '../core/models/training_launch_args.dart';
import '../features/training_contract/training_gateway.dart';

class MockTrainingGateway implements TrainingGateway {
  @override
  Future<SessionResult?> start(
    BuildContext context,
    TrainingLaunchArgs args,
  ) => Navigator.of(context).push<SessionResult>(
        MaterialPageRoute(builder: (_) => _MockTrainingPage(args: args)),
      );
}

class _MockTrainingPage extends StatelessWidget {
  const _MockTrainingPage({required this.args});

  final TrainingLaunchArgs args;

  SessionResult _result(String status) => SessionResult(
        sessionId: 'mock_${DateTime.now().microsecondsSinceEpoch}',
        status: status,
        finishedAt: DateTime.now(),
        durationSeconds: status == 'completed' ? 35 : 5,
        exercises: status == 'completed'
            ? [
                SessionExercise(
                  exerciseId: 'squat',
                  completedSets: args.exercises.firstOrNull?.targetSets ?? 0,
                  completedReps: args.exercises.firstOrNull?.targetReps ?? 0,
                  mainErrorCode: 'squat.depth_low',
                ),
              ]
            : [],
        agentSummary: status == 'completed'
            ? '模拟反馈：已完成本次练习；下次留意下蹲幅度。'
            : null,
        nextPlanChanged: status == 'completed',
        source: 'mock',
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('模拟训练入口')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.science_outlined, size: 72),
                const SizedBox(height: 20),
                const Text('这里尚未连接摄像头或姿态识别',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('仅用于验证 D 的计划入口、结果页、历史和下次安排。以下次数与纠错事件均为模拟数据。'),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _result('completed')),
                  child: const Text('模拟完成训练'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, _result('cancelled')),
                  child: const Text('模拟中途退出'),
                ),
              ],
            ),
          ),
        ),
      );
}
