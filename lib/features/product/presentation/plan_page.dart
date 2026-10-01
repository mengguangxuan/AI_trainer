import 'package:flutter/material.dart';

import '../domain/product_controller.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({super.key, required this.controller, required this.onStart,
    required this.busy});

  final ProductController controller;
  final Future<void> Function() onStart;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan!;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text('阶段计划', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 10),
      Chip(label: Text('${plan.stageName} · ${plan.source == 'template' ? '本地示例' : 'Agent'}')),
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.headline, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10), Text(plan.reason),
          if (plan.item != null) ...[
            const Divider(height: 32),
            Text(plan.item!.title, style: Theme.of(context).textTheme.titleMedium),
            Text('${plan.item!.targetSets} 组 × ${plan.item!.targetReps} 次 · 组间休息 ${plan.item!.restSeconds} 秒'),
          ],
        ]),
      )),
      if (plan.item != null) ...[
        const SizedBox(height: 12),
        FilledButton(onPressed: busy ? null : onStart,
            child: Text(busy ? '正在打开…' : '开始这项训练')),
      ],
      const SizedBox(height: 18),
      const Text('这是为了串通产品流程的模板计划，不代表已接入阶段规划 Agent。'),
    ]);
  }
}
