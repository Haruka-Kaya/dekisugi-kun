/// 「その日」の境目。
///
/// **午前0時では切らない。**
///
/// 0時ちょうどで切ると、23時50分から日をまたいで説明した生徒が
/// 「2日ぶんやったのに連続が1日ぶんしか付かない」か、
/// 逆に「10分で2日ぶん付く」かのどちらかになる。
/// どちらも本人の実感と合わない。
///
/// 深夜に勉強する層を切り捨てないために**午前4時**を境目にする。
/// 4時は「寝る前」と「起きたあと」が分かれる時刻で、
/// この時間に机に向かっている生徒はほとんどいない。
library;

/// 日の変わり目（時）。
const int kDayCutoverHour = 4;

/// その時刻が属する「日」。`YYYY-MM-DD`。
///
/// 端末のローカル時刻で切る。**UTC で切らない** —
/// 日本の生徒にとって「きのう」は日本時間のきのうしかない。
String dayKeyOf(DateTime t, {int cutoverHour = kDayCutoverHour}) {
  final shifted = t.subtract(Duration(hours: cutoverHour));
  return '${shifted.year.toString().padLeft(4, '0')}-'
      '${shifted.month.toString().padLeft(2, '0')}-'
      '${shifted.day.toString().padLeft(2, '0')}';
}

/// 日キーを、その日の始まり（午前4時）に戻す。
DateTime dayStartOf(String key, {int cutoverHour = kDayCutoverHour}) {
  final parts = key.split('-');
  final y = int.tryParse(parts.elementAtOrNull(0) ?? '') ?? 1970;
  final m = int.tryParse(parts.elementAtOrNull(1) ?? '') ?? 1;
  final d = int.tryParse(parts.elementAtOrNull(2) ?? '') ?? 1;
  return DateTime(y, m, d, cutoverHour);
}

/// 日キーを [days] だけずらす。
String shiftDay(String key, int days) =>
    dayKeyOf(dayStartOf(key).add(Duration(days: days)));

/// その日が属する週。**月曜はじまり。**
///
/// 猶予枠はこの単位で配る。日曜はじまりにすると、
/// 週末に潰れた部活のぶんが2つの週にまたがって数えにくい。
String weekKeyOf(String dayKey) {
  final d = dayStartOf(dayKey);
  // DateTime.weekday は月曜=1
  final monday = d.subtract(Duration(days: d.weekday - 1));
  return dayKeyOf(monday);
}

/// [from] から [to] までの日数（[from] を含まない）。
int daysBetweenKeys(String from, String to) =>
    dayStartOf(to).difference(dayStartOf(from)).inDays;
