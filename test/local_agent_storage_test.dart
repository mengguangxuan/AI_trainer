import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ai_fitness_d_starter/core/models/coach_session_summary.dart';
import 'package:ai_fitness_d_starter/core/models/session_result.dart';
import 'package:ai_fitness_d_starter/features/product/data/local_product_repository.dart';

void main() {
  late LocalProductRepository local;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    local = LocalProductRepository(SharedPreferencesAsync());
  });
  test(
    'parallel first requests and relaunch retain one installation UUID',
    () async {
      final ids = await Future.wait(
        List.generate(5, (_) => local.loadOrCreateInstallationId()),
      );
      expect(ids.toSet(), hasLength(1));
      expect(
        ids.first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(
        await LocalProductRepository(
          SharedPreferencesAsync(),
        ).loadOrCreateInstallationId(),
        ids.first,
      );
    },
  );
  test('concurrent summary writes preserve both records', () async {
    await Future.wait(
      List.generate(
        2,
        (i) => local.saveSummary(
          CoachSessionSummary(
            sessionId: 's$i',
            agentSummary: '总结$i',
            source: 'agent',
            nextPlanChanged: false,
            facts: const {},
            limitations: const [],
          ),
        ),
      ),
    );
    expect((await local.loadSummary('s0'))!.agentSummary, '总结0');
    expect((await local.loadSummary('s1'))!.agentSummary, '总结1');
  });
  test(
    'concurrent native records are retained and remain separate from summaries',
    () async {
      await Future.wait(
        List.generate(
          2,
          (i) => local.saveSession(
            SessionResult(
              sessionId: 's$i',
              status: 'completed',
              finishedAt: DateTime.now(),
              durationSeconds: 20,
              exercises: const [],
              source: 'real',
            ),
          ),
        ),
      );
      expect(await local.loadHistory(), hasLength(2));
      await local.saveSummary(
        const CoachSessionSummary(
          sessionId: 's0',
          agentSummary: '总结',
          source: 'agent',
          nextPlanChanged: false,
          facts: {},
          limitations: [],
        ),
      );
      await local.clearSummaries();
      expect(await local.loadSummary('s0'), isNull);
      final records = await local.loadHistory();
      expect(records, hasLength(2));
      expect(
        records.every((s) => s.agentSummary == null && s.source == 'real'),
        isTrue,
      );
    },
  );
}
