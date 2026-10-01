import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/models/session_result.dart';
import '../../core/models/training_launch_args.dart';
import 'training_gateway.dart';

/// Dart half of the proposed Android bridge. C implements the native method.
///
/// Keep the mock gateway active until C has supplied a native Activity that
/// accepts the launch map and returns a session map on the same method call.
class NativeTrainingGateway implements TrainingGateway {
  NativeTrainingGateway({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('ai_fitness/training_v1');

  final MethodChannel _channel;

  @override
  Future<SessionResult?> start(
    BuildContext context,
    TrainingLaunchArgs args,
  ) async {
    final Object? reply = await _channel.invokeMethod<Object?>(
      'startTraining',
      args.toJson(),
    );
    // A native back action without a completed session changes no D history.
    if (reply == null) return null;
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
        json['source'] != 'real') {
      throw const FormatException('Training bridge returned invalid v1 data');
    }
    if (json['status'] == 'completed' && (json['exercises'] as List).isEmpty) {
      throw const FormatException('Completed training has no exercise result');
    }
    // StandardMessageCodec decodes nested Kotlin maps as Map<Object?, Object?>.
    // Convert every level before SessionResult.fromJson casts exercise maps.
    final normalizedExercises = <Map<String, dynamic>>[];
    for (final exercise in json['exercises'] as List) {
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
          (normalized['completed_reps'] as int) < 0) {
        throw const FormatException('Exercise result is missing valid counts');
      }
      normalizedExercises.add(normalized);
    }
    json['exercises'] = normalizedExercises;
    return SessionResult.fromJson(json);
  }
}
