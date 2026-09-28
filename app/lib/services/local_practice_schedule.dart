import '../models/day_key.dart';
import '../models/unit.dart';
import 'local_practice_store.dart';

/// 現在時刻を返す関数。
///
/// テストでは固定時刻を渡し、本番では未指定のまま端末時計を使う。
typedef LocalPracticeClock = DateTime Function();

/// UTCの瞬間を、選定に使う地域の壁時計へ変換する関数。
///
/// 端末のタイムゾーンを使う本番実装だけでなく、固定offsetや任意の地域を
/// テストから注入できる。返り値の [DateTime.isUtc] は参照せず、年月日時だけを
/// 壁時計として扱う。
typedef LocalPracticeLocalizer = DateTime Function(DateTime utcInstant);

/// scheduled main CTA が今どの表示になるか。
enum LocalPracticeScheduleState {
  /// 未着手、または前の学習日以前に終えた概念を1件出せる。
  nextMission,

  /// 全概念を着手済みで、残る概念はすべて同じ学習日以降に完了している。
  waitingForNextDay,

  /// 現在のカタログに選べる概念が無い。
  emptyCatalog,
}

/// scheduled main CTA が概念を選んだ理由。
enum LocalPracticeMissionReason {
  /// 現在のカタログで、まだ一度も完了していない。
  newConcept,

  /// 全概念を着手済みで、最終完了が最も古い。
  dueReview,
}

/// scheduled main CTA から開く1件。
class LocalPracticeScheduledMission {
  const LocalPracticeScheduledMission({
    required this.unit,
    required this.conceptKey,
    required this.conceptLabel,
    required this.completedCount,
    required this.reason,
  });

  final UnitSummary unit;
  final String conceptKey;
  final String conceptLabel;

  /// 既存の公開variantを選ぶための完了回数。新規は0。
  final int completedCount;
  final LocalPracticeMissionReason reason;

  String get id => '${unit.id}/$conceptKey';
}

/// [LocalPracticeSchedule.select] の表示用結果。
class LocalPracticeScheduleResult {
  const LocalPracticeScheduleResult._({
    required this.state,
    required this.mission,
    required this.availableOnLocalDay,
    required this.totalConcepts,
    required this.startedConcepts,
  });

  /// main CTA は [state] だけで「次のミッション」「翌日待ち」「教材なし」を
  /// 分岐できる。[nextMission] のときだけ [mission] が入る。
  final LocalPracticeScheduleState state;
  final LocalPracticeScheduledMission? mission;

  /// [waitingForNextDay] のときに表示できる次の端末ローカル学習日。
  /// `YYYY-MM-DD`。アプリ共通の午前4時境界を使う。
  final String? availableOnLocalDay;

  /// カタログから消えたrecordはどちらの数にも含めない。
  final int totalConcepts;
  final int startedConcepts;
}

/// 端末内モードの scheduled main CTA だけを選定する純粋なサービス。
///
/// 学校コードと手動pickerはこのサービスを通さず、当日でも指定教材を開ける。
/// 保存済みの回答・選択肢・hintは必要とせず、[LocalPracticeRecord]の4項目だけを
/// 参照する。
class LocalPracticeSchedule {
  LocalPracticeSchedule({
    LocalPracticeClock? clock,
    LocalPracticeLocalizer? localize,
    this.cutoverHour = kDayCutoverHour,
  }) : _clock = clock ?? _systemClock,
       _localize = localize ?? _deviceLocalizer,
       assert(cutoverHour >= 0 && cutoverHour <= 23);

  final LocalPracticeClock _clock;
  final LocalPracticeLocalizer _localize;

  /// 既存の連続学習表示と同じ端末ローカル日の境界。
  final int cutoverHour;

  LocalPracticeScheduleResult select({
    required List<UnitSummary> units,
    required Iterable<LocalPracticeRecord> records,
  }) {
    final catalog = _roundRobinCatalog(units);
    if (catalog.isEmpty) {
      return const LocalPracticeScheduleResult._(
        state: LocalPracticeScheduleState.emptyCatalog,
        mission: null,
        availableOnLocalDay: null,
        totalConcepts: 0,
        startedConcepts: 0,
      );
    }

    final validIds = {for (final mission in catalog) mission.id};
    final recordById = <String, LocalPracticeRecord>{};
    for (final record in records) {
      if (!validIds.contains(record.id)) continue;
      final current = recordById[record.id];
      if (current == null ||
          record.lastCompletedAt.isAfter(current.lastCompletedAt)) {
        recordById[record.id] = record;
      }
    }

    // 新規は固定の単元round-robin順。復習が古くても、未着手を先にする。
    for (final entry in catalog) {
      if (!recordById.containsKey(entry.id)) {
        return _next(
          entry,
          completedCount: 0,
          reason: LocalPracticeMissionReason.newConcept,
          totalConcepts: catalog.length,
          startedConcepts: recordById.length,
        );
      }
    }

    final nowUtc = _clock().toUtc();
    final today = _dayKey(nowUtc);
    _CatalogMission? oldestDue;
    LocalPracticeRecord? oldestRecord;
    for (final entry in catalog) {
      final record = recordById[entry.id]!;
      // 当日と未来日の記録はscheduled CTAへ戻さない。手動pickerと学校コードは
      // この選定を通らないため、必要ならいつでも同じ概念を開ける。
      if (_dayKey(record.lastCompletedAt.toUtc()).compareTo(today) >= 0) {
        continue;
      }
      if (oldestRecord == null ||
          record.lastCompletedAt.isBefore(oldestRecord.lastCompletedAt)) {
        oldestDue = entry;
        oldestRecord = record;
      }
    }

    if (oldestDue != null && oldestRecord != null) {
      return _next(
        oldestDue,
        completedCount: oldestRecord.completedCount,
        reason: LocalPracticeMissionReason.dueReview,
        totalConcepts: catalog.length,
        startedConcepts: recordById.length,
      );
    }

    return LocalPracticeScheduleResult._(
      state: LocalPracticeScheduleState.waitingForNextDay,
      mission: null,
      availableOnLocalDay: _nextDayKey(today),
      totalConcepts: catalog.length,
      startedConcepts: recordById.length,
    );
  }

  LocalPracticeScheduleResult _next(
    _CatalogMission entry, {
    required int completedCount,
    required LocalPracticeMissionReason reason,
    required int totalConcepts,
    required int startedConcepts,
  }) => LocalPracticeScheduleResult._(
    state: LocalPracticeScheduleState.nextMission,
    mission: LocalPracticeScheduledMission(
      unit: entry.unit,
      conceptKey: entry.conceptKey,
      conceptLabel: entry.conceptLabel,
      completedCount: completedCount,
      reason: reason,
    ),
    availableOnLocalDay: null,
    totalConcepts: totalConcepts,
    startedConcepts: startedConcepts,
  );

  String _dayKey(DateTime utcInstant) =>
      dayKeyOf(_localize(utcInstant), cutoverHour: cutoverHour);

  static List<_CatalogMission> _roundRobinCatalog(List<UnitSummary> units) {
    final result = <_CatalogMission>[];
    final seenIds = <String>{};
    final longest = units.fold<int>(
      0,
      (length, unit) =>
          unit.concepts.length > length ? unit.concepts.length : length,
    );
    for (var conceptIndex = 0; conceptIndex < longest; conceptIndex++) {
      for (final unit in units) {
        if (conceptIndex >= unit.concepts.length) continue;
        final concept = unit.concepts[conceptIndex];
        if (unit.id.trim().isEmpty || concept.key.trim().isEmpty) continue;
        final id = '${unit.id}/${concept.key}';
        if (!seenIds.add(id)) continue;
        result.add(
          _CatalogMission(
            unit: unit,
            conceptKey: concept.key,
            conceptLabel: concept.label,
          ),
        );
      }
    }
    return result;
  }

  static DateTime _systemClock() => DateTime.now();

  static DateTime _deviceLocalizer(DateTime utcInstant) => utcInstant.toLocal();

  // 注入されたtimezoneと無関係な端末timezoneで日付をずらさないよう、
  // YYYY-MM-DDの暦計算だけをUTC上で行う。
  static String _nextDayKey(String key) {
    final parts = key.split('-').map(int.parse).toList(growable: false);
    final next = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
    ).add(const Duration(days: 1));
    return '${next.year.toString().padLeft(4, '0')}-'
        '${next.month.toString().padLeft(2, '0')}-'
        '${next.day.toString().padLeft(2, '0')}';
  }
}

class _CatalogMission {
  const _CatalogMission({
    required this.unit,
    required this.conceptKey,
    required this.conceptLabel,
  });

  final UnitSummary unit;
  final String conceptKey;
  final String conceptLabel;

  String get id => '${unit.id}/$conceptKey';
}
