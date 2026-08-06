import 'package:dekisugi/models/dossier.dart';
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
    }) =>
        ReviewItem(
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
        await store.upsertReviews(
            [item(label: '落ちる速さ', reason: ReviewReason.thin)]);

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

      test('逐語が残っていれば再開できる', () async {
        final id = await store.startSession('force-motion');
        await store.saveProgress(id, transcript: [
          const Utterance(id: 'u1', isStudent: true, text: '重いほうが速く落ちる'),
        ]);

        final saved = await store.unfinished();
        expect(saved?.transcript.single.text, '重いほうが速く落ちる');

        await store.finishSession(id);
        expect(await store.unfinished(), isNull);
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

        expect((await store.days()).map((d) => d.day).toList(),
            ['2026-08-06', '2026-08-05', '2026-08-04']);
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
            said('fall', '空気の抵抗を無視すれば重さによらない', DateTime(2026, 8, 6)));
        final e = (await store.explained()).single;
        expect(e.said, '空気の抵抗を無視すれば重さによらない');
        expect(e.conceptKey, 'fall');
      });

      test('同じ概念は最後の1件だけ残る', () async {
        // 言い直すたびに増えると、積み上がった数が水増しになる
        await store.recordExplained(said('fall', '古い説明', DateTime(2026, 8, 5)));
        await store.recordExplained(said('fall', '新しい説明', DateTime(2026, 8, 6)));
        final all = await store.explained();
        expect(all, hasLength(1));
        expect(all.single.said, '新しい説明');
      });

      test('新しい順に返る', () async {
        await store.recordExplained(said('a', 'A', DateTime(2026, 8, 4)));
        await store.recordExplained(said('c', 'C', DateTime(2026, 8, 6)));
        await store.recordExplained(said('b', 'B', DateTime(2026, 8, 5)));
        expect((await store.explained()).map((e) => e.said).toList(),
            ['C', 'B', 'A']);
      });

      test('記録が無ければ空', () async {
        expect(await store.explained(), isEmpty);
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
