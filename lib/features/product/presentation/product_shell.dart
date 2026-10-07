import 'package:flutter/material.dart';

import '../../../core/models/session_result.dart';
import '../../../core/models/training_launch_args.dart';
import '../../training_contract/training_gateway.dart';
import '../domain/product_controller.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'nutrition_page.dart';
import 'onboarding_page.dart';
import 'plan_page.dart';
import 'session_summary_page.dart';
import 'agent_settings_page.dart';
import 'coach_chat_page.dart';

/// D's single integration point. C may mount this inside the team's App shell.
class ProductShell extends StatefulWidget {
  const ProductShell({
    super.key,
    required this.controller,
    required this.training,
  });

  final ProductController controller;
  final TrainingGateway training;

  @override
  State<ProductShell> createState() => _ProductShellState();
}

class _ProductShellState extends State<ProductShell> {
  int tab = 0;
  bool editing = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  Future<void> startPlannedTraining() async {
    final item = widget.controller.plan?.item;
    if (busy || item == null) return;
    await _runTraining(item.launchArgs(), targetReps: item.targetReps);
  }

  Future<void> startFreeTraining() async {
    final profile = widget.controller.profile;
    if (busy || profile == null || profile.hasCurrentDiscomfort) return;

    final targetReps = profile.experience == '新手' ? 6 : 8;
    final exerciseId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择自由训练动作',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('每次选择一个动作，本次建议目标 $targetReps 次。'),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.accessibility_new),
                  title: const Text('徒手深蹲'),
                  subtitle: Text('1 组 × $targetReps 次'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheetContext, 'squat'),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: const Text('俯卧撑'),
                  subtitle: Text('1 组 × $targetReps 次'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheetContext, 'push_up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (exerciseId == null || !mounted) return;

    await _runTraining(
      TrainingLaunchArgs(
        planItemId: null,
        trainingMode: 'free',
        exercises: [
          LaunchExercise(
            exerciseId: exerciseId,
            targetSets: 1,
            targetReps: targetReps,
            restSeconds: 0,
          ),
        ],
      ),
      targetReps: targetReps,
    );
  }

  Future<void> _runTraining(
    TrainingLaunchArgs args, {
    required int targetReps,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final SessionResult? result = await widget.training.start(context, args);
      // training_bridge_v1_frozen.md §4：正常退出都返回明确状态；
      // null 仅在桥未实现/通道异常时出现，此时不更新任何历史。
      if (result == null) return;
      var saved = true;
      try {
        await widget.controller.recordSession(result);
      } catch (_) {
        saved = false;
      }
      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('训练已结束，但保存记录失败；请勿将它当作已同步的历史。')),
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SessionSummaryPage(
            result: result,
            saved: saved,
            targetReps: targetReps,
            controller: widget.controller,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('训练入口暂时无法打开，请稍后重试。')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (widget.controller.loading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final profile = widget.controller.profile;
      if (profile == null || editing) {
        return OnboardingPage(
          initial: editing ? profile : null,
          onCancel: editing ? () => setState(() => editing = false) : null,
          onSave: (value) async {
            await widget.controller.saveProfile(value);
            if (mounted) setState(() => editing = false);
          },
        );
      }
      final screens = [
        HomePage(
          controller: widget.controller,
          onStart: startPlannedTraining,
          onStartFree: startFreeTraining,
          onEditProfile: () => setState(() => editing = true),
          busy: busy,
        ),
        PlanPage(
          controller: widget.controller,
          onStart: startPlannedTraining,
          busy: busy,
        ),
        NutritionPage(controller: widget.controller),
        HistoryPage(controller: widget.controller),
        CoachChatPage(controller: widget.controller),
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text('动姿智护'),
          actions: [
            IconButton(
              tooltip: 'Agent 连接',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AgentSettingsPage(controller: widget.controller),
                ),
              ),
            ),
            IconButton(
              tooltip: '刷新教练建议',
              icon: const Icon(Icons.refresh),
              onPressed: widget.controller.refreshing
                  ? null
                  : widget.controller.refreshCoach,
            ),
          ],
        ),
        body: SafeArea(child: screens[tab]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) => setState(() => tab = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              label: '计划',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              label: '饮食',
            ),
            NavigationDestination(icon: Icon(Icons.history), label: '记录'),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              label: '教练',
            ),
          ],
        ),
      );
    },
  );
}
