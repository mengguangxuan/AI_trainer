import 'package:flutter/material.dart';

import '../../../core/models/session_result.dart';

class SessionSummaryPage extends StatelessWidget {
  const SessionSummaryPage({super.key, required this.result, this.saved = true});

  final SessionResult result;
  final bool saved;

  String _errorText(String? code) => switch (code) {
        'squat.depth_low' => '本次记录提示：下蹲幅度可能不足。',
        'squat.knee_valgus' => '本次记录提示：膝盖方向需要注意。',
        null => '没有可用的动作错误记录。',
        _ => '收到动作反馈代码：$code；目前没有对应的中文解释。',
      };

  @override
  Widget build(BuildContext context) {
    final completed = result.isCompleted;
    final exercise = result.exercises.firstOrNull;
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
        if (result.source == 'mock')
          const Chip(label: Text('模拟训练结果 · 次数与反馈不来自摄像头')),
        if (result.source != 'mock' && result.source != 'real')
          const Chip(label: Text('结果来源未确认')),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('时长：${result.durationSeconds} 秒'),
            Text('完成次数：${exercise?.completedReps ?? 0} 次'),
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
