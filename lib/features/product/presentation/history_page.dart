import 'package:flutter/material.dart';

import '../domain/product_controller.dart';
import 'session_summary_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final ProductController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.history;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Text('训练记录', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 10),
      Text('完成 ${controller.completedCount} 次 · 连续 ${controller.streak} 天'),
      const SizedBox(height: 14),
      if (items.isEmpty) const Card(child: Padding(
        padding: EdgeInsets.all(22), child: Text('暂无记录。完成一次模拟训练后可在此查看。'))),
      for (final item in items)
        Card(child: ListTile(
          leading: Icon(item.isCompleted ? Icons.check_circle_outline : Icons.pause_circle_outline),
          title: Text(item.isCompleted ? '已完成训练' : '训练未完成'),
          subtitle: Text('${item.finishedAt.toLocal().year}-${item.finishedAt.toLocal().month.toString().padLeft(2, '0')}-${item.finishedAt.toLocal().day.toString().padLeft(2, '0')} · ${item.source == 'mock' ? '模拟' : item.source == 'real' ? '真实' : '来源未确认'}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SessionSummaryPage(result: item))),
        )),
    ]);
  }
}
