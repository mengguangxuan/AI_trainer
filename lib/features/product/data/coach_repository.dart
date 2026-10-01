import '../../../core/models/nutrition_advice.dart';
import '../../../core/models/session_result.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/user_profile_snapshot.dart';

/// Agent B's future implementation supplies structured data through this API.
abstract class CoachRepository {
  Future<TrainingPlan> fetchPlan(
    UserProfileSnapshot profile,
    List<SessionResult> history,
  );

  Future<NutritionAdvice> fetchNutrition(UserProfileSnapshot profile);
}
