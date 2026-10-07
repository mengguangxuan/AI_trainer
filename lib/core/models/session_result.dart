class SessionResult {
  const SessionResult({
    required this.sessionId,
    required this.status,
    required this.finishedAt,
    this.finishedAtIso,
    required this.durationSeconds,
    required this.exercises,
    this.agentSummary,
    this.nextPlanChanged = false,
    this.source = 'unknown',
  });

  final String sessionId;
  final String status; // completed / cancelled / interrupted
  final DateTime finishedAt;
  // Preserve the native timestamp spelling for stable idempotency across time zones.
  final String? finishedAtIso;
  final int durationSeconds;
  final List<SessionExercise> exercises;
  final String? agentSummary;
  final bool nextPlanChanged;
  final String source; // real / mock / unknown

  bool get isCompleted => status == 'completed';

  Map<String, Object?> toJson() => {
    'schema_version': 1,
    'session_id': sessionId,
    'status': status,
    'finished_at': finishedAtIso ?? finishedAt.toIso8601String(),
    'duration_seconds': durationSeconds,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'agent_summary': agentSummary,
    'next_plan_changed': nextPlanChanged,
    'source': source,
  };

  factory SessionResult.fromJson(Map<String, dynamic> json) => SessionResult(
    sessionId: json['session_id'] as String,
    status: json['status'] as String? ?? 'interrupted',
    finishedAt:
        DateTime.tryParse(json['finished_at'] as String? ?? '') ??
        DateTime.now(),
    finishedAtIso: json['finished_at'] as String?,
    durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    exercises: (json['exercises'] as List<dynamic>? ?? const [])
        .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
    agentSummary: json['agent_summary'] as String?,
    nextPlanChanged: json['next_plan_changed'] as bool? ?? false,
    source: json['source'] as String? ?? 'unknown',
  );
}

class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    required this.completedSets,
    required this.completedReps,
    this.qualityTrend,
    this.mainErrorCode,
  });

  final String exerciseId;
  final int completedSets;
  final int completedReps;
  final String? qualityTrend;
  final String? mainErrorCode;

  Map<String, Object?> toJson() => {
    'exercise_id': exerciseId,
    'completed_sets': completedSets,
    'completed_reps': completedReps,
    'quality_trend': qualityTrend,
    'main_error_code': mainErrorCode,
  };

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      SessionExercise(
        exerciseId: json['exercise_id'] as String,
        completedSets: (json['completed_sets'] as num?)?.toInt() ?? 0,
        completedReps: (json['completed_reps'] as num?)?.toInt() ?? 0,
        qualityTrend: json['quality_trend'] as String?,
        mainErrorCode: json['main_error_code'] as String?,
      );
}
