import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/widgets/dossier_bar.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> slotJson({
  String key = 'fall',
  String status = 'explained',
  List<String> evidence = const ['u02'],
  List<Map<String, dynamic>> probes = const [],
}) => {
  'key': key,
  'label': '落下の速さ',
  'status': status,
  'content': '重さによらない',
  'evidence': evidence,
  'followUpHint': '条件を引き出す',
  'probes': probes,
};

void main() {
  group('SlotStatus のパース', () {
    test('既知の値を読む', () {
      expect(SlotStatus.parse('explained'), SlotStatus.explained);
      expect(SlotStatus.parse('thin'), SlotStatus.thin);
      expect(SlotStatus.parse('untouched'), SlotStatus.untouched);
    });

    test('知らない値は untouched に落とす', () {
      // explained 側に落とすと、説明していないものを説明済みとして扱う
      expect(SlotStatus.parse('filled'), SlotStatus.untouched);
      expect(SlotStatus.parse(null), SlotStatus.untouched);
      expect(SlotStatus.parse(42), SlotStatus.untouched);
    });
  });

  group('ProbeResult のパース', () {
    test('既知の値を読む', () {
      expect(ProbeResult.parse('corrected'), ProbeResult.corrected);
      expect(ProbeResult.parse('accepted'), ProbeResult.accepted);
      expect(ProbeResult.parse('unclear'), ProbeResult.unclear);
    });

    test('知らない値を accepted に落とさない', () {
      // accepted は「誤解している」という強い主張。
      // 間違えると触れてもいない誤解を弱点として突きつけることになる
      expect(ProbeResult.parse('yes'), ProbeResult.notTried);
      expect(ProbeResult.parse(null), ProbeResult.notTried);
    });
  });

  group('Slot', () {
    test('根拠が無ければ explained でも空扱い', () {
      final s = Slot.fromJson(slotJson(evidence: const []));
      expect(s.isEmpty, isTrue);
    });

    test('壊れた JSON でも落ちない', () {
      final s = Slot.fromJson(const {});
      expect(s.key, '');
      expect(s.status, SlotStatus.untouched);
      expect(s.probes, isEmpty);
    });

    test('probes の要素が Map でなくても落ちない', () {
      final s = Slot.fromJson({
        ...slotJson(),
        'probes': ['ごみ', 42],
      });
      expect(s.probes, isEmpty);
    });
  });

  group('statusOf — カルテを画面の4状態へ写す', () {
    test('説明できた → gotIt', () {
      expect(statusOf(Slot.fromJson(slotJson())), ExplainStatus.gotIt);
    });

    test('薄い → shaky', () {
      expect(
        statusOf(Slot.fromJson(slotJson(status: 'thin'))),
        ExplainStatus.shaky,
      );
    });

    test('触れていない → untouched', () {
      expect(
        statusOf(Slot.fromJson(slotJson(status: 'untouched', evidence: []))),
        ExplainStatus.untouched,
      );
    });

    test('訂正できなかった誤概念があれば weak', () {
      final s = Slot.fromJson(
        slotJson(
          probes: [
            {
              'id': 'M01',
              'result': 'accepted',
              'evidence': ['u04'],
            },
          ],
        ),
      );
      expect(statusOf(s), ExplainStatus.weak);
    });

    test('unclear は weak に落とさない', () {
      // 判断がついていないものを「できていない」側に置くと、
      // 触れてもいないことを突きつけることになる
      final s = Slot.fromJson(
        slotJson(
          probes: [
            {'id': 'M01', 'result': 'unclear', 'evidence': <String>[]},
          ],
        ),
      );
      expect(statusOf(s), ExplainStatus.gotIt);
    });

    test('corrected は説明できた扱いのまま', () {
      final s = Slot.fromJson(
        slotJson(
          probes: [
            {
              'id': 'M01',
              'result': 'corrected',
              'evidence': ['u04'],
            },
          ],
        ),
      );
      expect(statusOf(s), ExplainStatus.gotIt);
    });
  });

  group('DirectorResult', () {
    test('必要なものを読み取る', () {
      final r = DirectorResult.fromJson({
        'corrections': [
          {'id': 'u02', 'corrected': '直した'},
          {'id': 'u03'},
          'ごみ',
        ],
        'dossier': {
          'unitId': 'force-motion',
          'coverage': 30,
          'slots': [slotJson()],
        },
        'nextInstruction': '次はこれ',
        'lureId': 'M01',
        'lureText': '固定文',
        'shouldEnd': false,
        'endReason': '',
      });

      expect(r.corrections, {'u02': '直した'});
      expect(r.dossier.coverage, 30);
      expect(r.dossier.slots.single.key, 'fall');
      expect(r.lureId, 'M01');
      expect(r.lureText, '固定文');
      expect(r.shouldEnd, isFalse);
    });

    test('中身が空でも落ちない', () {
      final r = DirectorResult.fromJson(const {});
      expect(r.corrections, isEmpty);
      expect(r.dossier.slots, isEmpty);
      expect(r.lureId, isNull);
      expect(r.lureText, isNull);
      expect(r.shouldEnd, isFalse);
    });

    test('shouldEnd は真偽値以外を true にしない', () {
      expect(DirectorResult.fromJson({'shouldEnd': 'true'}).shouldEnd, isFalse);
      expect(DirectorResult.fromJson({'shouldEnd': 1}).shouldEnd, isFalse);
    });
  });

  group('Utterance', () {
    test('サーバへ送る形', () {
      const u = Utterance(id: 'u01', isStudent: true, text: 'あ');
      expect(u.toJson(), {'id': 'u01', 'speaker': 'student', 'text': 'あ'});
    });

    test('校正後を表示に使う', () {
      const u = Utterance(id: 'u01', isStudent: true, text: '茶道水');
      expect(u.display, '茶道水');
      expect(u.withCorrection('砂糖水').display, '砂糖水');
      // 生の文字起こしは残す（何が崩れたか追えなくなる）
      expect(u.withCorrection('砂糖水').text, '茶道水');
    });

    test('校正してもchallengeの発話印を保つ', () {
      const u = Utterance(
        id: 'u01',
        isStudent: false,
        text: '重い方が速いの？',
        challengeLureId: 'M01',
        challengeLureText: '重い方が速いの？',
      );
      final corrected = u.withCorrection('重いものの方が速く落ちるの？');

      expect(corrected.challengeLureId, 'M01');
      expect(corrected.challengeLureText, '重い方が速いの？');
      expect(corrected.toJson()['challengeLureId'], 'M01');
      expect(corrected.toJson()['challengeLureText'], '重い方が速いの？');
    });
  });

  group('本人の説明を evidence から取り出す', () {
    test('LLMが作ったcontentではなく、実在する生徒発話を使う', () {
      final slot = Slot.fromJson({
        ...slotJson(),
        'content': 'これはディレクターが作った要約',
        'evidence': ['u02'],
      });
      final said = studentExplanationFor(slot, const [
        Utterance(id: 'u01', isStudent: false, text: 'どうして？'),
        Utterance(id: 'u02', isStudent: true, text: '重さは関係ないと思う'),
      ]);

      expect(said, '重さは関係ないと思う');
      expect(said, isNot(contains('ディレクター')), reason: 'AIの要約を「本人の言葉」として保存している');
    });

    test('累積evidenceの古い誤答を混ぜず、最新の実発話だけを使う', () {
      final slot = Slot.fromJson({
        ...slotJson(),
        'evidence': ['u03', 'u01', 'u03'],
      });
      final said = studentExplanationFor(slot, const [
        Utterance(id: 'u01', isStudent: true, text: '重い方が速く落ちる'),
        Utterance(id: 'u02', isStudent: false, text: 'それから？'),
        Utterance(id: 'u03', isStudent: true, text: 'いや、重さは関係ない'),
      ]);

      expect(said, 'いや、重さは関係ない');
      expect(said, isNot(contains('重い方が速く落ちる')));
    });

    test('LLMの校正文ではなく、生の発話を使う', () {
      final slot = Slot.fromJson({
        ...slotJson(),
        'evidence': ['u01'],
      });
      final said = studentExplanationFor(slot, const [
        Utterance(
          id: 'u01',
          isStudent: true,
          text: '空気のていこうがある',
          corrected: '空気抵抗が作用するためです',
        ),
      ]);

      expect(said, '空気のていこうがある');
      expect(said, isNot(contains('作用するためです')));
    });

    test('存在しないIDやAI発話しかなければ空にする', () {
      final slot = Slot.fromJson({
        ...slotJson(),
        'evidence': ['u99', 'u02'],
      });
      expect(
        studentExplanationFor(slot, const [
          Utterance(id: 'u02', isStudent: false, text: 'AIの発話'),
        ]),
        isEmpty,
      );
    });
  });

  group('Dossier の往復', () {
    test('toJson した結果を fromJson で戻せる', () {
      final before = Dossier.fromJson({
        'unitId': 'force-motion',
        'coverage': 45,
        'slots': [
          slotJson(
            probes: [
              {
                'id': 'M01',
                'result': 'accepted',
                'evidence': ['u04'],
                'countered': true,
              },
            ],
          ),
        ],
      });
      final after = Dossier.fromJson(before.toJson());

      expect(after.unitId, 'force-motion');
      expect(after.coverage, 45);
      expect(after.slots.single.probes.single.result, ProbeResult.accepted);
      // countered が落ちると毎ターン同じ訂正を持ち出して会話が止まる
      expect(after.slots.single.probes.single.countered, isTrue);
    });
  });
}
