import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/product_controller.dart';
import 'product_ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onStart,
    required this.onStartFree,
    required this.onEditProfile,
    required this.busy,
    this.onOpenCoach,
  });

  final ProductController controller;
  final Future<void> Function() onStart;
  final Future<void> Function() onStartFree;
  final VoidCallback onEditProfile;
  final VoidCallback? onOpenCoach;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final plan = controller.plan!;
    final nutrition = controller.nutrition!;
    final planSource = plan.source == 'agent'
        ? 'AI 生成'
        : controller.planUsingFallback
        ? '本地模板'
        : '服务规则';
    final nutritionSource = nutrition.source == 'agent'
        ? 'AI 生成'
        : controller.nutritionUsingFallback
        ? '本地模板'
        : '服务规则';
    final weeklyCompleted = _completedDaysThisWeek();

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        _Greeting(
          goal: profile.goal,
          connected: controller.connection.allowDataUpload,
          onEditProfile: onEditProfile,
        ),
        const SizedBox(height: 18),
        if (plan.item != null)
          _TodayTrainingCard(
            stage: plan.stageName,
            source: planSource,
            title: plan.item!.title,
            sets: plan.item!.targetSets,
            reps: plan.item!.targetReps,
            rest: plan.item!.restSeconds,
            busy: busy,
            onStart: onStart,
          )
        else
          _RestCard(
            title: profile.hasCurrentDiscomfort ? '先处理当前不适' : plan.headline,
            body: profile.hasCurrentDiscomfort
                ? '你标记了当前身体不适，暂不提供训练入口。可修改档案或查看记录。'
                : plan.reason,
            discomfort: profile.hasCurrentDiscomfort,
          ),
        const SizedBox(height: AppSpacing.gap),
        _WeeklyProgressCard(
          completedDays: weeklyCompleted,
          goalDays: profile.daysPerWeek,
          totalSessions: controller.completedCount,
          streak: controller.streak,
        ),
        if (!profile.hasCurrentDiscomfort) ...[
          const SizedBox(height: 20),
          const ProductSectionTitle(title: '快捷开始', eyebrow: 'MOVE YOUR WAY'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.directions_run_rounded,
                  title: '自由训练',
                  subtitle: '自选动作',
                  color: AppTheme.primary,
                  onTap: busy ? null : onStartFree,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickAction(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI 私教',
                  subtitle: '问问教练',
                  color: AppTheme.ai,
                  onTap: onOpenCoach,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const ProductSectionTitle(title: '今日补给', eyebrow: 'DAILY FUEL'),
        const SizedBox(height: 10),
        _NutritionCard(
          title: nutrition.title,
          body: nutrition.body,
          source: nutritionSource,
        ),
        const SizedBox(height: 10),
        _SourceNotice(
          localOnly: !controller.connection.allowDataUpload,
          fallback: controller.usingFallback,
          error: controller.coachError,
        ),
      ],
    );
  }

  int _completedDaysThisWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: today.weekday - 1));
    final tomorrow = today.add(const Duration(days: 1));
    final days = <String>{};
    for (final session in controller.history) {
      final finished = session.finishedAt.toLocal();
      if (!session.isCompleted ||
          finished.isBefore(start) ||
          !finished.isBefore(tomorrow)) {
        continue;
      }
      days.add('${finished.year}-${finished.month}-${finished.day}');
    }
    return days.length;
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.goal,
    required this.connected,
    required this.onEditProfile,
  });

  final String goal;
  final bool connected;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingText(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF718078),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '为「$goal」动起来',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditProfile,
            tooltip: '修改档案',
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: connected ? const Color(0xFFE9E9FF) : const Color(0xFFE9EFEA),
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              connected ? Icons.auto_awesome_rounded : Icons.smartphone_rounded,
              size: 14,
              color: connected ? AppTheme.ai : AppTheme.primary,
            ),
            const SizedBox(width: 5),
            Text(
              connected ? 'AI 在线' : '本地模式',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: connected ? AppTheme.ai : AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 11) return '早上好，今天也稳稳开始';
    if (hour < 14) return '中午好，记得适当活动';
    if (hour < 19) return '下午好，保持你的节奏';
    return '晚上好，量力而行';
  }
}

class _TodayTrainingCard extends StatelessWidget {
  const _TodayTrainingCard({
    required this.stage,
    required this.source,
    required this.title,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.busy,
    required this.onStart,
  });

  final String stage;
  final String source;
  final String title;
  final int sets;
  final int reps;
  final int rest;
  final bool busy;
  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: AppRadius.hero,
    child: DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
      child: Stack(
        children: [
          const Positioned(
            right: -28,
            top: -24,
            child: _DecorativeRing(size: 132),
          ),
          const Positioned(
            right: 36,
            bottom: 72,
            child: _DecorativeRing(size: 46),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _DarkBadge(label: stage.toUpperCase()),
                    const SizedBox(width: 8),
                    _DarkBadge(
                      label: source,
                      icon: source == 'AI 生成'
                          ? Icons.auto_awesome_rounded
                          : Icons.layers_outlined,
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.fitness_center_rounded,
                      color: AppTheme.energy,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const Text(
                  'TODAY · 今日训练',
                  style: TextStyle(
                    color: Color(0xFFBFD2C9),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricPill(value: '$sets', label: '组'),
                    _MetricPill(value: '$reps', label: '次'),
                    _MetricPill(value: '$rest', label: '秒休息'),
                  ],
                ),
                const SizedBox(height: 22),
                PrimaryActionButton(
                  label: '开始今日训练',
                  icon: Icons.play_arrow_rounded,
                  loading: busy,
                  onPressed: busy ? null : onStart,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DecorativeRing extends StatelessWidget {
  const _DecorativeRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0x24FFFFFF), width: 18),
    ),
  );
}

class _DarkBadge extends StatelessWidget {
  const _DarkBadge({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0x1FFFFFFF),
      borderRadius: AppRadius.pill,
      border: Border.all(color: const Color(0x24FFFFFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: const BoxDecoration(
      color: Color(0x18FFFFFF),
      borderRadius: AppRadius.medium,
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      style: const TextStyle(color: Colors.white),
    ),
  );
}

class _RestCard extends StatelessWidget {
  const _RestCard({
    required this.title,
    required this.body,
    required this.discomfort,
  });

  final String title;
  final String body;
  final bool discomfort;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.cardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: discomfort
                  ? const Color(0xFFFFEEE8)
                  : const Color(0xFFE8F3EC),
              borderRadius: AppRadius.medium,
            ),
            child: Icon(
              discomfort
                  ? Icons.health_and_safety_outlined
                  : Icons.self_improvement_rounded,
              color: discomfort ? const Color(0xFFB65F42) : AppTheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                const SizedBox(height: 5),
                Text(body, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({
    required this.completedDays,
    required this.goalDays,
    required this.totalSessions,
    required this.streak,
  });

  final int completedDays;
  final int goalDays;
  final int totalSessions;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final progress = goalDays == 0
        ? 0.0
        : (completedDays / goalDays).clamp(0.0, 1.0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 7,
                    color: Color(0xFFE5ECE7),
                  ),
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    color: AppTheme.energy,
                  ),
                  Text(
                    '$completedDays/$goalDays',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本周训练目标', style: AppText.cardTitle),
                  SizedBox(height: 3),
                  Text('按完成训练日统计', style: AppText.caption),
                ],
              ),
            ),
            _CompactStat(value: '$totalSessions', label: '总完成'),
            const SizedBox(width: 14),
            _CompactStat(value: '$streak', label: '连续天'),
          ],
        ),
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      Text(label, style: AppText.caption),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.large,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: AppRadius.medium,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    ),
  );
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({
    required this.title,
    required this.body,
    required this.source,
  });

  final String title;
  final String body;
  final String source;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3D8),
              borderRadius: AppRadius.medium,
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: Color(0xFFAA7017),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppText.cardTitle)),
                    SourceBadge(
                      label: source,
                      kind: source == 'AI 生成'
                          ? SourceBadgeKind.agent
                          : source == '本地模板'
                          ? SourceBadgeKind.local
                          : SourceBadgeKind.service,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: AppText.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF77847D)),
        ],
      ),
    ),
  );
}

class _SourceNotice extends StatelessWidget {
  const _SourceNotice({
    required this.localOnly,
    required this.fallback,
    required this.error,
  });

  final bool localOnly;
  final bool fallback;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final color = error != null
        ? AppTheme.error
        : fallback
        ? AppTheme.mockBadge
        : AppTheme.primary;
    final background = error != null
        ? const Color(0xFFFFEEE8)
        : fallback
        ? const Color(0xFFFFF8E9)
        : const Color(0xFFEAF0EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.medium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error != null
                ? Icons.error_outline_rounded
                : fallback
                ? Icons.layers_outlined
                : Icons.verified_user_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error != null
                  ? 'Agent 状态：$error'
                  : localOnly
                  ? '本地模式 · 未发送训练数据'
                  : fallback
                  ? '服务暂不可用，当前展示本地模板。'
                  : 'AI 建议已连接；训练事实仍以端侧记录为准。',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}
