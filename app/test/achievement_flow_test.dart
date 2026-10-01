import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/concept_progress.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/models/review.dart';
import 'package:dekisugi/models/streak.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_live.dart';
import 'support/live_fakes.dart';

const _m01Lure = 'えっと、じゃあ重いものの方が速く落ちるってこと？';

class _FlakyStore extends MemorySessionStore {
  bool failExplained = true;

  @override
  Future<void> recordExplained(ExplainedItem item) async {
    if (failExplained) throw StateError('test save failure');
    await super.recordExplained(item);
  }
}

class _FlakyMissionStore extends MemorySessionStore {
  bool failCompletion = true;

  @override
  Future<ConceptProgress> completeMission(
    int sessionId, {
    required bool cleared,
    required DateTime completedAt,
    ExplainedItem? explained,
    ReviewItem? review,
  }) async {
    if (failCompletion) throw StateError('test mission completion failure');
    return super.completeMission(
      sessionId,
      cleared: cleared,
      completedAt: completedAt,
      explained: explained,
      review: review,
    );
  }
}

Slot explainedSlot({
  List<String> evidence = const ['u01'],
  List<Probe> probes = const [],
}) => Slot(
  key: 'fall',
  label: '落下の速さ',
  status: SlotStatus.explained,
  content: 'AIが作った要約',
  evidence: evidence,
  followUpHint: '',
  probes: probes,
);

Dossier finalDossier(Slot slot) =>
    Dossier(unitId: 'force-motion', slots: [slot], coverage: 100);

LiveSessionController controller(
  SessionStore store, {
  String? focusConceptKey,
  MissionKind missionKind = MissionKind.teach,
}) => LiveSessionController(
  unitId: 'force-motion',
  focusConceptKey: focusConceptKey,
  missionKind: missionKind,
  tokens: FakeTokens(grantFor(1)),
  store: store,
  mic: FakeMic(),
  player: PcmPlayer(sink: FakeSink()),
);

Future<SavedSession> focusedSaved(
  SessionStore store, {
  required MissionKind missionKind,
  required Dossier dossier,
  String text = '条件をそろえると重さによらず同時に落ちる',
}) async {
  final id = await store.startSession(
    'force-motion',
    focusConceptKey: 'fall',
    missionKind: missionKind,
  );
  await store.saveProgress(
    id,
    transcript: [
      const Utterance(
        id: 'u01',
        isStudent: false,
        text: _m01Lure,
        challengeLureId: 'M01',
        challengeLureText: _m01Lure,
      ),
      Utterance(id: 'u02', isStudent: true, text: text),
    ],
    dossier: dossier,
  );
  return (await store.unfinished(
    unitId: 'force-motion',
    focusConceptKey: 'fall',
    missionKind: missionKind,
  ))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('最終カルテと最新の生発話から成果を1回だけ保存する', () async {
    final store = MemorySessionStore();
    final live = controller(store);
    addTearDown(live.dispose);
    live.transcript.addAll(const [
      Utterance(id: 'u01', isStudent: true, text: '重い方が速く落ちる'),
      Utterance(id: 'u02', isStudent: true, text: 'いや、重さは関係ない'),
    ]);
    live.dossier = finalDossier(explainedSlot(evidence: const ['u01', 'u02']));

    await live.stop(to: LiveState.done);
    await live.stop(to: LiveState.done);

    expect(live.state, LiveState.done);
    expect(live.sessionAchievements.single.said, 'いや、重さは関係ない');
    expect((await store.explained()).single.said, 'いや、重さは関係ない');
    expect((await store.days()).single.done, 1, reason: '重複stopで成果を二重加算している');
  });

  test('訂正できなかった誤概念が残るslotを成果として祝わない', () async {
    final store = MemorySessionStore();
    final live = controller(store);
    addTearDown(live.dispose);
    live.transcript.add(
      const Utterance(id: 'u01', isStudent: true, text: '重い方が速い'),
    );
    live.dossier = finalDossier(
      explainedSlot(
        probes: const [
          Probe(
            id: 'm01',
            result: ProbeResult.accepted,
            evidence: ['u01'],
            countered: true,
          ),
        ],
      ),
    );

    await live.stop(to: LiveState.done);

    expect(live.sessionAchievements, isEmpty);
    expect(await store.explained(), isEmpty);
  });

  test('中断再開の前半で説明できた内容も完了時に復元する', () async {
    final store = MemorySessionStore();
    final id = await store.startSession('force-motion');
    await store.saveProgress(
      id,
      transcript: const [
        Utterance(id: 'u01', isStudent: true, text: '重さは関係ない'),
      ],
      dossier: finalDossier(explainedSlot()),
    );
    final saved = await store.unfinished(unitId: 'force-motion');
    final live = controller(store);
    addTearDown(live.dispose);

    expect(await live.resumeSaved(saved!), isTrue);
    await live.stop(to: LiveState.done);

    expect(live.sessionAchievements.single.said, '重さは関係ない');
    expect((await store.explained()).single.said, '重さは関係ない');
    expect(await store.unfinished(unitId: 'force-motion'), isNull);
  });

  test('再開候補の破棄はController内の逐語とセッション参照も外す', () async {
    final store = MemorySessionStore();
    final id = await store.startSession('force-motion');
    await store.saveProgress(
      id,
      transcript: const [Utterance(id: 'u01', isStudent: true, text: '途中の説明')],
      dossier: finalDossier(explainedSlot()),
    );
    final saved = await store.unfinished(unitId: 'force-motion');
    final live = controller(store);
    addTearDown(live.dispose);
    expect(await live.resumeSaved(saved!), isTrue);

    expect(await live.discardSaved(saved), isTrue);

    expect(live.transcript, isEmpty);
    expect(live.dossier, isNull);
    expect(await store.unfinished(unitId: 'force-motion'), isNull);
    expect((await store.recentSessions()).single.id, id);
    expect((await store.recentSessions()).single.isFinished, isTrue);
  });

  test('保存失敗を完了画面へ伝え、成功した処理を重複せず再試行する', () async {
    final store = _FlakyStore();
    final live = controller(store);
    addTearDown(live.dispose);
    live.transcript.add(
      const Utterance(id: 'u01', isStudent: true, text: '重さは関係ない'),
    );
    live.dossier = finalDossier(explainedSlot());

    await live.stop(to: LiveState.done);
    expect(live.completionSaveFailed, isTrue);
    expect(await store.explained(), isEmpty);

    store.failExplained = false;
    expect(await live.retryCompletionSave(), isTrue);
    expect(live.completionSaveFailed, isFalse);
    expect((await store.explained()).single.said, '重さは関係ない');
    expect((await store.days()).single.done, 1);
  });

  test('focused CASE CLEARを成果・保持間隔・完了数まで1回で確定する', () async {
    final store = MemorySessionStore();
    final dossier = finalDossier(
      explainedSlot(
        evidence: const ['u02'],
        probes: const [
          Probe(id: 'M01', result: ProbeResult.corrected, evidence: ['u02']),
        ],
      ),
    );
    final saved = await focusedSaved(
      store,
      missionKind: MissionKind.caseRetry,
      dossier: dossier,
    );
    final live = controller(
      store,
      focusConceptKey: 'fall',
      missionKind: MissionKind.caseRetry,
    );
    addTearDown(live.dispose);
    expect(await live.resumeSaved(saved), isTrue);

    await live.stop(to: LiveState.done);
    await live.stop(to: LiveState.done);

    final progress = await store.progressFor('force-motion', 'fall');
    expect(progress?.lastOutcome, ConceptOutcome.retained);
    expect(progress?.successfulRetrievals, 1);
    expect((await store.days()).single.done, 1);
    expect((await store.explained()).single.conceptKey, 'fall');
    expect(await store.reviewItems(), isEmpty);
    expect(
      await store.unfinished(
        unitId: 'force-motion',
        focusConceptKey: 'fall',
        missionKind: MissionKind.caseRetry,
      ),
      isNull,
    );
  });

  test('focused未決着は完了数を増やさず、即REPAIRへ送る', () async {
    final store = MemorySessionStore();
    final saved = await focusedSaved(
      store,
      missionKind: MissionKind.teach,
      dossier: finalDossier(
        explainedSlot(
          evidence: const ['u02'],
          probes: const [
            Probe(id: 'M01', result: ProbeResult.accepted, evidence: ['u02']),
          ],
        ),
      ),
    );
    final live = controller(store, focusConceptKey: 'fall');
    addTearDown(live.dispose);
    expect(await live.resumeSaved(saved), isTrue);

    await live.stop(to: LiveState.done);

    expect(live.sessionAchievements, isEmpty);
    expect((await store.days()), isEmpty);
    final progress = await store.progressFor('force-motion', 'fall');
    expect(progress?.lastOutcome, ConceptOutcome.rematchNeeded);
    expect(progress?.nextMissionKind, MissionKind.repair);
    expect(
      (await store.reviewItems()).single.reason,
      ReviewReason.notCorrected,
    );
  });

  test('focused完了保存の再試行はCASE成功を二重加算しない', () async {
    final store = _FlakyMissionStore();
    final saved = await focusedSaved(
      store,
      missionKind: MissionKind.caseRetry,
      dossier: finalDossier(
        explainedSlot(
          evidence: const ['u02'],
          probes: const [
            Probe(id: 'M01', result: ProbeResult.corrected, evidence: ['u02']),
          ],
        ),
      ),
    );
    final live = controller(
      store,
      focusConceptKey: 'fall',
      missionKind: MissionKind.caseRetry,
    );
    addTearDown(live.dispose);
    expect(await live.resumeSaved(saved), isTrue);

    await live.stop(to: LiveState.done);
    expect(live.completionSaveFailed, isTrue);
    expect(await store.conceptProgress(), isEmpty);

    store.failCompletion = false;
    expect(await live.retryCompletionSave(), isTrue);
    expect(await live.retryCompletionSave(), isTrue);
    expect((await store.days()).single.done, 1);
    expect(
      (await store.progressFor('force-motion', 'fall'))?.successfulRetrievals,
      1,
    );
  });
}
