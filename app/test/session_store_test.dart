import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/review.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

List<Utterance> turns(int n) => [
  for (var i = 1; i <= n; i++)
    Utterance(
      id: 'u${i.toString().padLeft(2, '0')}',
      isStudent: i.isEven,
      text: '発話$i',
    ),
];

Dossier dossier({int coverage = 30}) => Dossier.fromJson({
  'unitId': 'force-motion',
  'coverage': coverage,
  'slots': [
    {
      'key': 'fall',
      'label': '落下の速さ',
      'status': 'thin',
      'content': 'x',
      'evidence': ['u02'],
      'followUpHint': '',
      'probes': const [],
    },
  ],
});

void main() {
  late SessionStore store;

  setUp(() => store = MemorySessionStore());
  tearDown(() => store.close());

  group('中断と再開', () {
    test('保存した会話を終わっていないものとして拾える', () async {
      final id = await store.startSession('force-motion');
      await store.saveProgress(id, transcript: turns(4), dossier: dossier());

      final saved = await store.unfinished();
      expect(saved, isNotNull);
      expect(saved!.id, id);
      expect(saved.transcript, hasLength(4));
      expect(saved.dossier?.coverage, 30);
    });

    test('終わった会話は再開の候補にしない', () async {
      final id = await store.startSession('force-motion');
      await store.saveProgress(id, transcript: turns(2));
      await store.finishSession(id);
      expect(await store.unfinished(), isNull);
    });

    test('発話が無い会話は「続きから」と聞かない', () async {
      // 起動してすぐ閉じただけのものを毎回出すと邪魔になる
      await store.startSession('force-motion');
      expect(await store.unfinished(), isNull);
    });

    test('1ターンごとに上書きしても壊れない', () async {
      // OS に殺される前提なので、毎ターン丸ごと書く
      final id = await store.startSession('force-motion');
      for (var n = 1; n <= 5; n++) {
        await store.saveProgress(id, transcript: turns(n));
      }
      final saved = await store.unfinished();
      expect(saved!.transcript, hasLength(5));
    });

    test('新しい方を再開の候補にする', () async {
      final a = await store.startSession('force-motion');
      await store.saveProgress(a, transcript: turns(2));
      final b = await store.startSession('force-motion');
      await store.saveProgress(b, transcript: turns(3));

      expect((await store.unfinished())!.id, b);
    });
  });

  group('復習の記録', () {
    ReviewItem item(String key, {ReviewReason reason = ReviewReason.thin}) =>
        ReviewItem(
          unitId: 'force-motion',
          conceptKey: key,
          label: key,
          reason: reason,
          lastSeen: DateTime(2026, 8, 5),
        );

    test('積んで読み出せる', () async {
      await store.upsertReviews([item('fall'), item('inertia')]);
      expect(
        (await store.reviewItems()).map((r) => r.conceptKey),
        containsAll(['fall', 'inertia']),
      );
    });

    test('同じ概念は上書きする（同じものが増えない）', () async {
      await store.upsertReviews([item('fall')]);
      await store.upsertReviews([
        item('fall', reason: ReviewReason.notCorrected),
      ]);

      final all = await store.reviewItems();
      expect(all, hasLength(1));
      expect(all.single.reason, ReviewReason.notCorrected);
    });

    test('覚えたら消える', () async {
      await store.upsertReviews([item('fall'), item('inertia')]);
      await store.clearReview('force-motion', 'fall');
      expect((await store.reviewItems()).map((r) => r.conceptKey), ['inertia']);
    });
  });

  group('考査日', () {
    test('保存して読み出せる', () async {
      final d = DateTime(2026, 9, 1);
      await store.setExamDate(d);
      expect(await store.examDate(), d);
    });

    test('消せる', () async {
      await store.setExamDate(DateTime(2026, 9, 1));
      await store.setExamDate(null);
      expect(await store.examDate(), isNull);
    });
  });

  group('逐語の復元', () {
    test('壊れた JSON でも落とさず空を返す', () {
      // 記録が読めないより、欠けても開く方がまし
      expect(decodeTranscript('{ぐちゃぐちゃ'), isEmpty);
      expect(decodeTranscript('null'), isEmpty);
      expect(decodeTranscript('{"a":1}'), isEmpty);
      expect(decodeTranscript(null), isEmpty);
    });

    test('要素が壊れていても読める分だけ返す', () {
      final got = decodeTranscript(
        '[{"id":"u01","speaker":"student","text":"a"},'
        '{"speaker":"ai","text":"IDが無い"},'
        '"ごみ"]',
      );
      expect(got, hasLength(1));
      expect(got.single.id, 'u01');
      expect(got.single.isStudent, isTrue);
    });

    test('校正結果を残す', () {
      final got = decodeTranscript(
        '[{"id":"u01","speaker":"student","text":"茶道水","corrected":"砂糖水"}]',
      );
      expect(got.single.display, '砂糖水');
      expect(got.single.text, '茶道水', reason: '生の文字起こしが消えている');
    });

    test('challengeの印が壊れていても発話本体を失わない', () {
      final got = decodeTranscript(
        '[{"id":"u01","speaker":"ai","text":"質問",'
        '"challengeLureId":42,"challengeLureText":42}]',
      );

      expect(got.single.text, '質問');
      expect(got.single.challengeLureId, isNull);
      expect(got.single.challengeLureText, isNull);
    });

    test('challenge検証に使った固定本文を残す', () {
      final got = decodeTranscript(
        '[{"id":"u01","speaker":"ai","text":"固定文",'
        '"challengeLureId":"M01","challengeLureText":"固定文"}]',
      );

      expect(got.single.challengeLureId, 'M01');
      expect(got.single.challengeLureText, '固定文');
    });
  });
}
