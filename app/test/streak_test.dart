import 'package:dekisugi/models/day_key.dart';
import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/streak.dart';
import 'package:flutter_test/flutter_test.dart';

/// **C6 — streak を「1日抜けたらゼロ」にしない。猶予枠は残数を明示して配る。**
///
/// 根拠: Sharif & Shu 2021。猶予は失敗後の離脱を減らすが、
/// **「使わずに済ませる」ことが動機になる**ので残数の明示が要る。
/// L@S 2022 は110日 streak を失ってアカウントごと放棄した例を記録している。
void main() {
  // 2026-08-06 は木曜
  DateTime at(int day, {int hour = 12}) => DateTime(2026, 8, day, hour);
  String key(int day) => dayKeyOf(at(day));

  DayRecord done(int day, {int n = 1}) => DayRecord(day: key(day), done: n);
  DayRecord opened(int day) => DayRecord(day: key(day), sessions: 1);

  group('日の境目は午前4時', () {
    test('午前3時はまだ前の日', () {
      // 0時で切ると、23時50分から日をまたいだ生徒が
      // 「10分で2日ぶん」か「2日ぶんやって1日」のどちらかになる
      expect(dayKeyOf(DateTime(2026, 8, 6, 3, 59)), '2026-08-05');
      expect(dayKeyOf(DateTime(2026, 8, 6, 4, 0)), '2026-08-06');
      expect(dayKeyOf(DateTime(2026, 8, 5, 23, 50)), '2026-08-05');
    });

    test('日をまたいでも同じ勉強は1日ぶん', () {
      expect(dayKeyOf(DateTime(2026, 8, 5, 23, 50)),
          dayKeyOf(DateTime(2026, 8, 6, 0, 10)));
    });

    test('週は月曜はじまり', () {
      // 2026-08-06 は木曜、その週の月曜は 08-03
      expect(weekKeyOf('2026-08-06'), '2026-08-03');
      expect(weekKeyOf('2026-08-03'), '2026-08-03');
      expect(weekKeyOf('2026-08-09'), '2026-08-03'); // 日曜
      expect(weekKeyOf('2026-08-10'), '2026-08-10'); // 次の月曜
    });
  });

  group('連続日数', () {
    test('記録が無ければ0', () {
      final v = computeStreak(records: const [], now: at(6));
      expect(v.days, 0);
      expect(v.graceLeft, kGracePerWeek);
      expect(v.doneToday, isFalse);
    });

    test('続けたぶんだけ増える', () {
      final v = computeStreak(
        records: [done(3), done(4), done(5), done(6)],
        now: at(6),
      );
      expect(v.days, 4);
      expect(v.doneToday, isTrue);
    });

    test('きょうがまだでも減らない', () {
      // 朝アプリを開いた瞬間に連続が減って見えると、その日でやめる
      final v = computeStreak(records: [done(4), done(5)], now: at(6));
      expect(v.days, 2);
      expect(v.doneToday, isFalse);
    });

    test('会話しただけでは連続しない（C5）', () {
      // 「会話を開いた」を条件にすると、行動の中身と無関係な達成が積み上がる。
      // それは従事随伴報酬そのもので、内発動機を d = −0.40 で毀損する
      final v = computeStreak(records: [done(4), opened(5), done(6)], now: at(6));
      expect(v.days, 2, reason: '開いただけの日を数えている');
    });

    test('同じ日に何件やっても1日ぶん', () {
      final a = computeStreak(records: [done(5), done(6)], now: at(6));
      final b = computeStreak(records: [done(5), done(6, n: 5)], now: at(6));
      expect(a.days, b.days);
    });
  });

  group('猶予枠', () {
    test('1日抜けても切れない', () {
      final v = computeStreak(records: [done(3), done(4), done(6)], now: at(6));
      expect(v.days, 3, reason: '抜けた日は猶予で埋まる');
      expect(v.graceLeft, kGracePerWeek - 1);
    });

    test('残数が分かる', () {
      // Sharif & Shu 2021 が示したのは「使わずに済ませること自体が動機になる」
      // という働きなので、残っていることが見えていないと機能しない
      final v = computeStreak(records: [done(3), done(6)], now: at(6));
      expect(v.graceLeft, kGracePerWeek - 2);
      expect(v.graceTotal, kGracePerWeek);
    });

    test('使い切ったら連続が減る（ただしゼロにはしない）', () {
      // 08-03(月) から。04,05,06 を3日抜け、猶予は2枚しかない
      final v = computeStreak(records: [done(3), done(7)], now: at(7));
      expect(v.days, lessThan(2));
      expect(v.graceLeft, 0);
    });

    test('週をまたぐと戻る', () {
      // 08-03〜09 が1週目、08-10 から次の週
      final v = computeStreak(
        records: [done(3), done(6), done(10)], // 04,05 を猶予で埋める
        now: at(10),
      );
      expect(v.graceLeft, kGracePerWeek, reason: '週が変われば猶予は戻る');
    });

    test('繰り越さない', () {
      // 先週まったく使わなくても、今週使えるのは2枚まで
      final v = computeStreak(
        records: [done(3), done(4), done(5), done(6), done(7), done(8), done(9)],
        now: at(10),
      );
      expect(v.graceLeft, kGracePerWeek);
    });
  });

  group('切れたときに失うもの', () {
    test('ゼロには戻さない（C6）', () {
      // 110日を一瞬で失うのは、継続の動機を上回る破壊力がある
      expect(streakAfterMiss(110), 110 - kMissPenaltyDays);
      expect(streakAfterMiss(110), 103);
      expect(streakAfterMiss(20), 13);
    });

    test('もともと短ければ0まで落ちる', () {
      // 1か月来ていない生徒に「1日つづけています」と出すのは事実に反する
      expect(streakAfterMiss(3), 0);
      expect(streakAfterMiss(0), 0);
    });

    test('引くだけで、負にはならない', () {
      for (var n = 0; n < 200; n++) {
        expect(streakAfterMiss(n), greaterThanOrEqualTo(0));
        expect(streakAfterMiss(n), lessThanOrEqualTo(n));
      }
    });
  });

  group('考査の前日と当日は停止日', () {
    test('やらなくても抜けにならない', () {
      // 考査当日に学習アプリを開かせる設計にしない
      final exam = at(6);
      final v = computeStreak(
        records: [done(3), done(4)], // 05(前日) と 06(当日) は空
        now: at(6),
        examDate: exam,
      );
      expect(v.days, 2);
      expect(v.graceLeft, kGracePerWeek, reason: '停止日で猶予を減らしている');
      expect(v.restDay, isTrue);
    });

    test('停止日にやっても連続は増えない', () {
      final exam = at(6);
      final a = computeStreak(
          records: [done(3), done(4)], now: at(6), examDate: exam);
      final b = computeStreak(
          records: [done(3), done(4), done(5), done(6)],
          now: at(6),
          examDate: exam);
      expect(b.days, a.days, reason: '停止日は無かったことにする');
    });
  });

  group('newlyExplained', () {
    Dossier d(Map<String, bool> explained) => Dossier(
          unitId: 'force-motion',
          coverage: 0,
          slots: [
            for (final e in explained.entries)
              Slot(
                key: e.key,
                label: e.key,
                status: e.value ? SlotStatus.explained : SlotStatus.thin,
                content: '',
                evidence: const ['u1'],
                followUpHint: '',
                probes: const [],
              ),
          ],
        );

    test('上がった概念だけを返す', () {
      final before = d({'fall': false, 'inertia': true});
      final after = d({'fall': true, 'inertia': true});
      expect(newlyExplained(before, after), {'fall'});
    });

    test('すでに説明できていたものは数えない', () {
      // 同じ概念を何度説明しても積み上がると、水増しが構造的に可能になる
      final same = d({'fall': true});
      expect(newlyExplained(same, same), isEmpty);
    });

    test('根拠が無ければ説明できたと見なさない', () {
      final after = Dossier(
        unitId: 'u',
        coverage: 0,
        slots: const [
          Slot(
            key: 'fall',
            label: 'fall',
            status: SlotStatus.explained,
            content: '',
            evidence: [], // 根拠なし
            followUpHint: '',
            probes: [],
          ),
        ],
      );
      expect(newlyExplained(null, after), isEmpty);
    });

    test('最初のカルテでも数えられる', () {
      expect(newlyExplained(null, d({'fall': true})), {'fall'});
    });
  });
}
