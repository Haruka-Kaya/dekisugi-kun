import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef StoreFactory = Future<SessionStore> Function();

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  for (final entry in <String, StoreFactory>{
    'Memory': () async => MemorySessionStore(),
    'SQLite': () => SqfliteSessionStore.open(path: inMemoryDatabasePath),
  }.entries) {
    group('${entry.key} LAN friends reward contract', () {
      late SessionStore store;

      setUp(() async => store = await entry.value());
      tearDown(() => store.close());

      test('room単位で固定1結晶だけを冪等付与する', () async {
        const roomId = 'aaaaaaaaaaaaaaaaaaaaaaaa';
        final before = await store.learningProgressSnapshot(
          LearningScope.personal,
        );
        final first = await store.grantLearningLanFriendsReward(
          roomId: roomId,
          completedAt: DateTime.utc(2026, 8, 10, 3),
        );
        final replay = await store.grantLearningLanFriendsReward(
          roomId: roomId,
          completedAt: DateTime.utc(2026, 8, 11, 4),
        );
        final after = await store.learningProgressSnapshot(
          LearningScope.personal,
        );

        expect(first.applied, isTrue);
        expect(replay.applied, isFalse);
        expect(replay.reward.entryId, first.reward.entryId);
        expect(after.wallet.gems, before.wallet.gems + 1);
        expect(after.wallet.xp, before.wallet.xp);
        expect(after.events, hasLength(before.events.length));
        expect(after.nodes, hasLength(before.nodes.length));
        expect(after.days, hasLength(before.days.length));
        expect(after.quests, hasLength(before.quests.length));
        expect(after.rewards, hasLength(before.rewards.length + 1));
        final reward = after.rewards.single;
        expect(reward.type, LearningRewardType.gems);
        expect(reward.amount, 1);
        expect(reward.reason, 'lan-friends.v1:$roomId');
        expect(reward.sourceEventId, isNull);
      });

      test('room IDと時刻を狭く検証し任意報酬の入口にしない', () async {
        expect(
          () => store.grantLearningLanFriendsReward(
            roomId: 'student-name',
            completedAt: DateTime.utc(2026, 8, 10),
          ),
          throwsArgumentError,
        );
        expect(
          () => store.grantLearningLanFriendsReward(
            roomId: 'b' * 24,
            completedAt: DateTime.fromMillisecondsSinceEpoch(-1),
          ),
          throwsArgumentError,
        );
      });
    });
  }

  test('SQLite再起動後のrefreshでも同じroomを二重付与しない', () async {
    final directory = Directory.systemTemp.createTempSync(
      'dekisugi-lan-reward-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = p.join(directory.path, 'reward.db');
    final first = await SqfliteSessionStore.open(path: path);
    await first.grantLearningLanFriendsReward(
      roomId: 'c' * 24,
      completedAt: DateTime.utc(2026, 8, 10),
    );
    await first.close();

    final reopened = await SqfliteSessionStore.open(path: path);
    addTearDown(reopened.close);
    final replay = await reopened.grantLearningLanFriendsReward(
      roomId: 'c' * 24,
      completedAt: DateTime.utc(2026, 8, 12),
    );
    final snapshot = await reopened.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(replay.applied, isFalse);
    expect(snapshot.wallet.gems, 1);
    expect(snapshot.rewards, hasLength(1));
  });
}
