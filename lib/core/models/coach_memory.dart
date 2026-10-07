class CoachChatMessage {
  const CoachChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  factory CoachChatMessage.fromJson(Map<String, dynamic> json) =>
      CoachChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
      );
}

class CoachMemorySnapshot {
  const CoachMemorySnapshot({
    required this.userId,
    required this.profile,
    required this.profileUpdatedAt,
    required this.recentReports,
    required this.recentRecords,
    required this.chatMessages,
    required this.recordCounts,
    required this.storage,
  });

  final String userId;
  final Map<String, dynamic> profile;
  final String? profileUpdatedAt;
  final List<Map<String, dynamic>> recentReports;
  final List<Map<String, dynamic>> recentRecords;
  final List<CoachChatMessage> chatMessages;
  final Map<String, int> recordCounts;
  final String storage;

  int get rememberedRecordCount => recentReports.length + recentRecords.length;

  factory CoachMemorySnapshot.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(Object? value) =>
        (value as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);

    try {
      final counts = <String, int>{};
      final rawCounts = json['record_counts'];
      if (rawCounts is Map) {
        for (final entry in rawCounts.entries) {
          if (entry.key is String && entry.value is num) {
            counts[entry.key as String] = (entry.value as num).toInt();
          }
        }
      }
      return CoachMemorySnapshot(
        userId: json['user_id'] as String,
        profile: json['profile'] is Map
            ? Map<String, dynamic>.from(json['profile'] as Map)
            : const {},
        profileUpdatedAt: json['profile_updated_at'] as String?,
        recentReports: maps(json['recent_reports']),
        recentRecords: maps(json['recent_records']),
        chatMessages: maps(
          json['chat_messages'],
        ).map(CoachChatMessage.fromJson).toList(growable: false),
        recordCounts: counts,
        storage: json['storage'] as String? ?? 'unknown',
      );
    } on TypeError {
      throw const FormatException('invalid coach memory response');
    }
  }
}

class CoachChatReply {
  const CoachChatReply({
    required this.reply,
    required this.sourceIds,
    required this.sources,
    required this.memoryUsed,
    required this.modelCalled,
  });

  final String reply;
  final List<String> sourceIds;
  final List<String> sources;
  final List<String> memoryUsed;
  final bool modelCalled;

  factory CoachChatReply.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) =>
        (value as List<dynamic>? ?? const []).whereType<String>().toList();

    try {
      final agent = json['agent'];
      return CoachChatReply(
        reply: json['reply'] as String,
        sourceIds: strings(json['source_ids']),
        sources: strings(json['sources']),
        memoryUsed: strings(json['memory_used']),
        modelCalled: agent is Map && agent['model_called'] == true,
      );
    } on TypeError {
      throw const FormatException('invalid coach chat response');
    }
  }
}
