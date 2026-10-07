import '../../../core/models/agent_connection.dart';
import '../../../core/models/coach_memory.dart';
import '../../../core/models/session_result.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/user_profile_snapshot.dart';

abstract class CoachChatRepository {
  void configure(AgentConnection connection);

  Future<void> syncProfile(String installationId, UserProfileSnapshot profile);

  Future<CoachMemorySnapshot> fetchMemory(String installationId);

  Future<CoachChatReply> sendMessage({
    required String installationId,
    required String message,
    required UserProfileSnapshot profile,
    required List<SessionResult> history,
    TrainingPlan? currentPlan,
  });

  Future<void> deleteMemory(String installationId);

  void close();
}
