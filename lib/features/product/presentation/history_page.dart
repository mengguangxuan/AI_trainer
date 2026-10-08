import 'package:flutter/material.dart';

import '../../../core/models/session_result.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/product_controller.dart';
import 'product_ui.dart';
import 'session_summary_page.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});

  final ProductController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.history;
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        ProductHero(
          eyebrow: 'YOUR MOMENTUM · 训练记录',
          title: '每一次完成都算数',
          subtitle: '只记录真实返回的训练结果，用清晰数据回看你的节奏。',
          icon: Icons.insights_rounded,
          footer: Row(
            children: [
              Expanded(
                child: ProductMetric(
                  value: '${controller.completedCount}',
                  label: '累计完成',
                  color: AppTheme.primary,
                  background: const Color(0xFFEAF0EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ProductMetric(
                  value: '${controller.streak}',
                  label: '连续天数',
                  color: AppTheme.ai,
                  background: const Color(0xFFECEBFF),
                ),
              ),
            ],
          ),
        ),
        if (controller.connection.allowDataUpload) ...[
          const SizedBox(height: 14),
          _WeeklyReview(controller: controller),
        ],
        const SizedBox(height: 20),
        ProductSectionTitle(
          title: '训练明细',
          eyebrow: 'SESSION LOG',
          action: ProductBadge(label: '${items.length} 条'),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.directions_run_rounded,
            title: '还没有训练记录',
            body: '完成一次训练后，这里会展示时间、次数、时长和结果来源。',
          )
        else
          for (var index = 0; index < items.length; index++) ...[
            _SessionCard(
              result: items[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SessionSummaryPage(
                    result: items[index],
                    controller: controller,
                  ),
                ),
              ),
            ),
            if (index != items.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _WeeklyReview extends StatefulWidget {
  const _WeeklyReview({required this.controller});

  final ProductController controller;

  @override
  State<_WeeklyReview> createState() => _WeeklyReviewState();
}

class _WeeklyReviewState extends State<_WeeklyReview> {
  bool loading = false;

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      await widget.controller.refreshWeeklyProgress();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final progress = controller.weeklyProgress;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFECEBFF),
        borderRadius: AppRadius.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCD9FF),
                  borderRadius: AppRadius.small,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppTheme.ai,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI 本周回顾', style: AppText.cardTitle),
                    Text('基于已同步的真实训练记录', style: AppText.caption),
                  ],
                ),
              ),
              TextButton(
                onPressed: loading ? null : refresh,
                child: Text(
                  loading
                      ? '生成中…'
                      : progress == null
                      ? '生成'
                      : '刷新',
                ),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 8),
            const Text('正在整理本周真实训练记录…', style: AppText.caption),
          ] else if (progress != null) ...[
            const SizedBox(height: 12),
            Text(progress['summary'] as String, style: AppText.body),
            const SizedBox(height: 6),
            Text(progress['next_step'] as String, style: AppText.caption),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              controller.coachError == null
                  ? '生成后会在这里显示本周节奏与下一步建议。'
                  : '暂时无法生成回顾，可稍后重试。',
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.result, required this.onTap});

  final SessionResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = result.finishedAt.toLocal();
    final exercise = result.exercises.firstOrNull;
    final statusColor = result.isCompleted
        ? AppTheme.primary
        : result.status == 'cancelled'
        ? AppTheme.neutral
        : AppTheme.mockBadge;
    final source = result.source == 'mock'
        ? '模拟'
        : result.source == 'real'
        ? '真实'
        : '未确认';
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.large,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.medium,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 21,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${date.month} 月', style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusTitle(result.status), style: AppText.cardTitle),
                    const SizedBox(height: 5),
                    Text(
                      '${_exerciseName(exercise?.exerciseId)} · '
                      '${exercise?.completedSets ?? 0} 组 · '
                      '${exercise?.completedReps ?? 0} 次 · '
                      '${result.durationSeconds} 秒',
                      style: AppText.caption,
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        SemanticStatusBadge(status: result.status),
                        SourceBadge(
                          label: source,
                          kind: result.source == 'real'
                              ? SourceBadgeKind.real
                              : result.source == 'mock'
                              ? SourceBadgeKind.mock
                              : SourceBadgeKind.unknown,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 17),
            ],
          ),
        ),
      ),
    );
  }

  String _exerciseName(String? id) => switch (id) {
    'squat' => '徒手深蹲',
    'push_up' => '俯卧撑',
    null => '未记录动作',
    _ => id,
  };

  String _statusTitle(String status) => switch (status) {
    'completed' => '训练已完成',
    'cancelled' => '训练已取消',
    _ => '训练已中断',
  };
}
