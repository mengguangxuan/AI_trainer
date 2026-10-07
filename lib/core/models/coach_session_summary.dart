class CoachSessionSummary {
  const CoachSessionSummary({
    required this.sessionId,
    required this.agentSummary,
    required this.source,
    required this.nextPlanChanged,
    required this.facts,
    required this.limitations,
  });

  final String sessionId;
  final String agentSummary;
  final String source;
  final bool nextPlanChanged;
  final Map<String, dynamic> facts;
  final List<String> limitations;

  factory CoachSessionSummary.fromJson(Map<String, dynamic> json) =>
      CoachSessionSummary(
        sessionId: json['session_id'] as String,
        agentSummary: json['agent_summary'] as String,
        source: json['source'] as String? ?? 'agent',
        nextPlanChanged: json['next_plan_changed'] as bool? ?? false,
        facts: json['facts'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['facts'] as Map<String, dynamic>)
            : const {},
        limitations: (json['limitations'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  Map<String, Object?> toJson() => {
    'session_id': sessionId,
    'agent_summary': agentSummary,
    'source': source,
    'next_plan_changed': nextPlanChanged,
    'facts': facts,
    'limitations': limitations,
  };
}
