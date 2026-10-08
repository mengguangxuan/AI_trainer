import 'package:flutter/material.dart';

import '../../../core/models/agent_connection.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/product_controller.dart';
import 'product_ui.dart';

class AgentSettingsPage extends StatefulWidget {
  const AgentSettingsPage({super.key, required this.controller});

  final ProductController controller;

  @override
  State<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

class _AgentSettingsPageState extends State<AgentSettingsPage> {
  late final TextEditingController address;
  late final TextEditingController token;
  late bool consent;
  bool busy = false;
  String? status;

  @override
  void initState() {
    super.initState();
    final value = widget.controller.connection;
    address = TextEditingController(text: value.baseUrl);
    token = TextEditingController(text: value.devToken);
    consent = value.allowDataUpload;
  }

  @override
  void dispose() {
    address.dispose();
    token.dispose();
    super.dispose();
  }

  AgentConnection get value => AgentConnection(
    baseUrl: address.text.trim(),
    devToken: token.text.trim(),
    allowDataUpload: consent,
  );

  Future<void> run(Future<String> Function() action) async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => status = message);
    } catch (error) {
      if (mounted) setState(() => status = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> clearSummaries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除教练总结？'),
        content: const Text('清除本机与当前服务的总结缓存，原始训练记录保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await run(() async {
        await widget.controller.deleteSummaries();
        return '总结缓存已清除，原始记录未改动。';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Agent 连接')),
    body: SafeArea(
      child: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          ProductHero(
            eyebrow: 'AGENT CONNECTION · 服务配置',
            title: consent ? 'AI 教练已授权连接' : '连接你的 AI 教练',
            subtitle: '模型密钥保留在服务端；APP 这里只保存服务地址和开发访问凭据。',
            icon: Icons.hub_rounded,
            gradient: AppTheme.coachGradient,
            footer: ProductBadge(
              label: consent ? '允许有限数据同步' : '当前为本地模式',
              icon: consent
                  ? Icons.cloud_done_outlined
                  : Icons.smartphone_rounded,
              foreground: Colors.white,
              background: const Color(0x24FFFFFF),
            ),
          ),
          const SizedBox(height: 20),
          const ProductSectionTitle(title: '服务配置', eyebrow: 'ENDPOINT'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                children: [
                  TextField(
                    controller: address,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: '服务地址',
                      hintText: 'http://127.0.0.1:8000/api/app/v1/',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: token,
                    obscureText: true,
                    autocorrect: false,
                    enabled: !busy,
                    decoration: const InputDecoration(
                      labelText: '开发访问凭据',
                      helperText: '不是模型 API Key；仅用于受控联调',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const ProductSectionTitle(title: '数据授权', eyebrow: 'PRIVACY FIRST'),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              secondary: Container(
                width: 42,
                height: 42,
                color: const Color(0xFFECEBFF),
                child: const Icon(Icons.shield_outlined, color: AppTheme.ai),
              ),
              title: const Text('允许 Agent 使用训练数据'),
              subtitle: const Text(
                '仅发送目标、训练频率、饮食偏好和最多 30 条真实训练记录；不发送视频、骨架或身体不适信息。',
              ),
              value: consent,
              onChanged: busy ? null : (v) => setState(() => consent = v),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          final capabilities = await widget.controller
                              .checkConnection(value);
                          return capabilities['model_configured'] == false
                              ? '连接成功 · 协议兼容。服务端尚未配置模型，当前使用模板。'
                              : '连接成功 · App Coach v1 兼容。模型实际可用性以生成结果为准。';
                        }),
                  icon: const Icon(Icons.network_check),
                  label: const Text('检测连接'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await widget.controller.saveConnection(value);
                          return consent
                              ? '配置已保存，正在刷新教练建议。'
                              : '配置已保存，当前使用本地模式。';
                        }),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存配置'),
                ),
              ),
            ],
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: LinearProgressIndicator(),
            ),
          if (status != null) ...[
            const SizedBox(height: 12),
            ProductNotice(
              icon: Icons.info_outline_rounded,
              title: '连接状态',
              body: status!,
              color: AppTheme.ai,
              background: const Color(0xFFECEBFF),
            ),
          ],
          const SizedBox(height: 20),
          const ProductSectionTitle(title: '数据管理', eyebrow: 'YOUR CONTROL'),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 42,
                height: 42,
                color: const Color(0xFFFFEEE8),
                child: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB65F42),
                ),
              ),
              title: const Text('清除教练总结'),
              subtitle: const Text('保留原始训练记录，仅清除总结缓存'),
              trailing: const Icon(Icons.arrow_forward_rounded),
              onTap: busy ? null : clearSummaries,
            ),
          ),
        ],
      ),
    ),
  );
}
