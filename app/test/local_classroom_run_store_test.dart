import 'dart:convert';

import 'package:dekisugi/models/classroom_mission.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/services/local_classroom_run_store.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('完了も回答や学校情報を持たず、既存5項目だけを保存する', () async {
    final backing = MemorySessionStore();
    final store = LocalClassroomRunStore(backing);
    final at = DateTime.utc(2026, 8, 10, 3, 4, 5);

    await store.begin(
      unitId: 'force-motion',
      conceptKey: 'fall',
      practiceAttempt: 2,
    );
    await store.enterPractice(
      unitId: 'force-motion',
      conceptKey: 'fall',
      practiceAttempt: 2,
    );
    await store.complete(
      unitId: 'force-motion',
      conceptKey: 'fall',
      practiceAttempt: 2,
      updatedAt: at,
    );

    final raw = await backing.getSetting(LocalClassroomRunStore.settingKey);
    expect(raw, isNotNull);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json.keys, unorderedEquals(['version', 'run']));
    final run = json['run'] as Map<String, dynamic>;
    expect(
      run.keys,
      unorderedEquals([
        'unitId',
        'conceptKey',
        'practiceAttempt',
        'stage',
        'updatedAt',
      ]),
    );
    expect(run['practiceAttempt'], 2);
    expect(run['stage'], 'completed');
    expect(run['updatedAt'], at.millisecondsSinceEpoch);
    for (final forbidden in [
      'answer',
      'text',
      'response',
      'selection',
      'student',
      'school',
      'class',
      'account',
      'device',
    ]) {
      expect(raw.toLowerCase(), isNot(contains(forbidden)));
    }
  });

  test('教材から練習へ進み、OS再起動後も同じ概念の安全な段階を読める', () async {
    final backing = MemorySessionStore();
    final writer = LocalClassroomRunStore(backing);
    await writer.begin(unitId: 'u1', conceptKey: 'c1', practiceAttempt: 1);
    await writer.enterPractice(
      unitId: 'u1',
      conceptKey: 'c1',
      practiceAttempt: 1,
    );

    final restored = await LocalClassroomRunStore(backing).load();

    expect(restored, isNotNull);
    expect(restored!.unitId, 'u1');
    expect(restored.conceptKey, 'c1');
    expect(restored.practiceAttempt, 1);
    expect(restored.id, 'u1/c1/1');
    expect(restored.stage, LocalClassroomStage.practice);
  });

  test('一致する練習だけを完了でき、再起動後も直近1件を読める', () async {
    final backing = MemorySessionStore();
    final store = LocalClassroomRunStore(backing);
    final completedAt = DateTime.utc(2026, 8, 10, 8, 30);
    await store.begin(unitId: 'u1', conceptKey: 'c1', practiceAttempt: 2);

    await expectLater(
      store.complete(unitId: 'u1', conceptKey: 'c1', practiceAttempt: 2),
      throwsStateError,
      reason: '教材を読んだだけで完了表示にしない',
    );
    await store.enterPractice(
      unitId: 'u1',
      conceptKey: 'c1',
      practiceAttempt: 2,
    );
    for (final mismatch in [
      (unitId: 'u2', conceptKey: 'c1', attempt: 2),
      (unitId: 'u1', conceptKey: 'c2', attempt: 2),
      (unitId: 'u1', conceptKey: 'c1', attempt: 1),
    ]) {
      await expectLater(
        store.complete(
          unitId: mismatch.unitId,
          conceptKey: mismatch.conceptKey,
          practiceAttempt: mismatch.attempt,
        ),
        throwsStateError,
      );
      expect((await store.load())?.stage, LocalClassroomStage.practice);
    }

    final completed = await store.complete(
      unitId: 'u1',
      conceptKey: 'c1',
      practiceAttempt: 2,
      updatedAt: completedAt,
    );
    expect(completed.stage, LocalClassroomStage.completed);
    expect(completed.updatedAt, completedAt);

    final restored = await LocalClassroomRunStore(backing).load();
    expect(restored?.id, 'u1/c1/2');
    expect(restored?.stage, LocalClassroomStage.completed);
    expect(restored?.updatedAt, completedAt);
    await expectLater(
      store.complete(unitId: 'u1', conceptKey: 'c1', practiceAttempt: 2),
      throwsStateError,
      reason: '同じ完了を再記録して完了日時を動かさない',
    );
  });

  test('未知field・version・段階・範囲外日時を再開に使わない', () async {
    final backing = MemorySessionStore();
    final store = LocalClassroomRunStore(backing);
    for (final raw in [
      '{',
      '{"version":1,"run":{"unitId":"u","conceptKey":"c","stage":"practice","updatedAt":1786290000000}}',
      '{"version":2,"run":{}}',
      '{"version":2,"run":{"unitId":"u","conceptKey":"c","practiceAttempt":0,"stage":"practice","updatedAt":1786290000000},"answer":"x"}',
      '{"version":2,"run":{"unitId":"u","conceptKey":"c","practiceAttempt":0,"stage":"answer","updatedAt":1786290000000}}',
      '{"version":2,"run":{"unitId":"u","conceptKey":"c","practiceAttempt":0,"stage":"practice","updatedAt":1}}',
      '{"version":2,"run":{"unitId":"u","conceptKey":"c","practiceAttempt":3,"stage":"practice","updatedAt":1786290000000}}',
      '{"version":2,"run":{"unitId":"u","conceptKey":"c","practiceAttempt":0,"stage":"practice","updatedAt":1786290000000,"student":"x"}}',
    ]) {
      await backing.setSetting(LocalClassroomRunStore.settingKey, raw);
      expect(await store.load(), isNull, reason: raw);
      expect(
        await backing.getSetting(LocalClassroomRunStore.settingKey),
        isNull,
        reason: '曖昧または壊れた再開位置を残さない',
      );
    }
  });

  test('roundの範囲外は保存しない', () async {
    final store = LocalClassroomRunStore(MemorySessionStore());

    expect(
      () => store.begin(unitId: 'u', conceptKey: 'c', practiceAttempt: -1),
      throwsArgumentError,
    );
    expect(
      () =>
          store.enterPractice(unitId: 'u', conceptKey: 'c', practiceAttempt: 3),
      throwsArgumentError,
    );
    expect(
      () => store.complete(unitId: 'u', conceptKey: 'c', practiceAttempt: 3),
      throwsArgumentError,
    );
  });

  test('本人が途中位置または最後の完了表示を削除できる', () async {
    final backing = MemorySessionStore();
    final store = LocalClassroomRunStore(backing);
    await store.begin(unitId: 'u', conceptKey: 'c', practiceAttempt: 0);
    await store.enterPractice(unitId: 'u', conceptKey: 'c', practiceAttempt: 0);
    await store.complete(unitId: 'u', conceptKey: 'c', practiceAttempt: 0);

    await store.clear();

    expect(await store.load(), isNull);
    expect(await backing.getSetting(LocalClassroomRunStore.settingKey), isNull);
  });

  test('教材番号とA/B/Cを全角入力から正規化し、旧コードは拒否する', () {
    const units = [
      UnitSummary(
        id: 'u1',
        title: '単元1',
        brief: '',
        concepts: [
          UnitConcept(key: 'c1', label: '概念1', storyTitle: '概念1の事件'),
          UnitConcept(key: 'c2', label: '概念2', storyTitle: '概念2の事件'),
        ],
        sectionCount: 2,
      ),
    ];
    final missions = ClassroomMission.fromUnits(units);

    expect(ClassroomAssignment.normalizeClassroomCode('1-2-a'), '01-02-A');
    expect(ClassroomAssignment.normalizeClassroomCode('０１ー０２ーＢ'), '01-02-B');
    expect(ClassroomAssignment.normalizeClassroomCode('01 02 c'), '01-02-C');
    expect(ClassroomAssignment.normalizeClassroomCode('01-02'), isNull);
    expect(ClassroomAssignment.normalizeClassroomCode('01-02-D'), isNull);
    expect(ClassroomAssignment.normalizeClassroomCode('学校A-1'), isNull);
    expect(
      ClassroomAssignment.findByClassroomCode(
        missions,
        '１ー２ーＣ',
      )?.mission.conceptKey,
      'c2',
    );
    expect(
      ClassroomAssignment.findByClassroomCode(
        missions,
        '１ー２ーＣ',
      )?.practiceAttempt,
      2,
    );
  });

  test('Aはteach、B/CはcaseRetryと公開variantを固定する', () {
    expect(ClassroomRound.a.practiceAttempt, 0);
    expect(ClassroomRound.a.missionKind.name, 'teach');
    expect(ClassroomRound.a.practiceStage, LocalPracticeStage.foundation);
    expect(ClassroomRound.b.practiceAttempt, 1);
    expect(ClassroomRound.b.missionKind.name, 'caseRetry');
    expect(ClassroomRound.b.practiceStage, LocalPracticeStage.conditions);
    expect(ClassroomRound.c.practiceAttempt, 2);
    expect(ClassroomRound.c.missionKind.name, 'caseRetry');
    expect(ClassroomRound.c.practiceStage, LocalPracticeStage.transfer);
  });
}
