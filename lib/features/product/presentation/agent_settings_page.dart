import 'package:flutter/material.dart';

import '../../../core/models/agent_connection.dart';
import '../domain/product_controller.dart';

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
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: address,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: '服务地址',
            hintText: 'http://127.0.0.1:8000/api/app/v1/',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: token,
          obscureText: true,
          autocorrect: false,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: '开发访问凭据',
            helperText: '不是模型 API Key；仅用于受控联调',
          ),
        ),
        const SizedBox(height: 20),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('允许 Agent 使用训练数据'),
          subtitle: const Text(
            '发送目标、训练频率、饮食偏好及最多 30 条真实训练记录。不发送视频、骨架或身体不适信息。总结在服务端保留最多 30 天。',
          ),
          value: consent,
          onChanged: busy ? null : (v) => setState(() => consent = v),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
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
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await widget.controller.saveConnection(value);
                      return consent ? '配置已保存，正在刷新教练建议。' : '配置已保存，当前使用本地模式。';
                    }),
              icon: const Icon(Icons.save_outlined),
              label: const Text('保存配置'),
            ),
          ],
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: LinearProgressIndicator(),
          ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(status!),
          ),
        const Divider(height: 40),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.delete_outline),
          title: const Text('清除教练总结'),
          onTap: busy ? null : clearSummaries,
        ),
      ],
    ),
  );
}
