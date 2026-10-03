import 'package:flutter/material.dart';

import '../../../core/models/session_result.dart';

class SessionSummaryPage extends StatelessWidget {
  const SessionSummaryPage(
      {super.key, required this.result, this.saved = true, this.targetReps});

  final SessionResult result;
  final bool saved;

  /// 本组目标次数（由计划入口传入）。仅用于展示"是否达到目标"，
  /// 不改变完成状态的判定——判定以桥返回的 status 为准。
  final int? targetReps;

  /// 错误码文案与 docs/contracts/training_bridge_v1_frozen.md 保持一致；
  /// 未知码只显示代码本身，不推断健康结论。
  String _errorText(String? code) => switch (code) {
        'squat.depth_shallow' => '本次记录提示：下蹲幅度不足（膝角未达标）。',
        'squat.torso_lean' => '本次记录提示：躯干前倾过多，请保持抬头挺胸。',
        'push_up.depth_shallow' => '本次记录提示：俯卧撑下压幅度不足（肘角未达标）。',
        'push_up.body_line_bent' => '本次记录提示：身体线条下塌，请保持肩髋踝一条直线。',
        'camera.landmarks_missing' => '本次记录提示：摄像头未能完整捕捉身体关键点，请调整站位。',
        null => '没有可用的动作错误记录。',
        _ => '收到动作反馈代码：$code；目前没有对应的中文解释。',
      };

  @override
  Widget build(BuildContext context) {
    final completed = result.isCompleted;
    final exercise = result.exercises.firstOrNull;
    final reps = exercise?.completedReps ?? 0;
    // 只有完成状态才判断是否达标；提前结束（cancelled/interrupted）不算"未达目标"，只是未完成。
    final reachedTarget = completed && targetReps != null && reps >= targetReps!;
    return Scaffold(
      appBar: AppBar(title: const Text('训练总结')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Icon(completed ? Icons.celebration_outlined : Icons.info_outline,
            size: 58, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(!saved ? '训练已结束，但记录未保存'
            : completed ? '本次训练已记录' : '本次训练未完成',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (completed && targetReps != null)
          Chip(
            avatar: Icon(reachedTarget ? Icons.check : Icons.info_outline,
                size: 18),
            label: Text(reachedTarget
                ? '已达到本组目标（$reps/$targetReps 次）'
                : '提前结束：完成 $reps 次，未达到目标 $targetReps 次'),
          ),
        if (result.source == 'mock')
          const Chip(label: Text('模拟训练结果 · 次数与反馈不来自摄像头')),
        if (result.source != 'mock' && result.source != 'real')
          const Chip(label: Text('结果来源未确认')),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('时长：${result.durationSeconds} 秒'),
            Text('完成次数：$reps 次'),
            if (exercise != null)
              Text('完成组数：${exercise.completedSets} 组'),
            const SizedBox(height: 10),
            Text(_errorText(exercise?.mainErrorCode)),
          ],
        ))),
        if (result.agentSummary != null) ...[
          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(18),
              child: Text(result.agentSummary!))),
        ],
        const SizedBox(height: 14),
        Text(result.nextPlanChanged && completed
            ? '下一次安排将参考这次已完成的训练。'
            : '本次没有确认的下一次计划调整。'),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.pop(context),
            child: const Text('返回')),
      ])),
    );
  }
}

