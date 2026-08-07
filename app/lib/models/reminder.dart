/// 通知の文面と、送るかどうか。
///
/// ## 一次調査が存在しない領域
///
/// 通知の時刻・頻度・文面について、この製品が使える一次データは
/// **1つも見つかっていない**。Duolingo の bandit 最適化（DAU +0.5%）が
/// 唯一の数字だが、あれは大母集団での最適化の話で、
/// 何通送ってよいかの根拠にはならない。
///
/// 根拠が無いので、**増やす余地を作らず、下げる余地だけ持つ**。
/// Duolingo が通知を増やすのに CEO 承認を要求している事実は、
/// 「増やすのは特別な判断である」ことの外部証拠として使える
/// （増やしてよい根拠ではない）。
///
/// ## 主語は「進捗の事実」
///
/// AI キャラからの個人的なメッセージにしない。理由は3つ:
///
/// 1. 罪悪感で動かす設計は C5（報酬で釣らない）・C6（喪失で縛らない）の
///    思想と正面から衝突する
/// 2. 中高生に向けてキャラから個人的な文言を送ることは、保護者への説明で
///    擁護しにくい
/// 3. 「デキすぎ君が待っています」は**事実ではない**。
///    アプリが嘘を言うことになる
library;

/// 1日に送ってよい上限。**増やさない。**
const int kMaxNotificationsPerDay = 1;

/// 既定の時刻（時）。設定で変えられる。
const int kDefaultReminderHour = 20;

/// 通知に必要な材料。画面の状態をそのまま渡す。
class ReminderState {
  const ReminderState({
    required this.daysLeft,
    required this.remaining,
    required this.dueCount,
    required this.graceLeft,
    required this.doneToday,
    required this.restDay,
  });

  /// 考査まで。未設定なら null
  final int? daysLeft;

  /// まだ説明していない概念の数
  final int remaining;

  /// 見直す期限が来ている数
  final int dueCount;

  /// 今週の残り猶予
  final int graceLeft;

  final bool doneToday;

  /// 考査の前日・当日
  final bool restDay;
}

/// 送る文面。**送らないなら null。**
///
/// 送らない場合が多いのは意図的で、
/// 「毎日必ず届く」ではなく「用があるときだけ届く」を目指している。
String? reminderText(ReminderState s) {
  // 考査の前日と当日は送らない。**その日に学習アプリを開かせない**
  if (s.restDay) return null;

  // きょうの分が終わっている人に声をかけない。
  // 終わったのに通知が来るのは、見ていないと言われているのと同じ
  if (s.doneToday) return null;

  if (s.daysLeft case final left? when left >= 0 && s.remaining > 0) {
    return '考査まであと$left日。まだ説明していないところが${s.remaining}つあります。';
  }
  if (s.dueCount > 0) {
    return 'もう一度見るところが${s.dueCount}件あります。';
  }
  if (s.remaining > 0) {
    return 'まだ説明していないところが${s.remaining}つあります。';
  }
  // 猶予の残りは**それ単体では送らない**。
  // 「使わずに済ませる」ための情報であって、呼び出す理由ではない
  return null;
}

/// 通知の見出し。**アプリ名だけ。** 煽らない。
const String kReminderTitle = 'デキすぎ君';
