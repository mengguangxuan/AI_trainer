import '../../../core/models/nutrition_advice.dart';
import '../../../core/models/session_result.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/user_profile_snapshot.dart';
import 'coach_repository.dart';

/// Deliberately labelled template output. Replace with Agent B's repository.
class TemplateCoachRepository implements CoachRepository {
  @override
  Future<TrainingPlan> fetchPlan(
      UserProfileSnapshot profile, List<SessionResult> history) async =>
      plan(profile, history);

  @override
  Future<NutritionAdvice> fetchNutrition(UserProfileSnapshot profile) async =>
      nutrition(profile);

  TrainingPlan plan(UserProfileSnapshot profile, List<SessionResult> history) {
    final lastCompleted = history.where((e) => e.isCompleted).firstOrNull;
    if (profile.hasCurrentDiscomfort) {
      return const TrainingPlan(
        planId: 'template_pause_v1',
        stageName: '暂停安排',
        headline: '先处理当前不适',
        reason: '你标记了当前身体不适。这里暂不自动安排训练；请根据实际情况寻求专业意见。',
        item: null,
        source: 'template',
      );
    }
    final beginner = profile.experience == '新手';
    final reps = beginner ? 6 : 8;
    final followUp = lastCompleted != null;
    return TrainingPlan(
      planId: 'template_squat_v1',
      stageName: '适应期示例',
      headline: followUp ? '继续练习：深蹲' : '今天从深蹲开始',
      reason: followUp
          ? '已记录上一次训练。下一次继续用同一动作练习，并关注上次的反馈。'
          : '根据所选目标“${profile.goal}”和运动基础，先展示一项无需器械的练习。',
      item: TrainingPlanItem(
        id: 'template_squat_01',
        title: '徒手深蹲',
        targetSets: 1,
        targetReps: reps,
        restSeconds: 45,
      ),
      source: 'template',
    );
  }

  NutritionAdvice nutrition(UserProfileSnapshot profile) {
    final preference = profile.dietPreference;
    if (preference == '素食') {
      return const NutritionAdvice(
        title: '食堂搭配示例',
        body: '可选择豆制品或鸡蛋（如符合你的饮食方式），搭配主食和蔬菜；点餐时再次核对配料。',
        source: 'template',
      );
    }
    if (preference == '有过敏或特殊限制') {
      return const NutritionAdvice(
        title: '先核对食物限制',
        body: '目前没有采集具体过敏原，无法生成针对性的食物替换。请先核对配料，并向有资质的专业人员咨询。',
        source: 'template',
      );
    }
    return const NutritionAdvice(
      title: '训练日饮食示例',
      body: '在食堂可选择一份有蛋白质来源的主菜，搭配主食和蔬菜；根据饥饿感与日常习惯调整。',
      source: 'template',
    );
  }
}
