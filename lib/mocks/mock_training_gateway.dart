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

  // 模拟"真实端侧计数"：完成时恰好达标；取消/中断时给出部分次数。
  // 与 training_bridge_v1_frozen.md §3 一致：训练已开始后的 cancelled/interrupted
  // 也携带该动作的真实计数（这里是模拟值），由 D 端决定不计入完成统计。
  int get _targetReps => args.exercises.firstOrNull?.targetReps ?? 6;

  SessionResult _result(String status, {required int reps}) => SessionResult(
        sessionId: 'mock_${DateTime.now().microsecondsSinceEpoch}',
        status: status,
        finishedAt: DateTime.now(),
        durationSeconds: switch (status) {
          'completed' => 35,
          'cancelled' => 18,
          _ => 5,
        },
        exercises: reps > 0
            ? [
                SessionExercise(
                  exerciseId:
                      args.exercises.firstOrNull?.exerciseId ?? 'squat',
                  // 与协议一致：仅 completed 且达标时组数为 1，其余为 0。
                  completedSets:
                      status == 'completed' && reps >= _targetReps ? 1 : 0,
                  completedReps: reps,
                  mainErrorCode:
                      status == 'completed' ? 'squat.depth_shallow' : null,
                ),
              ]
            : const [],
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
                  onPressed: () =>
                      Navigator.pop(context, _result('completed', reps: _targetReps)),
                  child: const Text('模拟完成训练'),
                ),
                OutlinedButton(
                  // 模拟中途退出：携带部分完成次数（协议 §4 cancelled 语义）
                  onPressed: () => Navigator.pop(
                      context, _result('cancelled', reps: 3)),
                  child: const Text('模拟中途退出（已完成 3 次）'),
                ),
                OutlinedButton(
                  // 模拟权限拒绝/异常中断：训练刚开始，无计数（协议 §4 interrupted 语义）
                  onPressed: () =>
                      Navigator.pop(context, _result('interrupted', reps: 0)),
                  child: const Text('模拟异常中断（相机不可用）'),
                ),
              ],
            ),
          ),
        ),
      );
}
