import 'dart:convert';

import 'package:dekisugi/services/local_practice_store.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('回答本文を持たず、概念・回数・最終日時だけを保存する', () async {
    final backing = MemorySessionStore();
    final store = LocalPracticeStore(backing);
    final at = DateTime.utc(2026, 8, 10, 1, 2, 3);

    final result = await store.recordCompletion(
      unitId: 'force-motion',
      conceptKey: 'fall',
      completedAt: at,
    );

    expect(result.completedCount, 1);
    expect(result.lastCompletedAt, at);
    final raw = await backing.getSetting(LocalPracticeStore.settingKey);
    expect(raw, isNotNull);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['version'], 1);
    final record = (json['records'] as List).single as Map<String, dynamic>;
    expect(
      record.keys,
      unorderedEquals([
        'unitId',
        'conceptKey',
        'completedCount',
        'lastCompletedAt',
      ]),
    );
    expect(raw, isNot(contains('answer')));
    expect(raw, isNot(contains('text')));
    expect(raw, isNot(contains('device')));
    expect(raw, isNot(contains('age')));
    expect(raw, isNot(contains('variant')));
    expect(raw, isNot(contains('stage')));
  });

  test('同じ概念を直列加算し、別概念を失わない', () async {
    final store = LocalPracticeStore(MemorySessionStore());
    await Future.wait([
      store.recordCompletion(unitId: 'u1', conceptKey: 'c1'),
      store.recordCompletion(unitId: 'u1', conceptKey: 'c1'),
      store.recordCompletion(unitId: 'u1', conceptKey: 'c2'),
    ]);

    final records = await store.records();
    expect(records, hasLength(2));
    expect(
      records.singleWhere((record) => record.conceptKey == 'c1').completedCount,
      2,
    );
    expect(
      records.singleWhere((record) => record.conceptKey == 'c2').completedCount,
      1,
    );
  });

  test('壊れた値や未知versionを学習済みと誤認しない', () async {
    final backing = MemorySessionStore();
    final store = LocalPracticeStore(backing);

    for (final raw in [
      '{',
      '{"version":2,"records":[]}',
      '{"version":1,"records":[],"answer":"混ぜない"}',
      '{"version":1,"records":[{"unitId":"u","conceptKey":"c","completedCount":0,"lastCompletedAt":1}]}',
      '{"version":1,"records":[{"unitId":"u","conceptKey":"c","completedCount":1,"lastCompletedAt":1786290000000,"answer":"混ぜない"}]}',
      '{"version":1,"records":[{"unitId":"u","conceptKey":"c","completedCount":1,"lastCompletedAt":1786290000000},{"unitId":"u","conceptKey":"c","completedCount":1,"lastCompletedAt":1786290000000}]}',
    ]) {
      await backing.setSetting(LocalPracticeStore.settingKey, raw);
      expect(await store.records(), isEmpty, reason: raw);
    }
  });

  test('履歴を端末から削除できる', () async {
    final backing = MemorySessionStore();
    final store = LocalPracticeStore(backing);
    await store.recordCompletion(unitId: 'u', conceptKey: 'c');

    await store.clear();

    expect(await store.records(), isEmpty);
    expect(await backing.getSetting(LocalPracticeStore.settingKey), isNull);
  });
}
