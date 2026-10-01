class TrainingLaunchArgs {
  const TrainingLaunchArgs({
    required this.planItemId,
    required this.trainingMode,
    required this.exercises,
    this.coachName = 'AI 私教',
  });

  final String? planItemId;
  final String trainingMode; // planned / free
  final List<LaunchExercise> exercises;
  final String coachName;

  Map<String, Object?> toJson() => {
        'schema_version': 1,
        'plan_item_id': planItemId,
        'training_mode': trainingMode,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'coach_name': coachName,
      };
}

class LaunchExercise {
  const LaunchExercise({
    required this.exerciseId,
    required this.targetSets,
    required this.targetReps,
    required this.restSeconds,
  });

  final String exerciseId;
  final int targetSets;
  final int targetReps;
  final int restSeconds;

  Map<String, Object?> toJson() => {
        'exercise_id': exerciseId,
        'target_sets': targetSets,
        'target_reps': targetReps,
        'rest_seconds': restSeconds,
      };
}
