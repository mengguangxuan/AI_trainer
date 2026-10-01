import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/models/session_result.dart';
import '../../core/models/training_launch_args.dart';
import 'training_gateway.dart';

/// Dart half of the frozen Android bridge.
///
/// The native method opens the full-screen training Activity and completes
/// this call with a measured v1 session map when that Activity exits.
class NativeTrainingGateway implements TrainingGateway {
  NativeTrainingGateway({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('ai_fitness/training_v1');

  final MethodChannel _channel;

  @override
  Future<SessionResult?> start(
    BuildContext context,
    TrainingLaunchArgs args,
  ) async {
    if (args.exercises.length != 1 ||
        !const ['squat', 'push_up'].contains(args.exercises.single.exerciseId) ||
        args.exercises.single.targetSets != 1) {
      throw const FormatException(
          'Training v1 requires one squat/push_up exercise and one set');
    }
    final Object? reply = await _channel.invokeMethod<Object?>(
      'startTraining',
      args.toJson(),
    );
    if (reply == null) {
      throw const FormatException('Training bridge returned no v1 result');
    }
    if (reply is! Map) {
      throw const FormatException('Training bridge returned a non-map result');
    }
    final Map<String, dynamic> json;
    try {
      json = Map<String, dynamic>.from(reply);
    } on TypeError {
      throw const FormatException('Training bridge returned non-string keys');
    }
    if (json['schema_version'] != 1 ||
        json['session_id'] is! String ||
        (json['session_id'] as String).isEmpty ||
        !const ['completed', 'cancelled', 'interrupted']
            .contains(json['status']) ||
        json['finished_at'] is! String ||
        DateTime.tryParse(json['finished_at'] as String) == null ||
        json['duration_seconds'] is! int ||
        (json['duration_seconds'] as int) < 0 ||
        json['exercises'] is! List ||
        json['agent_summary'] != null ||
        json['next_plan_changed'] != false ||
        json['source'] != 'real') {
      throw const FormatException('Training bridge returned invalid v1 data');
    }
    final rawExercises = json['exercises'] as List;
    if (json['status'] == 'completed' && rawExercises.length != 1) {
      throw const FormatException('Completed training must have one exercise result');
    }
    if (rawExercises.length > 1) {
      throw const FormatException('Training v1 returned multiple exercises');
    }
    // StandardMessageCodec decodes nested Kotlin maps as Map<Object?, Object?>.
    // Convert every level before SessionResult.fromJson casts exercise maps.
    final normalizedExercises = <Map<String, dynamic>>[];
    final expectedExercise = args.exercises.single;
    for (final exercise in rawExercises) {
      if (exercise is! Map) {
        throw const FormatException('Exercise result is not a map');
      }
      final Map<String, dynamic> normalized;
      try {
        normalized = Map<String, dynamic>.from(exercise);
      } on TypeError {
        throw const FormatException('Exercise result has non-string keys');
      }
      if (normalized['exercise_id'] is! String ||
          normalized['completed_sets'] is! int ||
          normalized['completed_reps'] is! int ||
          (normalized['completed_sets'] as int) < 0 ||
          (normalized['completed_reps'] as int) < 0 ||
          normalized['exercise_id'] != expectedExercise.exerciseId ||
          normalized['quality_trend'] != null ||
          normalized['main_error_code'] != null) {
        throw const FormatException('Exercise result is missing valid counts');
      }
      final expectedSets = json['status'] == 'completed' &&
              (normalized['completed_reps'] as int) >= expectedExercise.targetReps
          ? 1
          : 0;
      if (normalized['completed_sets'] != expectedSets) {
        throw const FormatException('Exercise result has invalid completed sets');
      }
      normalizedExercises.add(normalized);
    }
    json['exercises'] = normalizedExercises;
    return SessionResult.fromJson(json);
  }
}
