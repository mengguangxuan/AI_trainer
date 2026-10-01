import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_d_starter/core/models/session_result.dart';
import 'package:ai_fitness_d_starter/core/models/user_profile_snapshot.dart';
import 'package:ai_fitness_d_starter/features/product/data/template_coach_repository.dart';

void main() {
  const profile = UserProfileSnapshot(
    goal: '建立运动习惯',
    experience: '新手',
    daysPerWeek: 2,
    minutesPerSession: 15,
    hasEquipment: false,
    hasCurrentDiscomfort: false,
    dietPreference: '无特别偏好',
  );

  test('current discomfort blocks the automatic training entry', () {
    final plan = TemplateCoachRepository().plan(
      UserProfileSnapshot.fromJson({
        ...profile.toJson(),
        'has_current_discomfort': true,
      }),
      [],
    );
    expect(plan.item, isNull);
  });

  test('cancelled session cannot trigger the completed-session follow-up', () {
    final cancelled = SessionResult(
      sessionId: 'cancel_1',
      status: 'cancelled',
      finishedAt: DateTime(2026, 10, 1),
      durationSeconds: 5,
      exercises: const [],
      source: 'mock',
    );
    final plan = TemplateCoachRepository().plan(profile, [cancelled]);
    expect(plan.headline, '今天从深蹲开始');
  });

  test('exercise data remains absent when a cancelled result is decoded', () {
    final result = SessionResult.fromJson({
      'session_id': 'cancel_2',
      'status': 'cancelled',
      'finished_at': '2026-10-01T12:00:00',
      'duration_seconds': 5,
      'exercises': [],
    });
    expect(result.isCompleted, isFalse);
    expect(result.exercises, isEmpty);
  });
}
