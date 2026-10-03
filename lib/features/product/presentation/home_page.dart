import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/product_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onStart,
    required this.onEditProfile,
    required this.busy,
  });

  final ProductController controller;
  final Future<void> Function() onStart;
  final VoidCallback onEditProfile;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final plan = controller.plan!;
    final nutrition = controller.nutrition!;
    final planSource = plan.source == 'agent' ? 'Agent' : '本地模板';
    final nutritionSource = nutrition.source == 'agent' ? 'Agent' : '本地模板';
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        // 顶部问候行：一行内解决，不再用大标题
        Row(
          children: [
            Expanded(
              child: Text(
                '你好 · ${profile.goal}',
                style: AppText.cardTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onEditProfile,
              tooltip: '修改档案',
              icon: const Icon(Icons.person_outline, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gap),

        // —— 主视觉：今日训练卡 ——
        if (plan.item != null)
          _TodayTrainingCard(
            stage: plan.stageName,
            title: plan.item!.title,
            sets: plan.item!.targetSets,
            reps: plan.item!.targetReps,
            rest: plan.item!.restSeconds,
            busy: busy,
            onStart: onStart,
          ),

        // 暂停状态（有当前不适）：独立的醒目提示卡
        if (plan.item == null)
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.pause_circle_outline,
                    size: 32,
                    color: AppTheme.neutral,
                  ),
                  SizedBox(height: AppSpacing.gapSmall),
                  Text('先处理当前不适', style: AppText.cardTitle),
                  SizedBox(height: 4),
                  Text('你标记了当前身体不适，暂不自动安排训练。可修改档案或查看记录。', style: AppText.body),
                ],
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.gap),

        // —— 次要：统计行（紧凑单行卡） ——
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _stat(
                  context,
                  Icons.check_circle_outline,
                  '${controller.completedCount}',
                  '完成',
                ),
                const SizedBox(width: 24),
                _stat(
                  context,
                  Icons.local_fire_department_outlined,
                  '${controller.streak}',
                  '连续天',
                ),
                const Spacer(),
                Text(
                  controller.usingFallback ? '本地回退' : '计划：$planSource',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.gap),

        // —— 次要：饮食提示（弱化为单行摘要） ——
        Card(
          child: ListTile(
            contentPadding: AppSpacing.cardPadding,
            leading: const Icon(Icons.restaurant_outlined, size: 20),
            title: Text(
              nutrition.title,
              style: AppText.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              nutrition.body,
              style: AppText.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
          ),
        ),
        const SizedBox(height: AppSpacing.gapSmall),
        Text(
          controller.usingFallback
              ? '服务不可用：当前显示本地示例模板；训练来源见总结页。'
              : '计划来源：$planSource；饮食来源：$nutritionSource；训练来源见总结页。',
          style: AppText.caption,
        ),
      ],
    );
  }

  Widget _stat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppText.caption),
      ],
    );
  }
}

/// 今日训练主卡：动作、组×次、休息直接展示，开始按钮嵌在卡内。
class _TodayTrainingCard extends StatelessWidget {
  const _TodayTrainingCard({
    required this.stage,
    required this.title,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.busy,
    required this.onStart,
  });

  final String stage;
  final String title;
  final int sets;
  final int reps;
  final int rest;
  final bool busy;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      // 主视觉：主色细描边 + 轻微阴影，从一堆白卡中突出
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stage,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.fitness_center,
                  size: 18,
                  color: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gapSmall + 4),
            Text('今日训练', style: AppText.caption),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.gapSmall),
            Row(
              children: [
                _pill('$sets 组'),
                const SizedBox(width: 8),
                _pill('$reps 次'),
                const SizedBox(width: 8),
                _pill('休息 ${rest}s'),
              ],
            ),
            const SizedBox(height: AppSpacing.gap),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onStart,
                icon: const Icon(Icons.play_arrow, size: 20),
                label: Text(
                  busy ? '正在打开…' : '开始今日训练',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF3F0),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF3D4A44),
      ),
    ),
  );
}
