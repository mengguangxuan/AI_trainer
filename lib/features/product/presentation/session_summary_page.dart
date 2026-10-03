import 'package:flutter/material.dart';

import '../../../core/models/session_result.dart';
import '../../../core/theme/app_theme.dart';

class SessionSummaryPage extends StatelessWidget {
  const SessionSummaryPage({
    super.key,
    required this.result,
    this.saved = true,
    this.targetReps,
  });

  final SessionResult result;
  final bool saved;

  /// 本组目标次数（由计划入口传入）。仅用于展示"是否达到目标"，
  /// 不改变完成状态的判定——判定以桥返回的 status 为准。
  final int? targetReps;

  /// 错误码文案与 docs/contracts/training_bridge_v1_frozen.md 保持一致；
  /// 未知码只显示代码本身，不推断健康结论。
  String _errorText(String? code) => switch (code) {
    'squat.depth_shallow' => '下蹲幅度不足（膝角未达标）',
    'squat.torso_lean' => '躯干前倾过多，请保持抬头挺胸',
    'push_up.depth_shallow' => '俯卧撑下压幅度不足（肘角未达标）',
    'push_up.body_line_bent' => '身体线条下塌，请保持肩髋踝一条直线',
    'camera.landmarks_missing' => '未能完整捕捉身体关键点，请调整站位',
    null => '没有可用的动作错误记录',
    _ => '收到反馈代码：$code（暂无中文解释）',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completed = result.isCompleted;
    final exercise = result.exercises.firstOrNull;
    final reps = exercise?.completedReps ?? 0;
    // cancelled/interrupted 只显示进度，不判断为“达到目标”。
    final reachedTarget =
        completed && targetReps != null && reps >= targetReps!;

    return Scaffold(
      appBar: AppBar(title: const Text('训练总结', style: AppText.pageTitle)),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            // —— 头部主视觉：状态 + 实际次数（大数字）+ 目标进度 ——
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: completed
                      ? scheme.primary.withValues(alpha: 0.5)
                      : const Color(0xFFE0E4E1),
                  width: completed ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          completed ? Icons.check_circle : Icons.pause_circle,
                          size: 22,
                          color: completed ? scheme.primary : AppTheme.neutral,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            !saved
                                ? '训练已结束，但记录未保存'
                                : completed
                                ? '本次训练已完成'
                                : '本次训练未完成',
                            style: AppText.cardTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$reps',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                            color: completed
                                ? scheme.primary
                                : AppTheme.neutral,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('次', style: AppText.body),
                        ),
                        const Spacer(),
                        if (targetReps != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '目标 $targetReps 次',
                              style: AppText.caption,
                            ),
                          ),
                      ],
                    ),
                    if (targetReps != null) ...[
                      const SizedBox(height: AppSpacing.gapSmall),
                      _Progress(
                        reps: reps,
                        target: targetReps!,
                        active: completed ? scheme.primary : AppTheme.neutral,
                      ),
                      const SizedBox(height: AppSpacing.gapSmall),
                    ],
                    if (completed && targetReps != null)
                      Text(
                        reachedTarget ? '已达到本组目标' : '提前结束：未达到目标',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: reachedTarget
                              ? scheme.primary
                              : AppTheme.neutral,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // —— 模拟来源标注：紧跟结果卡，颜色区分，不可误读 ——
            if (result.source == 'mock')
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.gapSmall),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.mockBadge.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.mockBadge.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.science_outlined,
                        size: 14,
                        color: AppTheme.mockBadge,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '模拟训练结果 · 次数与反馈不来自摄像头识别',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.mockBadge,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (result.source != 'real')
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.gapSmall),
                child: Text('结果来源未确认', style: AppText.caption),
              ),

            const SizedBox(height: AppSpacing.gap),

            // —— 次要数据行：时长 / 组数 / 纠错 ——
            Card(
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Column(
                  children: [
                    _kv('训练时长', '${result.durationSeconds} 秒'),
                    const Divider(height: AppSpacing.gap),
                    _kv('完成组数', '${exercise?.completedSets ?? 0} 组'),
                    const Divider(height: AppSpacing.gap),
                    _kv('动作纠错', _errorText(exercise?.mainErrorCode)),
                  ],
                ),
              ),
            ),

            // —— Agent 反馈（如有） ——
            if (result.agentSummary != null) ...[
              const SizedBox(height: AppSpacing.gap),
              Card(
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('教练反馈', style: AppText.cardTitle),
                      const SizedBox(height: AppSpacing.gapSmall),
                      Text(result.agentSummary!, style: AppText.body),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.gap),
            Text(
              result.nextPlanChanged && completed
                  ? '下一次安排将参考这次已完成的训练。'
                  : '本次没有确认的下一次计划调整。',
              style: AppText.caption,
            ),
            const SizedBox(height: AppSpacing.gap),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String key, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 72, child: Text(key, style: AppText.caption)),
      Expanded(child: Text(value, style: AppText.body)),
    ],
  );
}

/// 目标进度条：reps/target，超过按满格显示。
class _Progress extends StatelessWidget {
  const _Progress({
    required this.reps,
    required this.target,
    required this.active,
  });

  final int reps;
  final int target;
  final Color active;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : (reps / target).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 6,
        backgroundColor: const Color(0xFFE8ECE9),
        valueColor: AlwaysStoppedAnimation(active),
      ),
    );
  }
}
