import 'dart:convert';

import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

Map<String, Object?> sectionJson(String key) => {
      'conceptKey': key,
      'title': '$key の話',
      'body': ['1つめの段落。', '2つめの段落。'],
      'tryIt': '手を動かして確かめる。',
    };

Map<String, Object?> unitJson({List<Map<String, Object?>>? sections}) => {
      'id': 'force-motion',
      'title': '力と運動',
      'brief': 'ざっくりした紹介。',
      'concepts': [
        {'key': 'fall', 'label': '落下の速さ'},
        {'key': 'inertia', 'label': '慣性'},
      ],
      'sectionCount': 2,
      'sections': sections ?? [sectionJson('fall'), sectionJson('inertia')],
    };

void main() {
  group('UnitDetail のパース', () {
    test('教材ごと読める', () {
      final u = UnitDetail.fromJson(unitJson())!;
      expect(u.id, 'force-motion');
      expect(u.sections.length, 2);
      expect(u.sectionFor('fall')?.title, 'fall の話');
    });

    test('概念キーで教材を引ける（復習の読み直し先）', () {
      final u = UnitDetail.fromJson(unitJson())!;
      expect(u.sectionFor('inertia'), isNotNull);
      expect(u.sectionFor('nope'), isNull);
    });

    test('本文の無い節は落とす', () {
      // 出しても読めない。空の画面を見せるより存在しない方がよい
      final broken = {...sectionJson('friction'), 'body': <String>[]};
      final u = UnitDetail.fromJson(unitJson(sections: [
        sectionJson('fall'),
        broken,
      ]))!;
      expect(u.sections.length, 1);
      expect(u.sectionFor('friction'), isNull);
    });

    test('id が無ければ単元として扱わない', () {
      final json = unitJson()..remove('id');
      expect(UnitDetail.fromJson(json), isNull);
    });

    test('保存して読み戻せる', () {
      // 端末に保存するので、往復で壊れると復習が読めなくなる
      final a = UnitDetail.fromJson(unitJson())!;
      final b = UnitDetail.fromJson(
          jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>)!;
      expect(b.title, a.title);
      expect(b.sections.length, a.sections.length);
      expect(b.sectionFor('fall')?.body, a.sectionFor('fall')?.body);
    });

    test('読了時間は 30 秒を下回らない', () {
      // 「およそ0分」と出ると始めてよいのか分からない
      final tiny = UnitDetail.fromJson(unitJson(sections: [
        {...sectionJson('fall'), 'body': ['短い。'], 'tryIt': ''},
      ]))!;
      expect(tiny.readingTime.inSeconds, greaterThanOrEqualTo(30));
    });
  });

  group('UnitsClient', () {
    UnitsClient client(
      Map<String, Response<Object?> Function()> routes,
      SessionStore store,
    ) =>
        UnitsClient(
          baseUrl: 'https://example.test',
          store: store,
          dio: fakeDio(routes),
        );

    test('取れたら保存する', () async {
      final store = MemorySessionStore();
      final c = client({
        'GET https://example.test/api/units': () =>
            json200('{"unit": ${jsonEncode(unitJson())}}'),
      }, store);

      final got = await c.detail('force-motion');
      expect(got?.sections.length, 2);
      // 通信を切っても読める
      final cached = await c.cachedDetail('force-motion');
      expect(cached?.sectionFor('fall'), isNotNull);
    });

    test('取れなくても保存したものを出す', () async {
      // 教材は読み物。通信の都合で読めなくなるのは筋が悪い
      final store = MemorySessionStore();
      final ok = client({
        'GET https://example.test/api/units': () =>
            json200('{"unit": ${jsonEncode(unitJson())}}'),
      }, store);
      await ok.detail('force-motion');

      final offline = client({
        'GET https://example.test/api/units': () => jsonRes(500, '{}'),
      }, store);
      final got = await offline.detail('force-motion');
      expect(got, isNotNull, reason: '保存したものを出していない');
      expect(got!.sectionFor('fall'), isNotNull);
    });

    test('一度も取れていなければ null', () async {
      final c = client({
        'GET https://example.test/api/units': () => jsonRes(500, '{}'),
      }, MemorySessionStore());
      expect(await c.detail('force-motion'), isNull);
    });

    test('一覧も保存して出す', () async {
      final store = MemorySessionStore();
      final body = jsonEncode({
        'units': [unitJson()..remove('sections')],
      });
      final ok = client(
          {'GET https://example.test/api/units': () => json200(body)}, store);
      expect((await ok.list()).length, 1);

      final offline = client({
        'GET https://example.test/api/units': () => jsonRes(500, '{}'),
      }, store);
      final list = await offline.list();
      expect(list.length, 1);
      expect(list.first.concepts.length, 2);
    });

    test('接続先が無ければ通信しない', () async {
      final c = UnitsClient(baseUrl: '', store: MemorySessionStore());
      expect(await c.list(), isEmpty);
      expect(await c.detail('force-motion'), isNull);
    });
  });
}
