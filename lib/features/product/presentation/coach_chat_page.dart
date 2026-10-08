import 'package:flutter/material.dart';

import '../../../core/models/coach_memory.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/product_controller.dart';
import 'product_ui.dart';

class CoachChatPage extends StatefulWidget {
  const CoachChatPage({super.key, required this.controller});

  final ProductController controller;

  @override
  State<CoachChatPage> createState() => _CoachChatPageState();
}

class _CoachChatPageState extends State<CoachChatPage> {
  final message = TextEditingController();
  final scroll = ScrollController();
  bool requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!requested) {
      requested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.refreshChatMemory();
      });
    }
  }

  @override
  void dispose() {
    message.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = message.text.trim();
    if (text.isEmpty) return;
    final sent = await widget.controller.sendChatMessage(text);
    if (!mounted || !sent) return;
    message.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.connection.allowDataUpload) {
      return ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: AppTheme.coachGradient),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoachAvatar(size: 54, locked: true),
                SizedBox(height: 24),
                Text(
                  '聊天与记忆尚未启用',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '请先在右上角 Agent 连接中确认服务地址，并允许 Agent 使用训练数据。',
                  style: TextStyle(
                    color: Color(0xFFE5E5FF),
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PrivacyPill(
                      icon: Icons.lock_outline_rounded,
                      text: '默认关闭',
                    ),
                    _PrivacyPill(
                      icon: Icons.videocam_off_outlined,
                      text: '不上传视频',
                    ),
                    _PrivacyPill(
                      icon: Icons.delete_outline_rounded,
                      text: '记忆可删除',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('由你决定分享什么', style: AppText.cardTitle),
                        SizedBox(height: 5),
                        Text(
                          '开启后仅同步有限画像、当前计划和最近真实训练事实。',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final memory = controller.coachMemory;
    final messages = memory?.chatMessages ?? const <CoachChatMessage>[];
    return Column(
      children: [
        _MemoryHeader(
          memory: memory,
          loading: controller.chatMemoryLoading,
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CoachMemoryPage(controller: controller),
            ),
          ),
          onRefresh: controller.chatMemoryLoading
              ? null
              : controller.refreshChatMemory,
        ),
        if (controller.chatMemoryLoading) const LinearProgressIndicator(),
        Expanded(
          child: messages.isEmpty
              ? _EmptyChat(
                  onPrompt: (prompt) {
                    message.text = prompt;
                    message.selection = TextSelection.collapsed(
                      offset: message.text.length,
                    );
                  },
                )
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _MessageBubble(message: messages[index]),
                ),
        ),
        if (controller.chatError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF4E5)),
            child: Text(
              controller.chatError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A12)),
            ),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: AppTheme.canvas,
              border: Border(top: BorderSide(color: Color(0xFFE3E9E5))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: message,
                    enabled: !controller.chatSending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: '问问训练、恢复或饮食…',
                      counterText: '',
                      prefixIcon: Icon(
                        Icons.add_circle_outline_rounded,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 50,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppTheme.ai),
                    tooltip: '发送',
                    onPressed: controller.chatSending ? null : send,
                    icon: controller.chatSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemoryHeader extends StatelessWidget {
  const _MemoryHeader({
    required this.memory,
    required this.loading,
    required this.onOpen,
    required this.onRefresh,
  });

  final CoachMemorySnapshot? memory;
  final bool loading;
  final VoidCallback onOpen;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        gradient: AppTheme.coachGradient,
        boxShadow: const [
          BoxShadow(
            color: Color(0x24686CF6),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const _CoachAvatar(size: 48),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'AI 私教',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 7),
                          _OnlineBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        memory == null
                            ? loading
                                  ? '正在读取你的有限记忆…'
                                  : '点击查看 Agent 记忆'
                            : '记得 ${memory?.rememberedRecordCount ?? 0} 条训练信息 · '
                                  '${memory?.chatMessages.length ?? 0} 条消息',
                        style: const TextStyle(
                          color: Color(0xFFE4E4FF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '刷新记忆',
                  onPressed: onRefresh,
                  color: Colors.white,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onPrompt});

  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.waving_hand_rounded,
            size: 36,
            color: Color(0xFFE2A225),
          ),
          const SizedBox(height: 12),
          const Text('今天想聊点什么？', style: AppText.sectionTitle),
          const SizedBox(height: 6),
          const Text(
            '我会参考你的目标、当前计划和最近真实训练，给出一般健身建议。',
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
          const SizedBox(height: 20),
          _PromptButton(
            icon: Icons.calendar_month_rounded,
            label: '今天适合练什么？',
            onTap: () => onPrompt('今天适合练什么？'),
          ),
          const SizedBox(height: 8),
          _PromptButton(
            icon: Icons.history_rounded,
            label: '根据最近训练给我建议',
            onTap: () => onPrompt('请根据我最近的训练给出下一次建议。'),
          ),
          const SizedBox(height: 8),
          _PromptButton(
            icon: Icons.restaurant_menu_rounded,
            label: '训练日饮食怎么安排？',
            onTap: () => onPrompt('训练日的一般饮食应该怎么安排？'),
          ),
        ],
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final CoachChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!user) ...[
            const _CoachAvatar(size: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: user ? AppTheme.primary : Colors.white,
                border: user
                    ? null
                    : Border.all(color: const Color(0xFFE2E8E4)),
              ),
              child: Text(
                message.content,
                style: AppText.body.copyWith(
                  color: user ? Colors.white : AppTheme.ink,
                ),
              ),
            ),
          ),
          if (user) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFDDEBE3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 18,
                color: AppTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachAvatar extends StatelessWidget {
  const _CoachAvatar({required this.size, this.locked = false});

  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0x24FFFFFF),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0x52FFFFFF)),
    ),
    child: Icon(
      locked ? Icons.lock_outline_rounded : Icons.auto_awesome_rounded,
      color: Colors.white,
      size: size * 0.46,
    ),
  );
}

class _PrivacyPill extends StatelessWidget {
  const _PrivacyPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: const Color(0x20FFFFFF)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: const Color(0x26FFFFFF)),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 3, backgroundColor: AppTheme.energy),
        SizedBox(width: 4),
        Text(
          '在线',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _PromptButton extends StatelessWidget {
  const _PromptButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E6E2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.ai),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
    ),
  );
}

class CoachMemoryPage extends StatefulWidget {
  const CoachMemoryPage({super.key, required this.controller});

  final ProductController controller;

  @override
  State<CoachMemoryPage> createState() => _CoachMemoryPageState();
}

class _CoachMemoryPageState extends State<CoachMemoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.refreshChatMemory();
    });
  }

  Future<void> clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除 Agent 记忆？'),
        content: const Text('将删除服务端保存的档案、聊天和建议记忆；APP 本地训练记录不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.deleteChatMemory();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final memory = controller.coachMemory;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Agent 记忆'),
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: controller.chatMemoryLoading
                  ? null
                  : controller.refreshChatMemory,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: controller.chatMemoryLoading && memory == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: AppSpacing.pagePadding,
                children: [
                  ProductHero(
                    eyebrow: 'AGENT MEMORY · 有限记忆',
                    title: '你决定 Agent 记住什么',
                    subtitle: '这里仅展示服务端保存的有限档案与聊天记录，不包含视频、图片或骨架。',
                    icon: Icons.memory_rounded,
                    gradient: AppTheme.coachGradient,
                    footer: Row(
                      children: [
                        Expanded(
                          child: ProductMetric(
                            value: '${memory?.chatMessages.length ?? 0}',
                            label: '聊天消息',
                            color: Colors.white,
                            background: const Color(0x1FFFFFFF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ProductMetric(
                            value: '${memory?.rememberedRecordCount ?? 0}',
                            label: '训练记忆',
                            color: Colors.white,
                            background: const Color(0x1FFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const ProductSectionTitle(title: '同步档案', eyebrow: 'PROFILE'),
                  const SizedBox(height: 10),
                  _MemorySection(
                    children:
                        memory?.profile.entries
                            .map(
                              (entry) => ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 19,
                                  color: AppTheme.primary,
                                ),
                                title: Text(_profileLabel(entry.key)),
                                trailing: Text(
                                  _profileValue('${entry.value}'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                            .toList() ??
                        const [ListTile(title: Text('暂无同步档案'))],
                  ),
                  const SizedBox(height: 12),
                  const ProductNotice(
                    icon: Icons.shield_outlined,
                    title: '有限、透明、可删除',
                    body: 'APP 本地原始训练记录不在这里；删除 Agent 记忆不会删除本地训练历史。',
                    color: AppTheme.ai,
                    background: Color(0xFFECEBFF),
                  ),
                  if (controller.chatError != null) ...[
                    const SizedBox(height: AppSpacing.gap),
                    ProductNotice(
                      icon: Icons.error_outline_rounded,
                      title: '读取失败',
                      body: controller.chatError!,
                      color: AppTheme.mockBadge,
                      background: const Color(0xFFFFF3D8),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.gap),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          controller.chatMemoryLoading || controller.chatSending
                          ? null
                          : clear,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除全部 Agent 聊天与记忆'),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );
}

String _profileLabel(String value) => switch (value) {
  'goal' => '训练目标',
  'experience' => '运动基础',
  'days_per_week' => '每周训练',
  'minutes_per_session' => '单次时间',
  'equipment' => '可用器械',
  'dietary_preferences' => '饮食偏好',
  _ => value,
};

String _profileValue(String value) => switch (value) {
  'general_fitness' => '综合体能',
  'strength' => '力量提升',
  'fat_loss' => '减脂',
  'mobility' => '灵活性',
  'endurance' => '耐力',
  'beginner' => '新手',
  'intermediate' => '进阶',
  'advanced' => '高级',
  _ => value,
};
