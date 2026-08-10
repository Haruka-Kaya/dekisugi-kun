import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/local_weekly_league_projection.dart';
import 'package:dekisugi/models/league_ladder.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef _StoreFactory = Future<SessionStore> Function();

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  for (final entry in <String, _StoreFactory>{
    'Memory': () async => MemorySessionStore(),
    'SQLite': () => SqfliteSessionStore.open(path: inMemoryDatabasePath),
  }.entries) {
    group('${entry.key} 端末手渡し週次League', () {
      late SessionStore store;

      setUp(() async => store = await entry.value());
      tearDown(() => store.close());

      test('実順位で最大±1段、同じ週の再送は一度しか確定しない', () async {
        await _beginWeek(store, weekKey: '2026-08-10', participantCount: 5);
        await _score(store, weekKey: '2026-08-10', slot: 1, sequence: 1);
        await _score(store, weekKey: '2026-08-10', slot: 1, sequence: 2);
        for (var slot = 2; slot <= 5; slot += 1) {
          await _score(store, weekKey: '2026-08-10', slot: slot, sequence: 1);
        }

        final first = await store.finalizeLearningLocalWeeklyLeague(
          weekKey: '2026-08-10',
          finalizedAt: DateTime(2026, 8, 17, 4),
        );
        expect(first.applied, isTrue);
        expect(first.week?.rank, 1);
        expect(first.week?.tied, isFalse);
        expect(first.week?.meaningfulEventCount, 2);
        expect(first.week?.previousTier, LanSocialLeagueTier.bronze);
        expect(first.week?.tier, LanSocialLeagueTier.silver);
        expect(first.week?.movement, LanSocialLeagueMovement.promoted);

        final replay = await store.finalizeLearningLocalWeeklyLeague(
          weekKey: '2026-08-10',
          finalizedAt: DateTime(2026, 8, 18, 12),
        );
        expect(
          replay.status,
          LearningLocalLeagueFinalizeStatus.alreadyFinalized,
        );
        expect(replay.applied, isFalse);
        expect(replay.week?.finalizedAt, first.week?.finalizedAt);
        expect(
          (await store.learningProgressSnapshot(
            LearningScope.personal,
          )).localLeagueHistory,
          hasLength(1),
        );

        await _beginWeek(store, weekKey: '2026-08-17', participantCount: 5);
        for (var slot = 2; slot <= 5; slot += 1) {
          await _score(store, weekKey: '2026-08-17', slot: slot, sequence: 1);
          await _score(store, weekKey: '2026-08-17', slot: slot, sequence: 2);
        }
        await _score(store, weekKey: '2026-08-17', slot: 1, sequence: 1);
        final second = await store.finalizeLearningLocalWeeklyLeague(
          weekKey: '2026-08-17',
          finalizedAt: DateTime(2026, 8, 24, 4),
        );
        expect(second.week?.rank, 5);
        expect(second.week?.previousTier, LanSocialLeagueTier.silver);
        expect(second.week?.tier, LanSocialLeagueTier.bronze);
        expect(second.week?.movement, LanSocialLeagueMovement.demoted);
      });

      test('5人未満と週終了前は履歴を作らない', () async {
        await _beginWeek(store, weekKey: '2026-08-10', participantCount: 4);
        final tooEarly = await store.finalizeLearningLocalWeeklyLeague(
          weekKey: '2026-08-10',
          finalizedAt: DateTime(2026, 8, 17, 3, 59),
        );
        expect(
          tooEarly.status,
          LearningLocalLeagueFinalizeStatus.weekInProgress,
        );
        final underMinimum = await store.finalizeLearningLocalWeeklyLeague(
          weekKey: '2026-08-10',
          finalizedAt: DateTime(2026, 8, 17, 4),
        );
        expect(
          underMinimum.status,
          LearningLocalLeagueFinalizeStatus.insufficientParticipants,
        );
        expect(
          (await store.learningProgressSnapshot(
            LearningScope.personal,
          )).localLeagueHistory,
          isEmpty,
        );
      });

      test('全員0件はrank null、同率1位はrankを残してどちらも据置', () async {
        await _beginWeek(store, weekKey: '2026-08-10', participantCount: 5);
        final empty = await store.finalizeLearningLocalWeeklyLeague(
          weekKey: '2026-08-10',
          finalizedAt: DateTime(2026, 8, 17, 4),
        );
        expect(empty.week?.rank, isNull);
        expect(empty.week?.tied, isFalse);
        expect(empty.week?.tier, LanSocialLeagueTier.bronze);
        expect(empty.week?.movement, LanSocialLeagueMovement.stayed);

        await _beginWeek(store, weekKey: '2026-08-17', participantCount: 5);
        await _score(store, weekKey: '2026-08-17', slot: 1, sequence: 1);
        await _score(store, weekKey: '2026-08-17', slot: 1, sequence: 2);
        await _score(store, weekKey: '2026-08-17', slot: 2, sequence: 1);
        await _score(store, weekKey: '2026-08-17', slot: 2, sequence: 2);
        for (var slot = 3; slot <= 5; slot += 1) {
          await _score(store, weekKey: '2026-08-17', slot: slot, sequence: 1);
        }
        final tied = await store.finalizeLearningLocalWeeklyLeague(
          weekKey: '2026-08-17',
          finalizedAt: DateTime(2026, 8, 24, 4),
        );
        expect(tied.week?.rank, 1);
        expect(tied.week?.tied, isTrue);
        expect(tied.week?.tier, LanSocialLeagueTier.bronze);
        expect(tied.week?.movement, LanSocialLeagueMovement.stayed);
      });

      test('2週休眠でも古い順に実順位を確定しtierを連鎖する', () async {
        await _beginWinningWeek(store, weekKey: '2026-08-03');
        await _beginWinningWeek(store, weekKey: '2026-08-10');

        final catchUp = await store.catchUpLearningLocalWeeklyLeagues(
          currentWeekKey: '2026-08-17',
          finalizedAt: DateTime(2026, 8, 17, 4),
        );

        expect(catchUp.appliedCount, 2);
        expect(catchUp.results.map((result) => result.week?.weekKey), [
          '2026-08-03',
          '2026-08-10',
        ]);
        final history =
            (await store.learningProgressSnapshot(
                LearningScope.personal,
              )).localLeagueHistory.toList()
              ..sort((left, right) => left.weekKey.compareTo(right.weekKey));
        expect(history.map((week) => week.previousTier), [
          LanSocialLeagueTier.bronze,
          LanSocialLeagueTier.silver,
        ]);
        expect(history.map((week) => week.tier), [
          LanSocialLeagueTier.silver,
          LanSocialLeagueTier.gold,
        ]);

        final replay = await store.catchUpLearningLocalWeeklyLeagues(
          currentWeekKey: '2026-08-17',
          finalizedAt: DateTime(2026, 8, 17, 4),
        );
        expect(replay.results, isEmpty);
        expect(replay.appliedCount, 0);
      });

      test('8週休眠を全週catch-upし、現在週は確定しない', () async {
        const endedWeeks = [
          '2026-08-03',
          '2026-08-10',
          '2026-08-17',
          '2026-08-24',
          '2026-08-31',
          '2026-09-07',
          '2026-09-14',
          '2026-09-21',
        ];
        for (final weekKey in endedWeeks) {
          await _beginWeek(store, weekKey: weekKey, participantCount: 5);
        }
        await _beginWeek(store, weekKey: '2026-09-28', participantCount: 5);

        final catchUp = await store.catchUpLearningLocalWeeklyLeagues(
          currentWeekKey: '2026-09-28',
          finalizedAt: DateTime(2026, 9, 28, 4),
        );

        expect(catchUp.appliedCount, endedWeeks.length);
        expect(
          catchUp.results.map((result) => result.week?.weekKey),
          endedWeeks,
        );
        final history = (await store.learningProgressSnapshot(
          LearningScope.personal,
        )).localLeagueHistory;
        expect(history, hasLength(endedWeeks.length));
        expect(history.any((week) => week.weekKey == '2026-09-28'), isFalse);
      });

      test('runの無い空週と2〜4人週は後続の実在5人週を塞がない', () async {
        await _beginWeek(store, weekKey: '2026-08-03', participantCount: 4);
        // 2026-08-10にはrunを作らない。
        await _beginWeek(store, weekKey: '2026-08-17', participantCount: 5);

        final catchUp = await store.catchUpLearningLocalWeeklyLeagues(
          currentWeekKey: '2026-08-24',
          finalizedAt: DateTime(2026, 8, 24, 4),
        );

        expect(catchUp.results, hasLength(2));
        expect(
          catchUp.results.first.status,
          LearningLocalLeagueFinalizeStatus.insufficientParticipants,
        );
        expect(catchUp.results.last.week?.weekKey, '2026-08-17');
        expect(catchUp.appliedCount, 1);
      });
    });
  }

  test('SQLite再起動後に8週休眠をcatch-upし、次の再起動でも冪等', () async {
    final temp = Directory.systemTemp.createTempSync('local-league-catch-up');
    addTearDown(() => temp.deleteSync(recursive: true));
    final path = p.join(temp.path, 'league.db');
    final first = await SqfliteSessionStore.open(path: path);
    const weeks = [
      '2026-08-03',
      '2026-08-10',
      '2026-08-17',
      '2026-08-24',
      '2026-08-31',
      '2026-09-07',
      '2026-09-14',
      '2026-09-21',
    ];
    for (final weekKey in weeks) {
      await _beginWeek(first, weekKey: weekKey, participantCount: 5);
    }
    await first.close();

    final second = await SqfliteSessionStore.open(path: path);
    final catchUp = await second.catchUpLearningLocalWeeklyLeagues(
      currentWeekKey: '2026-09-28',
      finalizedAt: DateTime(2026, 9, 28, 4),
    );
    expect(catchUp.appliedCount, weeks.length);
    await second.close();

    final third = await SqfliteSessionStore.open(path: path);
    addTearDown(third.close);
    final snapshot = await third.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.localLeagueHistory, hasLength(weeks.length));
    expect(
      (await third.catchUpLearningLocalWeeklyLeagues(
        currentWeekKey: '2026-09-28',
        finalizedAt: DateTime(2026, 9, 28, 4),
      )).results,
      isEmpty,
    );
  });

  test('SQLiteの途中insert失敗は全週をrollbackし、学習eventを失わない', () async {
    final temp = Directory.systemTemp.createTempSync(
      'local-league-catch-up-rollback',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final path = p.join(temp.path, 'league.db');
    final store = await SqfliteSessionStore.open(path: path);
    addTearDown(store.close);
    await _beginWinningWeek(store, weekKey: '2026-08-03');
    await _beginWinningWeek(store, weekKey: '2026-08-10');
    final db = await databaseFactory.openDatabase(path);
    addTearDown(db.close);
    await db.execute('''
      CREATE TRIGGER fail_second_league_week
      BEFORE INSERT ON learning_local_league_history
      WHEN NEW.week_key = '2026-08-10'
      BEGIN
        SELECT RAISE(ABORT, 'forced catch-up failure');
      END
    ''');

    await expectLater(
      store.catchUpLearningLocalWeeklyLeagues(
        currentWeekKey: '2026-08-17',
        finalizedAt: DateTime(2026, 8, 17, 4),
      ),
      throwsA(isA<DatabaseException>()),
    );
    var snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.localLeagueHistory, isEmpty);
    expect(snapshot.events, isNotEmpty);

    await db.execute('DROP TRIGGER fail_second_league_week');
    final retry = await store.catchUpLearningLocalWeeklyLeagues(
      currentWeekKey: '2026-08-17',
      finalizedAt: DateTime(2026, 8, 17, 4),
    );
    expect(retry.appliedCount, 2);
    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.localLeagueHistory, hasLength(2));
  });

  test('SQLite再起動後も10段tier履歴を復元し、氏名・回答列を持たない', () async {
    final temp = Directory.systemTemp.createTempSync('local-league-restart');
    addTearDown(() => temp.deleteSync(recursive: true));
    final path = p.join(temp.path, 'league.db');
    final first = await SqfliteSessionStore.open(path: path);
    await _beginWeek(first, weekKey: '2026-08-10', participantCount: 5);
    await _score(first, weekKey: '2026-08-10', slot: 1, sequence: 1);
    await _score(first, weekKey: '2026-08-10', slot: 1, sequence: 2);
    for (var slot = 2; slot <= 5; slot += 1) {
      await _score(first, weekKey: '2026-08-10', slot: slot, sequence: 1);
    }
    await first.finalizeLearningLocalWeeklyLeague(
      weekKey: '2026-08-10',
      finalizedAt: DateTime(2026, 8, 17, 4),
    );
    await first.close();

    final reopened = await SqfliteSessionStore.open(path: path);
    addTearDown(reopened.close);
    final snapshot = await reopened.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.localLeagueHistory, hasLength(1));
    expect(snapshot.currentLocalLeagueTier, LanSocialLeagueTier.silver);
    expect(snapshot.localLeagueHistory.single.participantCount, 5);

    final db = await databaseFactory.openDatabase(path);
    addTearDown(db.close);
    final columns = (await db.rawQuery(
      'PRAGMA table_info(learning_local_league_history)',
    )).map((row) => row['name'] as String).toSet();
    expect(
      columns,
      equals({
        'scope',
        'week_key',
        'meaningful_event_count',
        'rank',
        'tied',
        'participant_count',
        'previous_tier',
        'tier',
        'movement',
        'finalized_at',
      }),
    );
    expect(
      columns.where(
        (name) => RegExp(
          r'(name|answer|response|transcript|audio|voice|selection|participant_id)',
          caseSensitive: false,
        ).hasMatch(name),
      ),
      isEmpty,
    );
  });
}

Future<void> _beginWeek(
  SessionStore store, {
  required String weekKey,
  required int participantCount,
}) => store.beginLearningLocalCoopRun(
  LearningLocalCoopRunCommand(
    runId: 'league:$weekKey:r1',
    participantIds: {
      for (var slot = 1; slot <= participantCount; slot += 1)
        'league:$weekKey:slot:$slot',
    },
    target: participantCount,
    rewardGems: 0,
    startDay: weekKey,
    endDay: _plusDays(weekKey, 6),
    definitionVersion: LocalWeeklyLeagueProjection.definitionVersion,
    startedAt: DateTime.parse('${weekKey}T04:01:00Z'),
  ),
);

Future<void> _beginWinningWeek(
  SessionStore store, {
  required String weekKey,
}) async {
  await _beginWeek(store, weekKey: weekKey, participantCount: 5);
  await _score(store, weekKey: weekKey, slot: 1, sequence: 1);
  await _score(store, weekKey: weekKey, slot: 1, sequence: 2);
  for (var slot = 2; slot <= 5; slot += 1) {
    await _score(store, weekKey: weekKey, slot: slot, sequence: 1);
  }
}

Future<void> _score(
  SessionStore store, {
  required String weekKey,
  required int slot,
  required int sequence,
}) async {
  final suffix = weekKey.replaceAll('-', '');
  final eventId = 'event.$suffix.slot.$slot.$sequence';
  final occurredAt = DateTime.parse(
    '${weekKey}T06:00:00Z',
  ).add(Duration(minutes: slot * 10 + sequence));
  await store.commitLearningEvent(
    LearningEventCommand(
      eventId: eventId,
      scope: LearningScope.personal,
      origin: LearningOrigin.path,
      courseId: 'course.jhs-science',
      nodeId: 'node.$suffix.$slot.$sequence',
      activityId: 'activity.$suffix.$slot.$sequence',
      skillIds: {'skill.$suffix.$slot.$sequence'},
      activityKind: LearningActivityKind.transfer,
      outcome: LearningAttemptOutcome.structuredSuccess,
      evidence: LearningEvidenceLevel.transfer,
      contentVersion: 'catalog.v1',
      learningDay: weekKey,
      occurredAt: occurredAt,
    ),
  );
  await store.contributeLearningLocalCoopRun(
    'league:$weekKey:r1',
    contributionId: 'contribution.$suffix.$slot.$sequence',
    participantId: 'league:$weekKey:slot:$slot',
    eventId: eventId,
    occurredAt: occurredAt.add(const Duration(seconds: 1)),
  );
}

String _plusDays(String day, int amount) {
  final date = DateTime.parse('${day}T00:00:00Z').add(Duration(days: amount));
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
