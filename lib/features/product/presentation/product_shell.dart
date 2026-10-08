import 'package:flutter/material.dart';

import '../../../core/models/session_result.dart';
import '../../../core/models/training_launch_args.dart';
import '../../../core/theme/app_theme.dart';
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
      showDragHandle: false,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFFE5F0E9),
                    child: const Icon(
                      Icons.directions_run_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('选择自由训练动作', style: AppText.cardTitle),
                        SizedBox(height: 2),
                        Text('FREE TRAINING · 单动作体验', style: AppText.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('每次选择一个动作，本次建议目标 $targetReps 次。'),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    color: const Color(0xFFEAF0EB),
                    child: const Icon(
                      Icons.accessibility_new,
                      color: AppTheme.primary,
                    ),
                  ),
                  title: const Text('徒手深蹲'),
                  subtitle: Text('1 组 × $targetReps 次'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(sheetContext, 'squat'),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    color: const Color(0xFFECEBFF),
                    child: const Icon(Icons.fitness_center, color: AppTheme.ai),
                  ),
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
          onOpenCoach: () => setState(() => tab = 4),
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
          toolbarHeight: 64,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(gradient: AppTheme.heroGradient),
                child: const Icon(
                  Icons.motion_photos_on_rounded,
                  size: 20,
                  color: AppTheme.energy,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('动姿智护'),
                  Text(
                    'AI FITNESS COACH',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Color(0xFF708078),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE4EAE5))),
            boxShadow: [
              BoxShadow(
                color: Color(0x100B2E24),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (index) => setState(() => tab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '首页',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_month_rounded),
                label: '计划',
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_outlined),
                selectedIcon: Icon(Icons.restaurant_rounded),
                label: '饮食',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_rounded),
                selectedIcon: Icon(Icons.history_toggle_off_rounded),
                label: '记录',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: '教练',
              ),
            ],
          ),
        ),
      );
    },
  );
}
