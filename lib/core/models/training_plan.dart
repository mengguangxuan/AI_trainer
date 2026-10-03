import 'training_launch_args.dart';

class TrainingPlan {
  const TrainingPlan({
    required this.planId,
    required this.stageName,
    required this.headline,
    required this.reason,
    required this.item,
    required this.source,
  });

  final String planId;
  final String stageName;
  final String headline;
  final String reason;
  final TrainingPlanItem? item;
  final String source; // template / agent
}

class TrainingPlanItem {
  const TrainingPlanItem({
    required this.id,
    required this.exerciseId,
    required this.title,
    required this.targetSets,
    required this.targetReps,
    required this.restSeconds,
  });

  final String id;
  final String exerciseId;
  final String title;
  final int targetSets;
  final int targetReps;
  final int restSeconds;

  TrainingLaunchArgs launchArgs() => TrainingLaunchArgs(
    planItemId: id,
    trainingMode: 'planned',
    exercises: [
      LaunchExercise(
        exerciseId: exerciseId,
        targetSets: targetSets,
        targetReps: targetReps,
        restSeconds: restSeconds,
      ),
    ],
  );
}
