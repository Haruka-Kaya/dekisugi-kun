import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/services/local_practice_schedule.dart';
import 'package:dekisugi/services/local_practice_store.dart';
import 'package:flutter_test/flutter_test.dart';

UnitSummary _unit(String id, List<String> conceptKeys) => UnitSummary(
  id: id,
  title: '単元$id',
  brief: '',
  concepts: [
    for (final key in conceptKeys)
      UnitConcept(key: key, label: '概念$key', storyTitle: '概念$keyの事件'),
  ],
  sectionCount: conceptKeys.length,
);

LocalPracticeRecord _record(
  String unitId,
  String conceptKey,
  DateTime at, {
  int count = 1,
}) => LocalPracticeRecord(
  unitId: unitId,
  conceptKey: conceptKey,
  completedCount: count,
  lastCompletedAt: at,
);

void main() {
  group('未着手の選定', () {
    test('単元をround-robinし、同一単元の連打を避ける', () {
      final now = DateTime.utc(2026, 8, 10, 12);
      final schedule = LocalPracticeSchedule(
        clock: () => now,
        localize: (instant) => instant,
      );
      final units = [
        _unit('u1', ['a', 'b', 'c']),
        _unit('u2', ['a', 'b']),
        _unit('u3', ['a', 'b']),
      ];
      final records = <LocalPracticeRecord>[];
      final selected = <String>[];

      for (var i = 0; i < 7; i++) {
        final result = schedule.select(units: units, records: records);
        expect(result.state, LocalPracticeScheduleState.nextMission);
        expect(result.mission!.reason, LocalPracticeMissionReason.newConcept);
        expect(result.mission!.completedCount, 0);
        selected.add(result.mission!.id);
        records.add(
          _record(result.mission!.unit.id, result.mission!.conceptKey, now),
        );
      }

      expect(selected, [
        'u1/a',
        'u2/a',
        'u3/a',
        'u1/b',
        'u2/b',
        'u3/b',
        'u1/c',
      ]);
      expect(
        schedule.select(units: units, records: records).state,
        LocalPracticeScheduleState.waitingForNextDay,
      );
    });

    test('古い復習候補より未着手を優先する', () {
      final schedule = LocalPracticeSchedule(
        clock: () => DateTime.utc(2026, 8, 10, 12),
        localize: (instant) => instant,
      );

      final result = schedule.select(
        units: [
          _unit('u1', ['done', 'new']),
        ],
        records: [
          _record('u1', 'done', DateTime.utc(2026, 7, 1, 12), count: 9),
        ],
      );

      expect(result.mission!.id, 'u1/new');
      expect(result.mission!.reason, LocalPracticeMissionReason.newConcept);
      expect(result.startedConcepts, 1);
      expect(result.totalConcepts, 2);
    });
  });

  group('全概念着手後', () {
    test('同じ端末ローカル学習日の再出題をmain CTAから外す', () {
      final schedule = LocalPracticeSchedule(
        clock: () => DateTime.utc(2026, 8, 10, 18),
        localize: (instant) => instant,
      );

      final result = schedule.select(
        units: [
          _unit('u1', ['a', 'b']),
        ],
        records: [
          _record('u1', 'a', DateTime.utc(2026, 8, 10, 5)),
          _record('u1', 'b', DateTime.utc(2026, 8, 10, 17)),
        ],
      );

      expect(result.state, LocalPracticeScheduleState.waitingForNextDay);
      expect(result.mission, isNull);
      expect(result.availableOnLocalDay, '2026-08-11');
      expect(result.startedConcepts, 2);
      expect(result.totalConcepts, 2);
    });

    test('翌日以降は最終完了日時が最も古い概念をdueにする', () {
      final schedule = LocalPracticeSchedule(
        clock: () => DateTime.utc(2026, 8, 11, 12),
        localize: (instant) => instant,
      );

      final result = schedule.select(
        units: [
          _unit('u1', ['newer', 'oldest', 'today']),
        ],
        records: [
          _record('u1', 'newer', DateTime.utc(2026, 8, 10, 19), count: 2),
          _record('u1', 'oldest', DateTime.utc(2026, 8, 9, 8), count: 5),
          _record('u1', 'today', DateTime.utc(2026, 8, 11, 5), count: 1),
        ],
      );

      expect(result.state, LocalPracticeScheduleState.nextMission);
      expect(result.mission!.id, 'u1/oldest');
      expect(result.mission!.reason, LocalPracticeMissionReason.dueReview);
      expect(result.mission!.completedCount, 5);
      expect(result.availableOnLocalDay, isNull);
    });

    test('同時刻ならcatalogのround-robin順で安定して選ぶ', () {
      final at = DateTime.utc(2026, 8, 9, 12);
      final schedule = LocalPracticeSchedule(
        clock: () => DateTime.utc(2026, 8, 11, 12),
        localize: (instant) => instant,
      );

      final result = schedule.select(
        units: [
          _unit('u1', ['a', 'b']),
          _unit('u2', ['a', 'b']),
        ],
        records: [
          _record('u1', 'a', at),
          _record('u1', 'b', at),
          _record('u2', 'a', at),
          _record('u2', 'b', at),
        ],
      );

      expect(result.mission!.id, 'u1/a');
    });
  });

  group('時計とタイムゾーン', () {
    test('同じUTC瞬間でも注入した地域の日付でdue判定する', () {
      final now = DateTime.utc(2026, 8, 10, 20);
      final record = _record('u1', 'a', DateTime.utc(2026, 8, 10, 14));
      final units = [
        _unit('u1', ['a']),
      ];
      final japan = LocalPracticeSchedule(
        clock: () => now,
        localize: (instant) => instant.add(const Duration(hours: 9)),
      );
      final west = LocalPracticeSchedule(
        clock: () => now,
        localize: (instant) => instant.subtract(const Duration(hours: 8)),
      );

      expect(
        japan.select(units: units, records: [record]).state,
        LocalPracticeScheduleState.nextMission,
      );
      expect(
        west.select(units: units, records: [record]).state,
        LocalPracticeScheduleState.waitingForNextDay,
      );
    });

    test('既存仕様どおり午前4時までは前の学習日として扱う', () {
      final units = [
        _unit('u1', ['a']),
      ];
      final record = _record('u1', 'a', DateTime.utc(2026, 8, 10, 23));
      LocalPracticeSchedule at(DateTime now) => LocalPracticeSchedule(
        clock: () => now,
        localize: (instant) => instant,
      );

      expect(
        at(
          DateTime.utc(2026, 8, 11, 3, 59),
        ).select(units: units, records: [record]).state,
        LocalPracticeScheduleState.waitingForNextDay,
      );
      expect(
        at(
          DateTime.utc(2026, 8, 11, 4),
        ).select(units: units, records: [record]).state,
        LocalPracticeScheduleState.nextMission,
      );
    });
  });

  test('カタログから消えたrecordを件数にもdue選定にも使わない', () {
    final schedule = LocalPracticeSchedule(
      clock: () => DateTime.utc(2026, 8, 10, 12),
      localize: (instant) => instant,
    );

    final result = schedule.select(
      units: [
        _unit('kept', ['a']),
      ],
      records: [
        _record('kept', 'a', DateTime.utc(2026, 8, 10, 8)),
        _record('removed', 'old', DateTime.utc(2020, 1, 1, 8), count: 99),
      ],
    );

    expect(result.state, LocalPracticeScheduleState.waitingForNextDay);
    expect(result.startedConcepts, 1);
    expect(result.totalConcepts, 1);
  });

  test('空または無効なカタログは教材なしを返す', () {
    final schedule = LocalPracticeSchedule();
    final result = schedule.select(
      units: [
        _unit('', ['a']),
        _unit('u1', ['', '']),
      ],
      records: const [],
    );

    expect(result.state, LocalPracticeScheduleState.emptyCatalog);
    expect(result.mission, isNull);
    expect(result.availableOnLocalDay, isNull);
    expect(result.totalConcepts, 0);
    expect(result.startedConcepts, 0);
  });
}
