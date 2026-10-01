import 'package:flutter/material.dart';

import '../domain/product_controller.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key, required this.controller});

  final ProductController controller;

  @override
  Widget build(BuildContext context) {
    final advice = controller.nutrition!;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text('饮食建议', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      Chip(label: Text(advice.source == 'template' ? '本地示例模板' : 'Agent 建议')),
      Card(child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(advice.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12), Text(advice.body),
        ]),
      )),
      const SizedBox(height: 14),
      const Text('本页面不计算热量或提供疾病、过敏的个体化医疗建议。'),
    ]);
  }
}
