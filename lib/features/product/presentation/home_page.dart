import 'package:flutter/material.dart';

import '../domain/product_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller, required this.onStart,
    required this.onEditProfile, required this.busy});

  final ProductController controller;
  final Future<void> Function() onStart;
  final VoidCallback onEditProfile;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final plan = controller.plan!;
    final nutrition = controller.nutrition!;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(children: [
          Expanded(child: Text('今天，向 ${profile.goal} 迈一步',
              style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(onPressed: onEditProfile, tooltip: '修改档案',
              icon: const Icon(Icons.person_outline)),
        ]),
        const SizedBox(height: 12),
        _panel(context, Icons.bolt_outlined, plan.stageName, plan.headline,
            plan.reason),
        const SizedBox(height: 12),
        if (plan.item != null)
          FilledButton.icon(
            onPressed: busy ? null : onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(busy ? '正在打开…' : '开始今日训练'),
          ),
        if (plan.item == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('当前不提供自动训练入口。你仍可修改档案或查看记录。'),
          ),
        const SizedBox(height: 12),
        _panel(context, Icons.restaurant_outlined, nutrition.title,
            '今日饮食提示', nutrition.body),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(child: _stat('已完成训练', '${controller.completedCount} 次')),
            Expanded(child: _stat('连续训练', '${controller.streak} 天')),
          ]),
        )),
        const SizedBox(height: 12),
        Text(controller.usingFallback
            ? '服务不可用：正在显示本地示例模板。训练结果来源请见总结页。'
            : '计划与饮食来源：${plan.source == 'template' ? '本地示例模板' : 'Agent'}；训练来源请见总结页。',
            style: TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(label), const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold))],
      );

  Widget _panel(BuildContext context, IconData icon, String badge,
      String title, String body) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon), const SizedBox(width: 8), Text(badge)]),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8), Text(body),
          ]),
        ),
      );
}
