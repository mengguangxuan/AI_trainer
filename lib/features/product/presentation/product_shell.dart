import 'package:flutter/material.dart';

import '../../../core/models/session_result.dart';
import '../../training_contract/training_gateway.dart';
import '../domain/product_controller.dart';
import 'history_page.dart';
import 'home_page.dart';
import 'nutrition_page.dart';
import 'onboarding_page.dart';
import 'plan_page.dart';
import 'session_summary_page.dart';

/// D's single integration point. C may mount this inside the team's App shell.
class ProductShell extends StatefulWidget {
  const ProductShell({super.key, required this.controller, required this.training});

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

  Future<void> startTraining() async {
    final item = widget.controller.plan?.item;
    if (busy || item == null) return;
    setState(() => busy = true);
    try {
      final SessionResult? result =
          await widget.training.start(context, item.launchArgs());
      if (result == null) return; // e.g. system back without an outcome
      var saved = true;
      try {
        await widget.controller.recordSession(result);
      } catch (_) {
        saved = false;
      }
      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('训练已结束，但保存记录失败；请勿将它当作已同步的历史。'),
        ));
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SessionSummaryPage(result: result, saved: saved),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('训练入口暂时无法打开，请稍后重试。'),
        ));
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
            HomePage(controller: widget.controller, onStart: startTraining,
                onEditProfile: () => setState(() => editing = true), busy: busy),
            PlanPage(controller: widget.controller, onStart: startTraining, busy: busy),
            NutritionPage(controller: widget.controller),
            HistoryPage(controller: widget.controller),
          ];
          return Scaffold(
            appBar: AppBar(title: const Text('动姿智护 · 产品原型')),
            body: SafeArea(child: screens[tab]),
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (index) => setState(() => tab = index),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
                NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: '计划'),
                NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: '饮食'),
                NavigationDestination(icon: Icon(Icons.history), label: '记录'),
              ],
            ),
          );
        },
      );
}
