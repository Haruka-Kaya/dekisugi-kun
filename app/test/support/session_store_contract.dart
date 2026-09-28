import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/models/concept_progress.dart';
import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/models/review.dart';
import 'package:dekisugi/models/streak.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// [SessionStore] の実装がどれも満たすべき振る舞い。
///
/// **メモリ版と sqflite 版の両方にこれを流す。**
/// メモリ版はスキーマを持たないので、整合はテストでしか担保できない。
/// 片方だけ直すと「テストは通るのに実機で壊れる」という最悪の形になる。
void runSessionStoreContract(
  String label,
  Future<SessionStore> Function() make,
) {
  group('$label — SessionStore の契約', () {
    late SessionStore store;

    setUp(() async => store = await make());
    tearDown(() async => store.close());

    ReviewItem item({
      String key = 'fall',
      String label = '落下の速さ',
      ReviewReason reason = ReviewReason.notCorrected,
      DateTime? seen,
    }) => ReviewItem(
      unitId: 'force-motion',
      conceptKey: key,
      label: label,
      reason: reason,
      lastSeen: seen ?? DateTime(2026, 8, 1),
    );

    Future<ReviewItem> only() async {
      final all = await store.reviewItems();
      expect(all, hasLength(1));
      return all.first;
    }

    group('復習の見直し回数', () {
      test('新しく入れたら 0 から始まる', () async {
        await store.upsertReviews([item()]);
        expect((await only()).timesSeen, 0);
        expect((await only()).lastReviewedAt, isNull);
      });

      test('見直すたびに増える', () async {
        await store.upsertReviews([item()]);
        await store.markReviewed('force-motion', 'fall');
        await store.markReviewed('force-motion', 'fall');

        final r = await only();
        expect(r.timesSeen, 2);
        expect(r.lastReviewedAt, isNotNull);
      });

      test('会話をやり直しても 0 に戻らない', () async {
        // **これが段階Bの本体。**
        // 以前は ConflictAlgorithm.replace で行ごと入れ替えていたので、
        // 会話するたびに回数が消え、間隔の階段が1段も上がらなかった
        await store.upsertReviews([item()]);
        await store.markReviewed('force-motion', 'fall');
        expect((await only()).timesSeen, 1);

        // 同じ概念がまた復習に回ってきた（＝また会話した）
        await store.upsertReviews([item(seen: DateTime(2026, 8, 5))]);

        final r = await only();
        expect(r.timesSeen, 1, reason: '会話のたびに見直し回数が消えている');
        expect(r.lastSeen, DateTime(2026, 8, 5), reason: '扱った日時は新しくなるべき');
      });

      test('やり直しでラベルと理由は新しくなる', () async {
        await store.upsertReviews([item()]);
        await store.upsertReviews([
          item(label: '落ちる速さ', reason: ReviewReason.thin),
        ]);

        final r = await only();
        expect(r.label, '落ちる速さ');
        expect(r.reason, ReviewReason.thin);
      });

      test('無い概念を見直しても落ちない', () async {
        await store.markReviewed('force-motion', 'nothing');
        expect(await store.reviewItems(), isEmpty);
      });

      test('消したら消える', () async {
        await store.upsertReviews([item()]);
        await store.clearReview('force-motion', 'fall');
        expect(await store.reviewItems(), isEmpty);
      });
    });

    group('中断と再開', () {
      test('中身のない会話は再開を提案しない', () async {
        await store.startSession('force-motion');
        expect(await store.unfinished(), isNull);
      });

      test('旧来の会話は概念と説明の足場がnull', () async {
        final id = await store.startSession('force-motion');
        await store.saveProgress(
          id,
          transcript: const [
            Utterance(id: 'u1', isStudent: true, text: '単元全体の話'),
          ],
        );

        final saved = await store.unfinished(unitId: 'force-motion');
        expect(saved?.focusConceptKey, isNull);
        expect(saved?.tactic, isNull);
      });

      test('逐語が残っていれば再開できる', () async {
        final id = await store.startSession('force-motion');
        await store.saveProgress(
          id,
          transcript: [
            const Utterance(id: 'u1', isStudent: true, text: '重いほうが速く落ちる'),
          ],
        );

        final saved = await store.unfinished();
        expect(saved?.transcript.single.text, '重いほうが速く落ちる');

        await store.finishSession(id);
        expect(await store.unfinished(), isNull);
      });

      test('challengeを示すAI発話の印を失わない', () async {
        final id = await store.startSession(
          'force-motion',
          focusConceptKey: 'fall',
        );
        await store.saveProgress(
          id,
          transcript: const [
            Utterance(
              id: 'u1',
              isStudent: false,
              text: '重いものの方が速く落ちるってこと？',
              challengeLureId: 'M01',
              challengeLureText: '重いものの方が速く落ちるってこと？',
            ),
          ],
        );

        final saved = await store.unfinished(
          unitId: 'force-motion',
          focusConceptKey: 'fall',
        );
        expect(saved?.transcript.single.challengeLureId, 'M01');
        expect(saved?.transcript.single.challengeLureText, '重いものの方が速く落ちるってこと？');
      });

      test('単元を指定したら、別単元の未完了会話を返さない', () async {
        final force = await store.startSession('force-motion');
        await store.saveProgress(
          force,
          transcript: const [Utterance(id: 'u1', isStudent: true, text: '力の話')],
        );
        final weather = await store.startSession('weather');
        await store.saveProgress(
          weather,
          transcript: const [
            Utterance(id: 'u1', isStudent: true, text: '天気の話'),
          ],
        );

        expect((await store.unfinished(unitId: 'force-motion'))?.id, force);
        expect((await store.unfinished(unitId: 'weather'))?.id, weather);
        expect(await store.unfinished(unitId: 'unknown'), isNull);
      });

      test('同じ単元でも別概念の会話を返さない', () async {
        final fall = await store.startSession(
          'force-motion',
          focusConceptKey: 'fall',
          tactic: TeachingTactic.example,
        );
        await store.saveProgress(
          fall,
          transcript: const [
            Utterance(id: 'u1', isStudent: true, text: '落下の話'),
          ],
        );
        final inertia = await store.startSession(
          'force-motion',
          focusConceptKey: 'inertia',
          tactic: TeachingTactic.experiment,
        );
        await store.saveProgress(
          inertia,
          transcript: const [
            Utterance(id: 'u1', isStudent: true, text: '慣性の話'),
          ],
        );

        final fallSaved = await store.unfinished(
          unitId: 'force-motion',
          focusConceptKey: 'fall',
        );
        expect(fallSaved?.id, fall);
        expect(fallSaved?.focusConceptKey, 'fall');
        expect(fallSaved?.tactic, TeachingTactic.example);

        final inertiaSaved = await store.unfinished(
          unitId: 'force-motion',
          focusConceptKey: 'inertia',
        );
        expect(inertiaSaved?.id, inertia);
        expect(inertiaSaved?.focusConceptKey, 'inertia');
        expect(inertiaSaved?.tactic, TeachingTactic.experiment);
        expect(
          await store.unfinished(unitId: 'force-motion'),
          isNull,
          reason: '単元全体会話へ1概念ミッションを混ぜてはいけない',
        );
        expect(
          await store.unfinished(
            unitId: 'force-motion',
            focusConceptKey: 'acceleration',
          ),
          isNull,
        );
      });

      test('保存更新と終了をまたいでもミッション文脈を保つ', () async {
        final id = await store.startSession(
          'force-motion',
          focusConceptKey: 'fall',
          tactic: TeachingTactic.reason,
        );
        await store.saveProgress(
          id,
          transcript: const [
            Utterance(id: 'u1', isStudent: true, text: '理由を説明する'),
          ],
        );

        await store.finishSession(id);
        final saved = (await store.recentSessions()).single;
        expect(saved.focusConceptKey, 'fall');
        expect(saved.tactic, TeachingTactic.reason);
      });

      test('同じ概念でも異なるミッション種別を取り違えない', () async {
        final repair = await store.startSession(
          'force-motion',
          focusConceptKey: 'fall',
          missionKind: MissionKind.repair,
        );
        await store.saveProgress(
          repair,
          transcript: const [
            Utterance(id: 'repair', isStudent: true, text: '説明を組み直す'),
          ],
        );
        final retry = await store.startSession(
          'force-motion',
          focusConceptKey: 'fall',
          missionKind: MissionKind.caseRetry,
        );
        await store.saveProgress(
          retry,
          transcript: const [
            Utterance(id: 'retry', isStudent: true, text: '別場面で使う'),
          ],
        );

        expect(
          (await store.unfinished(
            unitId: 'force-motion',
            focusConceptKey: 'fall',
            missionKind: MissionKind.repair,
          ))?.id,
          repair,
        );
        expect(
          (await store.unfinished(
            unitId: 'force-motion',
            focusConceptKey: 'fall',
            missionKind: MissionKind.caseRetry,
          ))?.id,
          retry,
        );
      });
    });

    group('日ごとの記録', () {
      test('足し算で積む（上書きしない）', () async {
        // 1日に2回会話したら、2回目で1回目が消えてはいけない
        await store.recordActivity('2026-08-06', sessions: 1, done: 1);
        await store.recordActivity('2026-08-06', sessions: 1, textTurns: 3);

        final d = (await store.days()).single;
        expect(d.sessions, 2);
        expect(d.done, 1);
        expect(d.textTurns, 3);
      });

      test('新しい順に返る', () async {
        await store.recordActivity('2026-08-04', done: 1);
        await store.recordActivity('2026-08-06', done: 1);
        await store.recordActivity('2026-08-05', done: 1);

        expect((await store.days()).map((d) => d.day).toList(), [
          '2026-08-06',
          '2026-08-05',
          '2026-08-04',
        ]);
      });

      test('記録が無ければ空', () async {
        expect(await store.days(), isEmpty);
      });

      test('件数を絞れる', () async {
        for (var i = 1; i <= 5; i++) {
          await store.recordActivity('2026-08-0$i', done: 1);
        }
        expect(await store.days(limit: 2), hasLength(2));
      });
    });

    group('言えるようになったこと', () {
      ExplainedItem said(String key, String text, DateTime at) => ExplainedItem(
        unitId: 'force-motion',
        conceptKey: key,
        label: '概念$key',
        said: text,
        at: at,
      );

      test('生徒の言葉がそのまま残る', () async {
        await store.recordExplained(
          said('fall', '空気の抵抗を無視すれば重さによらない', DateTime(2026, 8, 6)),
        );
        final e = (await store.explained()).single;
        expect(e.said, '空気の抵抗を無視すれば重さによらない');
        expect(e.conceptKey, 'fall');
      });

      test('同じ概念は最後の1件だけ残る', () async {
        // 言い直すたびに増えると、積み上がった数が水増しになる
        await store.recordExplained(said('fall', '古い説明', DateTime(2026, 8, 5)));
        await store.recordExplained(
          said('fall', '新しい説明', DateTime(2026, 8, 6)),
        );
        final all = await store.explained();
        expect(all, hasLength(1));
        expect(all.single.said, '新しい説明');
      });

      test('新しい順に返る', () async {
        await store.recordExplained(said('a', 'A', DateTime(2026, 8, 4)));
        await store.recordExplained(said('c', 'C', DateTime(2026, 8, 6)));
        await store.recordExplained(said('b', 'B', DateTime(2026, 8, 5)));
        expect((await store.explained()).map((e) => e.said).toList(), [
          'C',
          'B',
          'A',
        ]);
      });

      test('記録が無ければ空', () async {
        expect(await store.explained(), isEmpty);
      });
    });

    group('Mission Pathの確定', () {
      Future<int> start(MissionKind kind) => store.startSession(
        'force-motion',
        focusConceptKey: 'fall',
        missionKind: kind,
      );

      ExplainedItem achievement(String said, DateTime at) => ExplainedItem(
        unitId: 'force-motion',
        conceptKey: 'fall',
        label: '落下の速さ',
        said: said,
        at: at,
      );

      ReviewItem rematch(DateTime at) => ReviewItem(
        unitId: 'force-motion',
        conceptKey: 'fall',
        label: '落下の速さ',
        reason: ReviewReason.notCorrected,
        lastSeen: at,
      );

      test('初回clearは翌日のcase retryを作る', () async {
        final at = DateTime(2026, 8, 10, 12);
        await store.setExamDate(DateTime(2026, 10, 1));
        final id = await start(MissionKind.teach);
        final progress = await store.completeMission(
          id,
          cleared: true,
          completedAt: at,
          explained: achievement('重さによらない', at),
        );

        expect(progress.lastOutcome, ConceptOutcome.learned);
        expect(progress.successfulRetrievals, 0);
        expect(progress.lastAttemptDay, '2026-08-10');
        expect(progress.lastSuccessDay, '2026-08-10');
        expect(progress.nextDueDay, '2026-08-11');
        expect(progress.nextMissionKind, MissionKind.caseRetry);
        expect(progress.sourceSessionId, id);
        expect((await store.explained()).single.said, '重さによらない');
        expect(await store.reviewItems(), isEmpty);
        expect((await store.days()).single.done, 1);
        expect((await store.recentSessions()).single.isFinished, isTrue);
      });

      test('午前4時より前は前日の学習として確定する', () async {
        final at = DateTime(2026, 8, 10, 3, 59);
        final id = await start(MissionKind.teach);
        final progress = await store.completeMission(
          id,
          cleared: true,
          completedAt: at,
          explained: achievement('空気抵抗を無視する', at),
        );

        expect(progress.lastAttemptDay, '2026-08-09');
        expect(progress.nextDueDay, '2026-08-10');
        expect((await store.days()).single.day, '2026-08-09');
      });

      test('遅れて実施したretention clearは実成功日から次を数える', () async {
        final learnedAt = DateTime(2026, 8, 1, 12);
        final teach = await start(MissionKind.teach);
        await store.completeMission(
          teach,
          cleared: true,
          completedAt: learnedAt,
          explained: achievement('初回の説明', learnedAt),
        );

        // 期限は8/2だったが、実際に想起したのは8/6。
        final retainedAt = DateTime(2026, 8, 6, 18);
        final retry = await start(MissionKind.caseRetry);
        final progress = await store.completeMission(
          retry,
          cleared: true,
          completedAt: retainedAt,
          explained: achievement('別場面でも説明できた', retainedAt),
        );

        expect(progress.lastOutcome, ConceptOutcome.retained);
        expect(progress.successfulRetrievals, 1);
        expect(progress.lastSuccessDay, '2026-08-06');
        expect(progress.nextDueDay, '2026-08-09');
        expect(progress.nextDueDay, isNot('2026-08-05'));
      });

      test('未決着は即repairに回り、repair clearで翌日へ進む', () async {
        final failedAt = DateTime(2026, 8, 10, 12);
        final failed = await start(MissionKind.teach);
        final pending = await store.completeMission(
          failed,
          cleared: false,
          completedAt: failedAt,
          review: rematch(failedAt),
        );

        expect(pending.lastOutcome, ConceptOutcome.rematchNeeded);
        expect(pending.nextDueDay, '2026-08-10');
        expect(pending.nextMissionKind, MissionKind.repair);
        expect(await store.reviewItems(), hasLength(1));
        expect(await store.days(), isEmpty, reason: '未決着をdoneに数えてはいけない');

        final repairedAt = DateTime(2026, 8, 10, 18);
        final repair = await start(MissionKind.repair);
        final cleared = await store.completeMission(
          repair,
          cleared: true,
          completedAt: repairedAt,
          explained: achievement('条件と理由を含めて言い直した', repairedAt),
        );

        expect(cleared.lastOutcome, ConceptOutcome.learned);
        expect(cleared.successfulRetrievals, 0);
        expect(cleared.nextDueDay, '2026-08-11');
        expect(cleared.nextMissionKind, MissionKind.caseRetry);
        expect(await store.reviewItems(), isEmpty);
        expect((await store.days()).single.done, 1);
      });

      test('同じsessionの完了を再試行しても回数とdoneを二重加算しない', () async {
        final learnedAt = DateTime(2026, 8, 1, 12);
        final teach = await start(MissionKind.teach);
        await store.completeMission(
          teach,
          cleared: true,
          completedAt: learnedAt,
          explained: achievement('初回', learnedAt),
        );

        final retainedAt = DateTime(2026, 8, 2, 12);
        final retry = await start(MissionKind.caseRetry);
        final first = await store.completeMission(
          retry,
          cleared: true,
          completedAt: retainedAt,
          explained: achievement('保持できた', retainedAt),
        );
        final duplicate = await store.completeMission(
          retry,
          cleared: true,
          completedAt: retainedAt,
          explained: achievement('保持できた', retainedAt),
        );

        expect(first.successfulRetrievals, 1);
        expect(duplicate.successfulRetrievals, 1);
        expect(
          (await store.progressFor('force-motion', 'fall'))?.sourceSessionId,
          retry,
        );
        expect(
          (await store.days()).fold<int>(0, (sum, day) => sum + day.done),
          2,
        );
      });
    });

    group('思い込みの記録（learningNeedStates)', () {
      // カルテ画面のデータ経路。実機では sqflite を通るので、
      // メモリ版だけを試すと「テストは通るのに実機で空になる」。
      LearningEventCommand needEvent({
        required String eventId,
        required String nodeId,
        required String learningDay,
        required DateTime occurredAt,
        required LearningAttemptOutcome outcome,
        required LearningEvidenceLevel evidence,
        Map<String, Iterable<String>> observed = const {},
        Map<String, Iterable<String>> resolved = const {},
        LearningRepairResolution? repairResolution,
      }) => LearningEventCommand(
        eventId: eventId,
        scope: LearningScope.personal,
        origin: LearningOrigin.practice,
        courseId: 'course.jhs-science',
        nodeId: nodeId,
        activityId: 'activity.karte.v1',
        skillIds: const {'force-motion/fall'},
        activityKind: LearningActivityKind.diagram,
        outcome: outcome,
        evidence: evidence,
        contentVersion: 'catalog.v10',
        learningDay: learningDay,
        occurredAt: occurredAt,
        practiceNeedCodes: observed,
        resolvedPracticeNeedCodes: resolved,
        repairResolution: repairResolution,
      );

      test('観測だけならresolvedDayの無いactiveとして読める', () async {
        await store.commitLearningEvent(
          needEvent(
            eventId: 'contract.need.observe',
            nodeId: 'node.karte.1',
            learningDay: '2026-08-10',
            occurredAt: DateTime.utc(2026, 8, 10, 12),
            outcome: LearningAttemptOutcome.corrected,
            evidence: LearningEvidenceLevel.selfCompared,
            observed: const {
              'force-motion/fall': {'science.fall.foundation'},
            },
          ),
        );

        final states = await store.learningNeedStates(LearningScope.personal);
        expect(states, hasLength(1));
        expect(states.single.needCode, 'science.fall.foundation');
        expect(states.single.skillId, 'force-motion/fall');
        expect(states.single.resolved, isFalse);
        expect(states.single.resolvedDay, isNull);
        expect(states.single.firstObservedDay, '2026-08-10');
        expect(states.single.lastObservedDay, '2026-08-10');
      });

      test('解消のcommitがresolved日で反映される', () async {
        await store.commitLearningEvent(
          needEvent(
            eventId: 'contract.need.observe',
            nodeId: 'node.karte.1',
            learningDay: '2026-08-10',
            occurredAt: DateTime.utc(2026, 8, 10, 12),
            outcome: LearningAttemptOutcome.corrected,
            evidence: LearningEvidenceLevel.selfCompared,
            observed: const {
              'force-motion/fall': {'science.fall.foundation'},
            },
          ),
        );
        await store.commitLearningEvent(
          needEvent(
            eventId: 'contract.need.resolve',
            nodeId: 'node.karte.2',
            learningDay: '2026-08-12',
            occurredAt: DateTime.utc(2026, 8, 12, 12),
            outcome: LearningAttemptOutcome.structuredSuccess,
            evidence: LearningEvidenceLevel.structuredCorrection,
            resolved: const {
              'force-motion/fall': {'science.fall.foundation'},
            },
            repairResolution: LearningRepairResolution(
              unitId: 'force-motion',
              conceptKey: 'fall',
              skillId: 'force-motion/fall',
              needCode: 'science.fall.foundation',
              routeKind: LearningRepairRouteKind.practice,
              practiceAttempt: 0,
            ),
          ),
        );

        final states = await store.learningNeedStates(LearningScope.personal);
        expect(states, hasLength(1));
        expect(states.single.resolved, isTrue);
        expect(states.single.resolvedDay, '2026-08-12');
        expect(states.single.firstObservedDay, '2026-08-10');
      });

      test('別scopeのneed状態を混ぜない', () async {
        await store.commitLearningEvent(
          needEvent(
            eventId: 'contract.need.observe',
            nodeId: 'node.karte.1',
            learningDay: '2026-08-10',
            occurredAt: DateTime.utc(2026, 8, 10, 12),
            outcome: LearningAttemptOutcome.corrected,
            evidence: LearningEvidenceLevel.selfCompared,
            observed: const {
              'force-motion/fall': {'science.fall.foundation'},
            },
          ),
        );

        expect(
          await store.learningNeedStates(LearningScope.schoolLocal),
          isEmpty,
          reason: '個人の観測を学校scopeへ漏らしてはいけない',
        );
      });
    });

    group('設定', () {
      test('読み書きと削除', () async {
        expect(await store.getSetting('k'), isNull);
        await store.setSetting('k', 'v');
        expect(await store.getSetting('k'), 'v');
        await store.setSetting('k', null);
        expect(await store.getSetting('k'), isNull);
      });

      test('考査日', () async {
        expect(await store.examDate(), isNull);
        await store.setExamDate(DateTime(2026, 9, 10));
        expect(await store.examDate(), DateTime(2026, 9, 10));
      });
    });
  });
}
