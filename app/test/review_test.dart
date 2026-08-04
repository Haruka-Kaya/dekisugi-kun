import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/review.dart';
import 'package:flutter_test/flutter_test.dart';

Dossier dossierWith(List<Map<String, dynamic>> slots) => Dossier.fromJson({
      'unitId': 'force-motion',
      'coverage': 0,
      'slots': slots,
    });

Map<String, dynamic> slot({
  required String key,
  String status = 'explained',
  List<String> evidence = const ['u02'],
  List<Map<String, dynamic>> probes = const [],
}) =>
    {
      'key': key,
      'label': key,
      'status': status,
      'content': 'x',
      'evidence': evidence,
      'followUpHint': '',
      'probes': probes,
    };

final _now = DateTime(2026, 8, 5, 12);

void main() {
  group('復習に回すもの', () {
    test('訂正できなかった概念を含む', () {
      final d = dossierWith([
        slot(key: 'fall', probes: [
          {'id': 'M01', 'result': 'accepted', 'evidence': ['u04']}
        ])
      ]);
      final items = reviewItemsOf(d, _now);
      expect(items, hasLength(1));
      expect(items.single.reason, ReviewReason.notCorrected);
    });

    test('説明が薄いままの概念を含む', () {
      final items = reviewItemsOf(dossierWith([slot(key: 'fall', status: 'thin')]), _now);
      expect(items.single.reason, ReviewReason.thin);
    });

    test('unclear は含めない', () {
      // 判断がついていないものを「できていない」側に置くと、
      // 触れてもいないことを突きつけることになる
      final d = dossierWith([
        slot(key: 'fall', probes: [
          {'id': 'M01', 'result': 'unclear', 'evidence': <String>[]}
        ])
      ]);
      expect(reviewItemsOf(d, _now), isEmpty);
    });

    test('触れていない概念を含めない', () {
      // 「まだ」と「できなかった」は別物
      final d = dossierWith([slot(key: 'fall', status: 'untouched', evidence: [])]);
      expect(reviewItemsOf(d, _now), isEmpty);
    });

    test('説明できた概念を含めない', () {
      expect(reviewItemsOf(dossierWith([slot(key: 'fall')]), _now), isEmpty);
    });
  });

  group('復習の理由の文言', () {
    test('責める言い方をしない', () {
      // 「弱点」「間違い」「できていない」を出さない（C9）
      for (final r in ReviewReason.values) {
        for (final bad in ['弱点', '間違', 'できていない', 'ダメ']) {
          expect(r.label.contains(bad), isFalse, reason: '$r に「$bad」が入っている');
        }
      }
    });
  });

  group('nextGap — 考査日からの逆算', () {
    // 確かなのは「保持したい期間に応じて伸びる」という方向だけ（Cepeda 2006）。
    // 比率そのものは未検証なので、単調性と境界だけを縛る。

    test('考査が遠いほど間隔が伸びる', () {
      Duration g(int days) => nextGap(
            now: _now,
            examDate: _now.add(Duration(days: days)),
            timesSeen: 0,
          );
      expect(g(7) <= g(30), isTrue);
      expect(g(30) <= g(90), isTrue);
      expect(g(7) < g(90), isTrue, reason: '保持期間で変わっていない');
    });

    test('考査当日・過ぎているなら1日', () {
      expect(nextGap(now: _now, examDate: _now, timesSeen: 0),
          const Duration(days: 1));
      expect(
          nextGap(
              now: _now,
              examDate: _now.subtract(const Duration(days: 3)),
              timesSeen: 0),
          const Duration(days: 1));
    });

    test('間隔が0日にならない', () {
      for (final d in [2, 3, 5]) {
        final gap = nextGap(
            now: _now, examDate: _now.add(Duration(days: d)), timesSeen: 0);
        expect(gap.inDays, greaterThanOrEqualTo(1));
      }
    });

    test('考査までに1回は回ってくる', () {
      // 間隔が保持期間を超えると、復習が考査の後になる
      for (final d in [7, 14, 30, 60, 200]) {
        final gap = nextGap(
            now: _now, examDate: _now.add(Duration(days: d)), timesSeen: 0);
        expect(gap.inDays, lessThan(d), reason: '$d日先の考査に間に合わない');
      }
    });

    test('考査日が無ければ回数で伸ばす', () {
      final gaps = [
        for (var i = 0; i < 5; i++) nextGap(now: _now, timesSeen: i).inDays
      ];
      expect(gaps, [1, 3, 7, 14, 30]);
    });

    test('回数が階段を超えても落ちない', () {
      expect(nextGap(now: _now, timesSeen: 99).inDays, 30);
      expect(nextGap(now: _now, timesSeen: -5).inDays, 1);
    });
  });

  group('ReviewItem の往復', () {
    test('行にして戻せる', () {
      final item = ReviewItem(
        unitId: 'force-motion',
        conceptKey: 'fall',
        label: '落下の速さ',
        reason: ReviewReason.notCorrected,
        lastSeen: _now,
      );
      final back = ReviewItem.fromRow(item.toRow());
      expect(back.conceptKey, 'fall');
      expect(back.label, '落下の速さ');
      expect(back.reason, ReviewReason.notCorrected);
      expect(back.lastSeen, _now);
    });

    test('知らない理由は thin に落とす（notCorrected に落とさない）', () {
      // notCorrected は「訂正できなかった」という強い主張
      expect(ReviewReason.parse('???'), ReviewReason.thin);
      expect(ReviewReason.parse(null), ReviewReason.thin);
    });
  });
}
