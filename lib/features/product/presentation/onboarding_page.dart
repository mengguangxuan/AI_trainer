import 'package:flutter/material.dart';

import '../../../core/models/user_profile_snapshot.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onSave, this.initial, this.onCancel});

  final UserProfileSnapshot? initial;
  final Future<void> Function(UserProfileSnapshot) onSave;
  final VoidCallback? onCancel;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late String goal = widget.initial?.goal ?? '建立运动习惯';
  late String experience = widget.initial?.experience ?? '新手';
  late int days = widget.initial?.daysPerWeek ?? 2;
  late int minutes = widget.initial?.minutesPerSession ?? 15;
  late bool equipment = widget.initial?.hasEquipment ?? false;
  late bool discomfort = widget.initial?.hasCurrentDiscomfort ?? false;
  late String diet = widget.initial?.dietPreference ?? '无特别偏好';
  bool saving = false;

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.onSave(UserProfileSnapshot(
        goal: goal,
        experience: experience,
        daysPerWeek: days,
        minutesPerSession: minutes,
        hasEquipment: equipment,
        hasCurrentDiscomfort: discomfort,
        dietPreference: diet,
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试。')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.initial == null ? '建立你的训练档案' : '修改训练档案'),
          leading: widget.onCancel == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onCancel,
                ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('只需几项信息，先安排一条可体验的训练路径。',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              _choice('训练目标', goal,
                  ['建立运动习惯', '提升力量', '改善体能'], (v) => setState(() => goal = v)),
              _choice('运动基础', experience, ['新手', '有规律运动'],
                  (v) => setState(() => experience = v)),
              _choice('每周可训练', days, [1, 2, 3, 4],
                  (v) => setState(() => days = v), suffix: '天'),
              _choice('每次可用时间', minutes, [10, 15, 20, 30],
                  (v) => setState(() => minutes = v), suffix: '分钟'),
              SwitchListTile(
                title: const Text('有基础训练器械'),
                value: equipment,
                onChanged: (v) => setState(() => equipment = v),
              ),
              SwitchListTile(
                title: const Text('目前有身体不适'),
                subtitle: const Text('勾选后暂不自动开始训练'),
                value: discomfort,
                onChanged: (v) => setState(() => discomfort = v),
              ),
              _choice('饮食偏好', diet, ['无特别偏好', '素食', '有过敏或特殊限制'],
                  (v) => setState(() => diet = v)),
              const SizedBox(height: 12),
              const Text('当前版本的计划和饮食为本地示例模板；不提供医疗诊断。'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? '保存中…' : '保存并查看今日安排'),
              ),
            ],
          ),
        ),
      );

  Widget _choice<T>(String label, T value, List<T> values, ValueChanged<T> onChange,
      {String suffix = ''}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: values
              .map((v) => DropdownMenuItem(value: v, child: Text('$v$suffix')))
              .toList(),
          onChanged: (v) {
            if (v != null) onChange(v);
          },
        ),
      );
}
