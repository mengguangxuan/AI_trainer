import 'package:flutter/material.dart';

import '../../../core/models/coach_memory.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/product_controller.dart';

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
        children: const [
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: AppTheme.neutral),
                  SizedBox(height: AppSpacing.gapSmall),
                  Text('聊天与记忆尚未启用', style: AppText.cardTitle),
                  SizedBox(height: 6),
                  Text(
                    '请先在右上角 Agent 连接中确认服务地址，并允许 Agent 使用训练数据。',
                    style: AppText.body,
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
              ? const _EmptyChat()
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
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              controller.chatError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8A5A12)),
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                      hintText: '询问训练安排、恢复或一般饮食问题',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: '发送',
                  onPressed: controller.chatSending ? null : send,
                  icon: controller.chatSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
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
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: ListTile(
      leading: const Icon(Icons.psychology_alt_outlined),
      title: const Text('AI 私教'),
      subtitle: Text(
        memory == null
            ? loading
                  ? '正在读取记忆…'
                  : '尚未读取 Agent 记忆'
            : '${memory?.chatMessages.length ?? 0} 条消息 · '
                  '${memory?.rememberedRecordCount ?? 0} 条训练/建议记忆',
      ),
      onTap: onOpen,
      trailing: IconButton(
        tooltip: '刷新记忆',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
      ),
    ),
  );
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 42, color: AppTheme.neutral),
          SizedBox(height: 12),
          Text('开始和私教聊聊', style: AppText.cardTitle),
          SizedBox(height: 6),
          Text(
            '可询问训练安排和一般饮食建议。最近真实训练事实会随本次消息发送，不上传视频或骨架。',
            textAlign: TextAlign.center,
            style: AppText.caption,
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
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: user ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message.content, style: AppText.body),
      ),
    );
  }
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
                  const Text(
                    '这里只展示 Agent 服务端保存的有限档案与聊天记录，不包含视频、图片或骨架。',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  _MemorySection(
                    title: '同步档案',
                    children:
                        memory?.profile.entries
                            .map(
                              (entry) => ListTile(
                                dense: true,
                                title: Text(entry.key),
                                trailing: Text('${entry.value}'),
                              ),
                            )
                            .toList() ??
                        const [ListTile(title: Text('暂无同步档案'))],
                  ),
                  const SizedBox(height: AppSpacing.gap),
                  _MemorySection(
                    title: '记忆概览',
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text('聊天消息'),
                        trailing: Text('${memory?.chatMessages.length ?? 0}'),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('训练/计划/饮食记录'),
                        trailing: Text('${memory?.rememberedRecordCount ?? 0}'),
                      ),
                    ],
                  ),
                  if (controller.chatError != null) ...[
                    const SizedBox(height: AppSpacing.gap),
                    Text(
                      controller.chatError!,
                      style: const TextStyle(color: Color(0xFF9A6B1F)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.gap),
                  OutlinedButton.icon(
                    onPressed:
                        controller.chatMemoryLoading || controller.chatSending
                        ? null
                        : clear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除全部 Agent 聊天与记忆'),
                  ),
                ],
              ),
      );
    },
  );
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(title, style: AppText.cardTitle),
          ),
          ...children,
        ],
      ),
    ),
  );
}
