import '../../../core/models/nutrition_advice.dart';
import '../../../core/models/coach_session_summary.dart';
import '../../../core/models/session_result.dart';
import '../../../core/models/privacy_flow.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/user_profile_snapshot.dart';

/// Product-facing coach contract; optional features keep local mode usable.
abstract class CoachRepository {
  Future<TrainingPlan> fetchPlan(
    UserProfileSnapshot profile,
    List<SessionResult> history,
  );

  Future<NutritionAdvice> fetchNutrition(UserProfileSnapshot profile);

  Future<Map<String, dynamic>?> fetchWeeklyProgress({
    required UserProfileSnapshot profile,
    required List<SessionResult> history,
  }) async => null;

  Future<CoachSessionSummary?> fetchSummary({
    required String installationId,
    required UserProfileSnapshot profile,
    required SessionResult session,
    List<SessionResult> history = const [],
  }) async => null;

  /// Optional edge-token analysis. Local/template repositories intentionally
  /// return null so the privacy flow remains an additive capability.
  Future<PrivacyFlowResult?> submitPrivacyFlow(
    PrivacyFlowRequest request,
  ) async => null;
}
