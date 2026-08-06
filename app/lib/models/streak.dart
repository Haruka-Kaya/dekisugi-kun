import 'dart:math' as math;

import 'day_key.dart';

/// 継続の記録と、そこから数える連続日数。
///
/// ## streak を主役にしない
///
/// Duolingo の streak 14日保持率は、**高校生年代が全年齢中最低の 55%**
/// （50代は 79%）。日本全体は世界1位の 80% 超なのに、
/// **狙っている層にだけ効かない**。
///
/// だから中核は「考査日からの逆算」と「チームの合計」に置き、
/// これは画面の最下部に小さく出す補助にとどめる。
///
/// ## 保存しない
///
/// 連続日数を DB に持つと、日付をまたぐたびに更新する処理が要り、
/// 端末の時計を変えられたときに不整合が残る。
/// **日ごとの記録だけを持ち、連続日数は毎回この関数で数える。**

/// 1週間に配る猶予の枚数。
///
/// 部活で潰れる日が週2日ある前提に合わせている。
/// 1枚だと構造的に毎週切れる生徒が出て、3枚以上だと
/// 「7日のうち4日」で連続と呼べなくなる。
///
/// 月曜の午前4時に戻る。**繰り越さない**（貯めて長期の穴埋めに使わせない）。
const int kGracePerWeek = 2;

/// 抜けた1日で失う日数の上限。
const int kMissPenaltyDays = 7;

/// 1日の記録。**「きょうの1件」を終えたかどうか**が連続の判定に使われる。
class DayRecord {
  const DayRecord({
    required this.day,
    this.sessions = 0,
    this.done = 0,
    this.textTurns = 0,
  });

  /// `YYYY-MM-DD`（[dayKeyOf] で作る。境目は午前4時）
  final String day;

  /// その日に会話した回数
  final int sessions;

  /// その日に片づけた「きょうの1件」の数。
  ///
  /// 新しい概念でも、期限が来た復習でもよい。
  ///
  /// > [!warning] 「会話を開いた」を条件にしない
  /// > 行動の中身と無関係な達成が積み上がるのは、
  /// > C5 が禁じている従事随伴報酬そのもの（内発動機を d = −0.40 で毀損）。
  ///
  /// > [!warning] 「新しい概念」だけにもしない
  /// > 教材は3単元8節しかないので、8個を使い切った時点で
  /// > **誰も連続を続けられなくなる**。
  final int done;

  /// 文字で送った回数。音声を使えない生徒の割合を後で見るために取る
  final int textTurns;

  bool get accomplished => done > 0;
}

/// 言えるようになったこと1件。
///
/// **これが報酬の本体**（C5）。
///
/// C5 の下では、行動と切り離された報酬（ポイント・XP・レベル）を
/// 主動線に置けない。従事随伴報酬は内発動機を d = −0.40 で毀損する。
/// 出せるのは**行動の成果そのもの**で、この製品ではそれが
/// 「生徒が自分の言葉で言えた内容」になる。
///
/// 積み上がるのが XP ではなく**自分が言った文**なので、
/// 既存のループ（教える）に直結し、外的報酬としては働かない。
class ExplainedItem {
  const ExplainedItem({
    required this.unitId,
    required this.conceptKey,
    required this.label,
    required this.said,
    required this.at,
  });

  final String unitId;
  final String conceptKey;

  /// 概念の名前（「落下の速さ」）
  final String label;

  /// **生徒自身の説明**（校正済み）。ここが主役
  final String said;

  final DateTime at;

  Map<String, Object?> toRow() => {
        'unit_id': unitId,
        'concept_key': conceptKey,
        'label': label,
        'said': said,
        'at': at.millisecondsSinceEpoch,
      };

  factory ExplainedItem.fromRow(Map<String, Object?> row) => ExplainedItem(
        unitId: row['unit_id'] as String? ?? '',
        conceptKey: row['concept_key'] as String? ?? '',
        label: row['label'] as String? ?? '',
        said: row['said'] as String? ?? '',
        at: DateTime.fromMillisecondsSinceEpoch((row['at'] as int?) ?? 0),
      );
}

/// 画面に出す継続の状態。
class StreakView {
  const StreakView({
    required this.days,
    required this.graceLeft,
    required this.doneToday,
    required this.restDay,
  });

  /// 連続日数
  final int days;

  /// 今週あと何枚猶予が残っているか。
  ///
  /// **必ず画面に出す。** Sharif & Shu 2021 が示したのは
  /// 「使わずに済ませること自体が動機になる」という働きなので、
  /// 残っていることが見えていないと機能しない。
  final int graceLeft;

  /// きょうの1件が終わっているか
  final bool doneToday;

  /// きょうは停止日（考査の前日・当日）か
  final bool restDay;

  int get graceTotal => kGracePerWeek;
}

/// 1日抜けたあとの連続日数。
///
/// **ゼロには戻さない**（C6）。L@S 2022 は 110日 streak を失って
/// アカウントごと放棄した例を記録している。
/// 積み上げが一瞬で無になることの破壊力は、継続の動機を上回る。
///
/// > [!note] 下限を 1 ではなく 0 にした理由
/// > 計画では `max(1, n - 7)` としていたが、それだと
/// > **1か月来ていない生徒にも「1日つづけています」と表示されてしまう**。
/// > 事実でないことを画面が言うことになるので、0 まで落ちられるようにした。
/// > 1日の抜けが 110 → 103 で済むという C6 の要求は満たしている。
int streakAfterMiss(int current) =>
    math.max(0, current - kMissPenaltyDays);

/// 考査の前日と当日。**欠席にも成立にも数えない。**
///
/// 考査当日に学習アプリを開かせる設計にしない。
/// かといって「開かなかった」を抜けとして数えるのも理不尽なので、
/// その日は無かったことにする。
bool isRestDay(String day, DateTime? examDate) {
  if (examDate == null) return false;
  final exam = dayKeyOf(examDate);
  return day == exam || day == shiftDay(exam, -1);
}

/// 日ごとの記録から連続日数を数える。
///
/// [records] は順不同でよい。欠けている日は「やらなかった日」として扱う。
StreakView computeStreak({
  required Iterable<DayRecord> records,
  required DateTime now,
  DateTime? examDate,
}) {
  final today = dayKeyOf(now);
  final byDay = {for (final r in records) r.day: r};
  final doneToday = byDay[today]?.accomplished ?? false;
  final restToday = isRestDay(today, examDate);

  if (byDay.isEmpty) {
    return StreakView(
      days: 0,
      graceLeft: kGracePerWeek,
      doneToday: false,
      restDay: restToday,
    );
  }

  // 一番古い記録から今日まで、前へ歩く。
  // 後ろ向きに歩くと「抜けたときに何日ぶん引くか」を決めるのに
  // その前の連続日数が要り、再帰になる
  var day = byDay.keys.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  if (daysBetweenKeys(day, today) < 0) day = today;

  var streak = 0;
  final usedByWeek = <String, int>{};

  while (daysBetweenKeys(day, today) >= 0) {
    if (isRestDay(day, examDate)) {
      day = shiftDay(day, 1);
      continue;
    }
    if (byDay[day]?.accomplished ?? false) {
      streak++;
    } else if (day == today) {
      // **きょうはまだ終わっていないだけ。** ここで切ると、
      // 朝アプリを開いた瞬間に連続が減って見える
      break;
    } else {
      final week = weekKeyOf(day);
      final used = usedByWeek[week] ?? 0;
      if (used < kGracePerWeek) {
        // 猶予で埋める。連続は増えないが切れもしない
        usedByWeek[week] = used + 1;
      } else {
        streak = streakAfterMiss(streak);
      }
    }
    day = shiftDay(day, 1);
  }

  final usedThisWeek = usedByWeek[weekKeyOf(today)] ?? 0;
  return StreakView(
    days: streak,
    graceLeft: math.max(0, kGracePerWeek - usedThisWeek),
    doneToday: doneToday,
    restDay: restToday,
  );
}
