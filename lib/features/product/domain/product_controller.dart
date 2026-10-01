import 'package:flutter/foundation.dart';

import '../../../core/models/nutrition_advice.dart';
import '../../../core/models/session_result.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/user_profile_snapshot.dart';
import '../data/coach_repository.dart';
import '../data/local_product_repository.dart';
import '../data/template_coach_repository.dart';

class ProductController extends ChangeNotifier {
  ProductController(this._local, this._coach);

  final LocalProductRepository _local;
  final CoachRepository _coach;
  final TemplateCoachRepository _fallback = TemplateCoachRepository();
  UserProfileSnapshot? profile;
  List<SessionResult> history = [];
  bool loading = true;
  bool usingFallback = false;

  TrainingPlan? plan;
  NutritionAdvice? nutrition;

  Future<void> _refreshCoach() async {
    final current = profile;
    if (current == null) return;
    try {
      final nextPlan = await _coach.fetchPlan(current, history);
      final nextNutrition = await _coach.fetchNutrition(current);
      plan = nextPlan;
      nutrition = nextNutrition;
      usingFallback = false;
    } catch (_) {
      plan = _fallback.plan(current, history);
      nutrition = _fallback.nutrition(current);
      usingFallback = true;
    }
  }

  Future<void> initialize() async {
    profile = await _local.loadProfile();
    history = await _local.loadHistory();
    await _refreshCoach();
    loading = false;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfileSnapshot value) async {
    await _local.saveProfile(value);
    profile = value;
    await _refreshCoach();
    notifyListeners();
  }

  Future<void> recordSession(SessionResult result) async {
    await _local.saveSession(result);
    history = await _local.loadHistory();
    await _refreshCoach();
    notifyListeners();
  }

  int get completedCount => history.where((e) => e.isCompleted).length;

  int get streak {
    final days = history
        .where((e) => e.isCompleted)
        .map((e) {
          final day = e.finishedAt.toLocal();
          return DateTime(day.year, day.month, day.day);
        })
        .toSet();
    if (days.isEmpty) return 0;
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }
}
