import 'package:flutter/material.dart';

import '../../../core/models/user_profile_snapshot.dart';
import '../../../core/theme/app_theme.dart';
import 'product_ui.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.onSave,
    this.initial,
    this.onCancel,
  });

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
      await widget.onSave(
        UserProfileSnapshot(
          goal: goal,
          experience: experience,
          daysPerWeek: days,
          minutesPerSession: minutes,
          hasEquipment: equipment,
          hasCurrentDiscomfort: discomfort,
          dietPreference: diet,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试。')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initial == null ? '建立训练档案' : '修改训练档案'),
      leading: widget.onCancel == null
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onCancel,
            ),
    ),
    body: SafeArea(
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          ProductHero(
            eyebrow: 'PERSONAL SETUP · 个人档案',
            title: widget.initial == null ? '先了解你的节奏' : '调整你的训练节奏',
            subtitle: '用几项必要信息安排可执行的训练路径，之后随时可以修改。',
            icon: Icons.tune_rounded,
            footer: const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ProductBadge(label: '约 1 分钟', icon: Icons.timer_outlined),
                ProductBadge(label: '可随时修改', icon: Icons.edit_outlined),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const ProductSectionTitle(title: '训练偏好', eyebrow: 'TRAINING PROFILE'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  _choice('训练目标', goal, [
                    '建立运动习惯',
                    '提升力量',
                    '改善体能',
                  ], (v) => setState(() => goal = v)),
                  _choice('运动基础', experience, [
                    '新手',
                    '有规律运动',
                  ], (v) => setState(() => experience = v)),
                  _choice(
                    '每周训练',
                    days,
                    [1, 2, 3, 4],
                    (v) => setState(() => days = v),
                    suffix: ' 天',
                  ),
                  _choice(
                    '单次时间',
                    minutes,
                    [10, 15, 20, 30],
                    (v) => setState(() => minutes = v),
                    suffix: ' 分钟',
                    bottomPadding: 0,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const ProductSectionTitle(title: '训练条件', eyebrow: 'READINESS'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.fitness_center_rounded,
                    color: AppTheme.primary,
                  ),
                  title: const Text('有基础训练器械'),
                  subtitle: const Text('用于调整可选择的训练动作'),
                  value: equipment,
                  onChanged: (v) => setState(() => equipment = v),
                ),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.health_and_safety_outlined,
                    color: Color(0xFFB65F42),
                  ),
                  title: const Text('目前有身体不适'),
                  subtitle: const Text('开启后暂不自动提供训练入口'),
                  value: discomfort,
                  onChanged: (v) => setState(() => discomfort = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const ProductSectionTitle(title: '饮食偏好', eyebrow: 'DAILY FUEL'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: _choice(
                '偏好或限制',
                diet,
                ['无特别偏好', '素食', '有过敏或特殊限制'],
                (v) => setState(() => diet = v),
                bottomPadding: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const ProductNotice(
            icon: Icons.info_outline_rounded,
            title: '建议范围',
            body: '计划和饮食用于一般健身体验，不提供医疗诊断或治疗。',
          ),
          const SizedBox(height: 16),
          PrimaryActionButton(
            label: '保存并查看今日安排',
            icon: Icons.arrow_forward_rounded,
            loading: saving,
            onPressed: saving ? null : save,
          ),
        ],
      ),
    ),
  );

  Widget _choice<T>(
    String label,
    T value,
    List<T> values,
    ValueChanged<T> onChange, {
    String suffix = '',
    double bottomPadding = 12,
  }) => Padding(
    padding: EdgeInsets.only(bottom: bottomPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.caption.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (option) => ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: ChoiceChip(
                    label: Text('$option$suffix'),
                    selected: option == value,
                    showCheckmark: false,
                    selectedColor: const Color(0xFFDFF2E8),
                    side: BorderSide(
                      color: option == value
                          ? AppTheme.primary
                          : const Color(0xFFDCE5DF),
                    ),
                    onSelected: (_) => onChange(option),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}
