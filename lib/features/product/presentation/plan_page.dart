import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/product_controller.dart';
import 'product_ui.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({
    super.key,
    required this.controller,
    required this.onStart,
    required this.busy,
  });

  final ProductController controller;
  final Future<void> Function() onStart;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final plan = controller.plan!;
    final item = plan.item;
    final sourceLabel = plan.source == 'agent'
        ? 'AI 生成'
        : controller.planUsingFallback
        ? '本地模板'
        : '服务规则';

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        ProductHero(
          eyebrow: 'YOUR PROGRAM · 阶段计划',
          title: plan.stageName,
          subtitle: plan.headline,
          icon: Icons.calendar_month_rounded,
          footer: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ProductBadge(
                label: sourceLabel,
                icon: plan.source == 'agent'
                    ? Icons.auto_awesome_rounded
                    : Icons.layers_outlined,
                foreground: Colors.white,
                background: const Color(0x24FFFFFF),
              ),
              ProductBadge(
                label: item == null ? '恢复日' : '可开始训练',
                icon: item == null
                    ? Icons.self_improvement_rounded
                    : Icons.play_arrow_rounded,
                foreground: AppTheme.ink,
                background: AppTheme.energy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ProductSectionTitle(
          title: item == null ? '今日恢复' : '今日安排',
          eyebrow: item == null ? 'RECOVERY' : 'TODAY SESSION',
        ),
        const SizedBox(height: 10),
        if (item == null)
          ProductNotice(
            icon: Icons.self_improvement_rounded,
            title: plan.headline,
            body: plan.reason,
          )
        else
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        color: const Color(0xFFE5F0E9),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Text(item.title, style: AppText.cardTitle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ProductMetric(
                          value: '${item.targetSets}',
                          label: '目标组数',
                          background: const Color(0xFFF0F4F1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ProductMetric(
                          value: '${item.targetReps}',
                          label: '每组次数',
                          background: const Color(0xFFF0F4F1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ProductMetric(
                          value: '${item.restSeconds}',
                          label: '休息秒数',
                          background: const Color(0xFFF0F4F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('安排说明', style: AppText.cardTitle.copyWith(fontSize: 14)),
                  const SizedBox(height: 5),
                  Text(plan.reason, style: AppText.body),
                ],
              ),
            ),
          ),
        if (item != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.energy,
                foregroundColor: AppTheme.ink,
              ),
              onPressed: busy ? null : onStart,
              icon: Icon(
                busy ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
              ),
              label: Text(busy ? '正在打开…' : '开始这项训练'),
            ),
          ),
        ],
        const SizedBox(height: 18),
        ProductNotice(
          icon: Icons.tune_rounded,
          title: '循序渐进',
          body: plan.source == 'agent'
              ? 'Agent 训练建议不会仅依据单次完成次数自动加量。'
              : controller.planUsingFallback
              ? '当前使用本地模板，连接 Agent 后可刷新个性化安排。'
              : '当前计划由服务端规则生成，请根据实际感受完成。',
          color: AppTheme.ai,
          background: const Color(0xFFECEBFF),
        ),
      ],
    );
  }
}
