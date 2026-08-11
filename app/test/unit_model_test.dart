import 'dart:convert';

import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

class _JsonAssetBundle extends CachingAssetBundle {
  _JsonAssetBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
}

Map<String, Object?> checkpointJson([String conceptKey = 'fall']) => {
  'lure': '重いものほど先に着く。',
  'options': [
    {'id': 'correct', 'text': '同時に着く。'},
    {
      'id': 'wrong-1',
      'text': '重い方。',
      'hint': '重さ以外の条件を見る。',
      'needCode': 'science.$conceptKey.foundation',
    },
    {
      'id': 'wrong-2',
      'text': '軽い方。',
      'hint': '落下加速度を考える。',
      'needCode': 'science.$conceptKey.foundation',
    },
  ],
  'correctOptionId': 'correct',
  'explanation': '空気抵抗を無視すれば落下加速度は重さによらない。',
};

Map<String, Object?> checkpointVariantJson({
  required String suffix,
  required int correctIndex,
  String conceptKey = 'fall',
}) {
  final options = <Map<String, Object?>>[
    {
      'id': 'wrong-$suffix-a',
      'text': '誤った説明A。',
      'hint': '答えではなく、見直す条件A。',
      'needCode': 'science.$conceptKey.$suffix',
    },
    {
      'id': 'wrong-$suffix-b',
      'text': '誤った説明B。',
      'hint': '答えではなく、見直す条件B。',
      'needCode': 'science.$conceptKey.$suffix',
    },
  ]..insert(correctIndex, {'id': 'correct-$suffix', 'text': '正しい説明。'});
  return {
    'lure': '$suffix 周目の異なる思い込み。',
    'options': options,
    'correctOptionId': 'correct-$suffix',
    'explanation': '$suffix 周目の正答説明。',
  };
}

Map<String, Object?> cognitiveTaskJson(
  String stage, [
  String conceptKey = 'fall',
]) => switch (stage) {
  'foundation' => {
    'kind': 'singleSelect',
    'operation': 'prediction',
    'needCode': 'science.$conceptKey.$stage',
    'items': [
      {'id': 'outcome-a', 'text': '結果A'},
      {'id': 'outcome-b', 'text': '結果B'},
      {'id': 'outcome-c', 'text': '結果C'},
    ],
    'solution': {'selectedItemId': 'outcome-b'},
  },
  'conditions' => {
    'kind': 'classify',
    'operation': 'conditionClassify',
    'needCode': 'science.$conceptKey.$stage',
    'items': [
      {'id': 'setup-a', 'text': '条件A'},
      {'id': 'setup-b', 'text': '条件B'},
      {'id': 'setup-c', 'text': '条件C'},
    ],
    'targets': [
      {'id': 'group-a', 'label': '分類A'},
      {'id': 'group-b', 'label': '分類B'},
    ],
    'solution': {
      'targetByItemId': {
        'setup-a': 'group-b',
        'setup-b': 'group-a',
        'setup-c': 'group-b',
      },
    },
  },
  'transfer' => {
    'kind': 'sequence',
    'operation': 'causalOrder',
    'needCode': 'science.$conceptKey.$stage',
    'items': [
      {'id': 'event-c', 'text': '出来事C'},
      {'id': 'event-a', 'text': '出来事A'},
      {'id': 'event-b', 'text': '出来事B'},
    ],
    'solution': {
      'orderedItemIds': ['event-a', 'event-b', 'event-c'],
    },
  },
  _ => throw ArgumentError.value(stage, 'stage'),
};

List<Map<String, Object?>> practiceVariantsJson([String conceptKey = 'fall']) =>
    [
      {
        'stage': 'foundation',
        'recallPrompt': '中心となる考えを思い出す。',
        'reasoningPrompt': '理由を一つ足す。',
        'transferPrompt': '最初の具体場面を予想する。',
        'expectedOutcome': '最初の具体場面で観察する結果。',
        'expectedReason': '最初の結果が条件の下で生じる理由。',
        'cognitiveTask': cognitiveTaskJson('foundation', conceptKey),
        'checkpoint': checkpointJson(conceptKey),
        'listeningNeedCodes': listeningNeedCodesJson(conceptKey, 'foundation'),
      },
      {
        'stage': 'conditions',
        'recallPrompt': '成り立つ条件を思い出す。',
        'reasoningPrompt': '条件を区別する理由を書く。',
        'transferPrompt': '条件を変えた場面を予想する。',
        'expectedOutcome': '条件を変えた場面の観察結果。',
        'expectedReason': '条件の違いが結果を変える理由。',
        'cognitiveTask': cognitiveTaskJson('conditions', conceptKey),
        'checkpoint': checkpointVariantJson(
          suffix: 'conditions',
          correctIndex: 1,
          conceptKey: conceptKey,
        ),
        'listeningNeedCodes': listeningNeedCodesJson(conceptKey, 'conditions'),
      },
      {
        'stage': 'transfer',
        'recallPrompt': '別場面で使う原理を思い出す。',
        'reasoningPrompt': '別場面へつながる理由を書く。',
        'transferPrompt': '未見の具体場面を予想する。',
        'expectedOutcome': '未見の具体場面の予測結果。',
        'expectedReason': '中心の原理を未見の場面へ移す理由。',
        'cognitiveTask': cognitiveTaskJson('transfer', conceptKey),
        'checkpoint': checkpointVariantJson(
          suffix: 'transfer',
          correctIndex: 2,
          conceptKey: conceptKey,
        ),
        'listeningNeedCodes': listeningNeedCodesJson(conceptKey, 'transfer'),
      },
    ];

Map<String, Object?> listeningNeedCodesJson(String conceptKey, String stage) =>
    {
      'transcript': 'science.$conceptKey.listening.$stage.transcript',
      'meaning': 'science.$conceptKey.listening.$stage.meaning',
    };

Map<String, Object?> tracePatternJson(String taskId) => {
  'semanticsLabel': '$taskIdを順になぞる。',
  'strokes': [
    {
      'id': '$taskId.stroke-a',
      'label': '1本目の線',
      'points': [
        {'x': 0.1, 'y': 0.5},
        {'x': 0.4, 'y': 0.5},
        {'x': 0.8, 'y': 0.5},
      ],
    },
  ],
  'strokeOrderIds': ['$taskId.stroke-a'],
};

Map<String, Object?> notationLabJson(String key) => {
  'orderTasks': [
    {
      'id': '$key.arrow',
      'needCode': 'science.$key.notation.arrow',
      'title': '矢印をなぞる',
      'prompt': '$keyの矢印を順に置く。',
      'traceGuide': '始点から向きを確かめる。',
      'tracePattern': tracePatternJson('$key.arrow'),
      'tokens': [
        {'id': 'direction', 'label': '向き'},
        {'id': 'origin', 'label': '始点'},
      ],
      'correctOrderIds': ['origin', 'direction'],
      'solutionSummary': '始点から向きへ読みます。',
    },
    {
      'id': '$key.equation',
      'needCode': 'science.$key.notation.equation',
      'title': '式を組む',
      'prompt': '$keyの式を左から組む。',
      'traceGuide': '量の意味を確かめる。',
      'tracePattern': tracePatternJson('$key.equation'),
      'tokens': [
        {'id': 'equals', 'label': '='},
        {'id': 'left', 'label': '左辺'},
        {'id': 'right', 'label': '右辺'},
      ],
      'correctOrderIds': ['left', 'equals', 'right'],
      'solutionSummary': '左辺と右辺の量を結びます。',
    },
  ],
  'symbolMatch': {
    'needCode': 'science.$key.notation.symbol',
    'prompt': '$keyの単位記号は？',
    'choices': [
      {'id': 'unit-b', 'label': '単位B'},
      {'id': 'unit-a', 'label': '単位A'},
    ],
    'correctChoiceId': 'unit-a',
    'solutionSummary': '単位Aを使います。',
  },
  'graphRead': {
    'needCode': 'science.$key.notation.graph',
    'prompt': '$keyのグラフを読む。',
    'graphNotation': ['縦軸', '横軸 →'],
    'graphSemanticsLabel': '横軸と縦軸を持つグラフ。',
    'choices': [
      {'id': 'decrease', 'label': '減る'},
      {'id': 'increase', 'label': '増える'},
    ],
    'correctChoiceId': 'increase',
    'solutionSummary': '右へ進むと増えます。',
  },
};

Map<String, Object?> scienceStoryJson(String key) {
  final foundation = practiceVariantsJson(key).first;
  final checkpoint = foundation['checkpoint']! as Map<String, Object?>;
  final options = checkpoint['options']! as List<Map<String, Object?>>;
  Map<String, Object?> line(String id, String speakerId, String text) => {
    'id': '$key.story.$id',
    'speakerId': speakerId,
    'text': text,
  };

  return {
    'id': '$key.story',
    'title': '$key 固有の事件',
    'setting': '$key を調べる固定の実験場所。',
    'foundationNeedCode': 'science.$key.foundation',
    'characters': [
      {'id': 'mio', 'name': 'ミオ', 'role': '観察'},
      {'id': 'dekisugi', 'name': 'デキすぎ君', 'role': '仮説'},
      {'id': 'ren', 'name': 'レン', 'role': '記録'},
    ],
    'openingLines': [
      line('open-1', 'mio', '$key の事件を観察しよう。'),
      line('open-2', 'ren', '変えた条件を記録したよ。'),
      line('open-3', 'dekisugi', 'ぼくの仮説に任せて。'),
    ],
    'choiceLine': line('choice', 'dekisugi', checkpoint['lure']! as String),
    'choiceResponses': [
      for (var index = 0; index < options.length; index++)
        {
          'optionId': options[index]['id'],
          'line': line(
            'response-${options[index]['id']}',
            ['mio', 'dekisugi', 'ren'][index],
            '${options[index]['id']}への固定反応。',
          ),
        },
    ],
    'resolutionLines': [
      line('resolve-1', 'mio', '観察から結果を確かめたよ。'),
      line('resolve-2', 'ren', '条件と理由も一致したね。'),
    ],
    'scientificResolution': {
      'outcome': foundation['expectedOutcome'],
      'reason': foundation['expectedReason'],
    },
    'punchline': line('punchline', 'dekisugi', '$key の落ちは忘れないよ。'),
  };
}

Map<String, Object?> sectionJson(String key) => {
  'conceptKey': key,
  'title': '$key の話',
  'body': ['1つめの段落。', '2つめの段落。'],
  'tryIt': '手を動かして確かめる。',
  'localCheckpoint': checkpointJson(key),
  'localSpeakingPractice': {
    'targetPhrase': '$keyの固定目標語句を声または文字で確認する',
    'acceptedTranscripts': ['$keyの固定目標語句を声または文字で確認する'],
  },
  'localPracticeVariants': practiceVariantsJson(key),
  'notationLab': notationLabJson(key),
  'scienceStory': scienceStoryJson(key),
};

Map<String, Object?> unitJson({List<Map<String, Object?>>? sections}) {
  final resolvedSections =
      sections ?? [sectionJson('fall'), sectionJson('inertia')];
  return {
    'id': 'force-motion',
    'title': '力と運動',
    'brief': 'ざっくりした紹介。',
    'concepts': [
      for (final section in resolvedSections)
        {
          'key': section['conceptKey'],
          'label': '${section['conceptKey']}の考え',
          'storyTitle': '${section['conceptKey']} 固有の事件',
          'field': 'energy',
          'grade': 3,
          'curriculumRefs': [
            {
              'document': 'mext-jhs-science-2017',
              'section': '第1分野 (5) 運動とエネルギー',
              'pages': [61, 62],
              'url':
                  'https://www.mext.go.jp/component/a_menu/education/'
                  'micro_detail/__icsFiles/afieldfile/2019/03/18/'
                  '1387018_005.pdf',
            },
          ],
          'prerequisites': <String>[],
          'difficulty': 2,
          'safety': {
            'level': 'homeSafe',
            'guidance': '同じ紙を手の高さから落とし、踏み台は使わない。',
          },
        },
    ],
    'sectionCount': resolvedSections.length,
    'sections': resolvedSections,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnitDetail のパース', () {
    test('教材ごと読める', () {
      final u = UnitDetail.fromJson(unitJson())!;
      expect(u.id, 'force-motion');
      expect(u.sections.length, 2);
      expect(u.sectionFor('fall')?.title, 'fall の話');
      expect(u.sectionFor('fall')?.localCheckpoint.options, hasLength(3));
      expect(u.sectionFor('fall')?.localPracticeVariants, hasLength(3));
      expect(u.sectionFor('fall')?.notationLab?.orderTasks, hasLength(2));
      expect(u.sectionFor('fall')?.scienceStory?.choiceResponses, hasLength(3));
    });

    test('概念キーで教材を引ける（復習の読み直し先）', () {
      final u = UnitDetail.fromJson(unitJson())!;
      expect(u.sectionFor('inertia'), isNotNull);
      expect(u.sectionFor('nope'), isNull);
    });

    test('本文の無い節を含む単元は部分採用せずfail-closedにする', () {
      // 出しても読めない。空の画面を見せるより存在しない方がよい
      final broken = {...sectionJson('friction'), 'body': <String>[]};
      expect(
        UnitDetail.fromJson(unitJson(sections: [sectionJson('fall'), broken])),
        isNull,
      );
    });

    test('id が無ければ単元として扱わない', () {
      final json = unitJson()..remove('id');
      expect(UnitDetail.fromJson(json), isNull);
    });

    test('一覧conceptはStory事件名を必須化し、未知fieldと詳細不一致を拒否する', () {
      final missingTitle = unitJson();
      ((missingTitle['concepts']! as List).first as Map<String, Object?>)
          .remove('storyTitle');
      expect(UnitDetail.fromJson(missingTitle), isNull);

      final unknownField = unitJson();
      ((unknownField['concepts']! as List).first
              as Map<String, Object?>)['futureTitle'] =
          '未知field';
      expect(UnitDetail.fromJson(unknownField), isNull);

      final wrongType = unitJson();
      ((wrongType['concepts']! as List).first
              as Map<String, Object?>)['storyTitle'] =
          7;
      expect(UnitDetail.fromJson(wrongType), isNull);

      final mismatchedTitle = unitJson();
      ((mismatchedTitle['concepts']! as List).first
              as Map<String, Object?>)['storyTitle'] =
          '詳細と異なる事件名';
      expect(UnitDetail.fromJson(mismatchedTitle), isNull);

      final missingCoverage = unitJson();
      ((missingCoverage['concepts']! as List).first as Map<String, Object?>)
          .remove('curriculumRefs');
      expect(UnitDetail.fromJson(missingCoverage), isNull);

      final selfPrerequisite = unitJson();
      final selfConcept =
          (selfPrerequisite['concepts']! as List).first as Map<String, Object?>;
      selfConcept['prerequisites'] = [selfConcept['key']];
      expect(UnitDetail.fromJson(selfPrerequisite), isNull);

      final unknownSafety = unitJson();
      final safetyConcept =
          (unknownSafety['concepts']! as List).first as Map<String, Object?>;
      safetyConcept['safety'] = {
        ...(safetyConcept['safety']! as Map<String, Object?>),
        'futureRisk': true,
      };
      expect(UnitDetail.fromJson(unknownSafety), isNull);
    });

    test('保存して読み戻せる', () {
      // 端末に保存するので、往復で壊れると復習が読めなくなる
      final a = UnitDetail.fromJson(unitJson())!;
      final b = UnitDetail.fromJson(
        jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>,
      )!;
      expect(b.title, a.title);
      expect(b.sections.length, a.sections.length);
      expect(b.sectionFor('fall')?.body, a.sectionFor('fall')?.body);
      expect(
        b.sectionFor('fall')?.localCheckpoint.correctOptionId,
        a.sectionFor('fall')?.localCheckpoint.correctOptionId,
      );
      expect(
        b.sectionFor('fall')?.localPracticeVariants.map((v) => v.stage),
        LocalPracticeStage.values,
      );
      expect(
        b.sectionFor('fall')?.localPracticeVariants.first.expectedOutcome,
        a.sectionFor('fall')?.localPracticeVariants.first.expectedOutcome,
      );
      expect(
        b.sectionFor('fall')?.localPracticeVariants.first.expectedReason,
        a.sectionFor('fall')?.localPracticeVariants.first.expectedReason,
      );
      expect(
        b.sectionFor('fall')?.notationLab?.graphRead.graphSemanticsLabel,
        a.sectionFor('fall')?.notationLab?.graphRead.graphSemanticsLabel,
      );
      expect(
        b.sectionFor('fall')?.scienceStory?.punchline.text,
        a.sectionFor('fall')?.scienceStory?.punchline.text,
      );
    });

    test('Notation Labは未知field・欠落・正答順の表示を節ごとfail-closedにする', () {
      bool rejects(Map<String, Object?> notation) {
        final section = sectionJson('fall')..['notationLab'] = notation;
        return UnitDetail.fromJson(unitJson(sections: [section])) == null;
      }

      expect(
        rejects({...notationLabJson('fall'), 'answer': '未知field'}),
        isTrue,
      );
      final missingGraph = notationLabJson('fall')..remove('graphRead');
      expect(rejects(missingGraph), isTrue);

      final shownInAnswerOrder = notationLabJson('fall');
      final tasks = shownInAnswerOrder['orderTasks']! as List;
      final first = tasks.first as Map<String, Object?>;
      first['tokens'] = [
        {'id': 'origin', 'label': '始点'},
        {'id': 'direction', 'label': '向き'},
      ];
      expect(rejects(shownInAnswerOrder), isTrue);

      final unknownSection = sectionJson('fall')..['futureAnswer'] = true;
      expect(UnitDetail.fromJson(unitJson(sections: [unknownSection])), isNull);

      final missingTrace = notationLabJson('fall');
      (missingTrace['orderTasks']! as List)
          .cast<Map<String, Object?>>()
          .first
          .remove('tracePattern');
      expect(rejects(missingTrace), isTrue);

      final outOfRange = notationLabJson('fall');
      final outPattern =
          ((outOfRange['orderTasks']! as List).first
                  as Map<String, Object?>)['tracePattern']!
              as Map<String, Object?>;
      final outStroke =
          (outPattern['strokes']! as List).first as Map<String, Object?>;
      (outStroke['points']! as List).first = {'x': 1.2, 'y': 0.5};
      expect(rejects(outOfRange), isTrue);

      final tooShort = notationLabJson('fall');
      final shortPattern =
          ((tooShort['orderTasks']! as List).first
                  as Map<String, Object?>)['tracePattern']!
              as Map<String, Object?>;
      final shortStroke =
          (shortPattern['strokes']! as List).first as Map<String, Object?>;
      shortStroke['points'] = [
        {'x': 0.1, 'y': 0.5},
        {'x': 0.2, 'y': 0.5},
      ];
      expect(rejects(tooShort), isTrue);

      final duplicateRef = notationLabJson('fall');
      final duplicatePattern =
          ((duplicateRef['orderTasks']! as List).first
                  as Map<String, Object?>)['tracePattern']!
              as Map<String, Object?>;
      final id = (duplicatePattern['strokeOrderIds']! as List).first;
      duplicatePattern['strokeOrderIds'] = [id, id];
      expect(rejects(duplicateRef), isTrue);
    });

    test('v10 Notation tagged unionは6kindを厳格に読み、trace無しarrangeも損失しない', () {
      Map<String, Object?> tagged() =>
          (jsonDecode(
                    jsonEncode(
                      LocalNotationLab.fromJson(
                        notationLabJson('fall'),
                      )!.toJson(),
                    ),
                  )
                  as Map)
              .cast<String, Object?>();
      bool rejects(Map<String, Object?> notation) {
        final section = sectionJson('fall')..['notationLab'] = notation;
        return UnitDetail.fromJson(unitJson(sections: [section])) == null;
      }

      final withoutTrace = tagged();
      final arrange = (withoutTrace['tasks']! as List)
          .cast<Map<String, Object?>>()
          .first;
      arrange.remove('tracePattern');
      final parsed = UnitDetail.fromJson(
        unitJson(
          sections: [sectionJson('fall')..['notationLab'] = withoutTrace],
        ),
      );
      expect(parsed, isNotNull);
      expect(
        (parsed!.sectionFor('fall')!.notationLab!.tasks.first
                as LocalNotationArrangeTask)
            .tracePattern,
        isNull,
      );
      expect(
        parsed.sectionFor('fall')!.notationLab!.toJson(),
        withoutTrace,
        reason: 'tagged unionのfieldを往復で落とした',
      );

      final unknownTaskField = tagged();
      ((unknownTaskField['tasks']! as List).first
              as Map<String, Object?>)['futureAnswer'] =
          true;
      expect(rejects(unknownTaskField), isTrue);

      final mismatchedLegacyNeed = tagged();
      ((mismatchedLegacyNeed['tasks']! as List).first
              as Map<String, Object?>)['kind'] =
          'modelBuild';
      expect(rejects(mismatchedLegacyNeed), isTrue);

      final shownInAnswerOrder = tagged();
      final shownTask =
          (shownInAnswerOrder['tasks']! as List).first as Map<String, Object?>;
      shownTask['tokens'] = [
        {'id': 'origin', 'label': '始点'},
        {'id': 'direction', 'label': '向き'},
      ];
      expect(rejects(shownInAnswerOrder), isTrue);

      final missingRepresentation = tagged();
      final choiceTask = (missingRepresentation['tasks']! as List)
          .cast<Map<String, Object?>>()
          .firstWhere((task) => task['kind'] == 'graphRead');
      choiceTask.remove('representation');
      expect(rejects(missingRepresentation), isTrue);
    });

    test('Science Storyは未知field・欠落会話・参照不整合・foundation不一致をfail-closedにする', () {
      bool rejects(Map<String, Object?> story) {
        final section = sectionJson('fall')..['scienceStory'] = story;
        return UnitDetail.fromJson(unitJson(sections: [section])) == null;
      }

      expect(
        rejects({...scienceStoryJson('fall'), 'futureScene': '未知'}),
        isTrue,
      );
      final missingLine = scienceStoryJson('fall')
        ..['openingLines'] = <Object?>[];
      expect(rejects(missingLine), isTrue);

      final unknownSpeaker = scienceStoryJson('fall');
      final opening = unknownSpeaker['openingLines']! as List;
      opening[0] = {
        ...(opening[0] as Map<String, Object?>),
        'speakerId': 'unknown',
      };
      expect(rejects(unknownSpeaker), isTrue);

      final unusedCharacter = scienceStoryJson('fall');
      (unusedCharacter['characters']! as List).add({
        'id': 'unused',
        'name': '未使用',
        'role': '会話なし',
      });
      expect(rejects(unusedCharacter), isTrue);

      final missingResponse = scienceStoryJson('fall');
      (missingResponse['choiceResponses']! as List).removeLast();
      expect(rejects(missingResponse), isTrue);

      final wrongFoundation = scienceStoryJson('fall')
        ..['foundationNeedCode'] = 'science.fall.conditions';
      expect(rejects(wrongFoundation), isTrue);

      final wrongResolution = scienceStoryJson('fall');
      (wrongResolution['scientificResolution']!
              as Map<String, Object?>)['outcome'] =
          '別の結果';
      expect(rejects(wrongResolution), isTrue);
    });

    test('Speaking目標は未知field・欠落・短文・重複候補をfail-closedにする', () {
      bool rejects(Map<String, Object?> speaking) {
        final section = sectionJson('fall')
          ..['localSpeakingPractice'] = speaking;
        return UnitDetail.fromJson(unitJson(sections: [section])) == null;
      }

      final valid =
          sectionJson('fall')['localSpeakingPractice']! as Map<String, Object?>;
      expect(rejects({...valid, 'futureScore': 0.8}), isTrue);
      expect(
        rejects({
          'targetPhrase': '短い',
          'acceptedTranscripts': ['短い'],
        }),
        isTrue,
      );
      expect(
        rejects({
          ...valid,
          'acceptedTranscripts': [
            valid['targetPhrase'],
            '${valid['targetPhrase']}。',
          ],
        }),
        isTrue,
      );
      expect(
        rejects({
          'targetPhrase': '。。。。。。。。。。。。',
          'acceptedTranscripts': ['。。。。。。。。。。。。'],
        }),
        isTrue,
      );
      final missing = sectionJson('fall')..remove('localSpeakingPractice');
      expect(UnitDetail.fromJson(unitJson(sections: [missing])), isNull);
    });

    test('3variantが無い旧sectionと、3択1正答でないsectionは読まない', () {
      final old = sectionJson('fall')..remove('localPracticeVariants');
      final twoChoices = {
        ...sectionJson('inertia'),
        'localPracticeVariants': [
          ...practiceVariantsJson().take(2),
          {
            ...practiceVariantsJson()[2],
            'checkpoint': {
              ...checkpointVariantJson(suffix: 'broken', correctIndex: 2),
              'options':
                  (checkpointVariantJson(
                            suffix: 'broken',
                            correctIndex: 2,
                          )['options']
                          as List)
                      .take(2)
                      .toList(),
            },
          },
        ],
      };
      expect(
        UnitDetail.fromJson(unitJson(sections: [old, twoChoices])),
        isNull,
      );
    });

    test('Listeningの聞き取り/意味needはconcept×stage完全一致を必須にする', () {
      bool rejects(void Function(Map<String, Object?> codes) mutate) {
        final section = sectionJson('fall');
        final variants = section['localPracticeVariants']! as List;
        final first = variants.first as Map<String, Object?>;
        final codes = Map<String, Object?>.from(
          first['listeningNeedCodes']! as Map,
        );
        mutate(codes);
        first['listeningNeedCodes'] = codes;
        return UnitDetail.fromJson(unitJson(sections: [section])) == null;
      }

      expect(
        rejects((codes) => codes['transcript'] = 'science.fall.foundation'),
        isTrue,
      );
      expect(
        rejects(
          (codes) =>
              codes['meaning'] = 'science.inertia.listening.foundation.meaning',
        ),
        isTrue,
      );
      expect(rejects((codes) => codes.remove('meaning')), isTrue);
      expect(
        rejects((codes) => codes['future'] = 'science.fall.foundation'),
        isTrue,
      );
    });

    test('完了回数だけで3段階を順に巡回し、variant IDは保存しない', () {
      final section = UnitDetail.fromJson(unitJson())!.sectionFor('fall')!;

      expect(
        [
          for (var count = 0; count < 7; count++)
            section.practiceVariantForAttempt(count).stage,
        ],
        [
          LocalPracticeStage.foundation,
          LocalPracticeStage.conditions,
          LocalPracticeStage.transfer,
          LocalPracticeStage.foundation,
          LocalPracticeStage.conditions,
          LocalPracticeStage.transfer,
          LocalPracticeStage.foundation,
        ],
      );
      expect(
        section.practiceVariantForAttempt(-1).stage,
        LocalPracticeStage.foundation,
        reason: '壊れた負数でも配列外参照せず先頭へfail-closedする',
      );
    });

    test('variant段階の順序と旧client用checkpointの一致を強制する', () {
      final wrongOrder = sectionJson('fall');
      final reversed = practiceVariantsJson().reversed.toList();
      wrongOrder['localPracticeVariants'] = reversed;
      expect(UnitDetail.fromJson(unitJson(sections: [wrongOrder])), isNull);

      final mismatched = sectionJson('fall');
      mismatched['localCheckpoint'] = checkpointVariantJson(
        suffix: 'legacy-mismatch',
        correctIndex: 0,
      );
      expect(UnitDetail.fromJson(unitJson(sections: [mismatched])), isNull);
    });

    test('transfer場面に直接対応する結果と理由を必須にする', () {
      final missingOutcome = sectionJson('fall');
      final noOutcomeVariants = practiceVariantsJson();
      noOutcomeVariants[0].remove('expectedOutcome');
      missingOutcome['localPracticeVariants'] = noOutcomeVariants;

      final missingReason = sectionJson('inertia');
      final noReasonVariants = practiceVariantsJson();
      noReasonVariants[2]['expectedReason'] = '   ';
      missingReason['localPracticeVariants'] = noReasonVariants;

      expect(
        UnitDetail.fromJson(
          unitJson(sections: [missingOutcome, missingReason]),
        ),
        isNull,
      );
    });

    test('3種類のcognitiveTaskを厳格に読み、solutionなしpromptを分離する', () {
      final section = UnitDetail.fromJson(unitJson())!.sectionFor('fall')!;
      final tasks = section.localPracticeVariants
          .map((variant) => variant.cognitiveTask)
          .toList();

      expect(tasks.map((task) => task.kind), LocalCognitiveTaskKind.values);
      expect(tasks.map((task) => task.operation), [
        LocalCognitiveOperation.prediction,
        LocalCognitiveOperation.conditionClassify,
        LocalCognitiveOperation.causalOrder,
      ]);
      expect(tasks.first.solution, isA<LocalSingleSelectSolution>());
      expect(tasks[1].solution, isA<LocalClassifySolution>());
      expect(tasks[2].solution, isA<LocalSequenceSolution>());
      expect(tasks.first.prompt.items, tasks.first.items);
      expect(tasks.first.prompt.targets, isEmpty);
      expect(tasks[1].prompt.targets, hasLength(2));

      final roundTrip = LocalCognitiveTask.fromJson(
        jsonDecode(jsonEncode(tasks[1].toJson())) as Map<String, Object?>,
      );
      expect(roundTrip, isNotNull);
      expect((roundTrip!.solution as LocalClassifySolution).targetByItemId, {
        'setup-a': 'group-b',
        'setup-b': 'group-a',
        'setup-c': 'group-b',
      });
    });

    test('cognitiveTaskの未知field・示唆ID・不完全solution・正答順提示を拒否する', () {
      bool rejects(Map<String, Object?> task) {
        final section = sectionJson('fall');
        final variants = practiceVariantsJson();
        variants[0]['cognitiveTask'] = task;
        section['localPracticeVariants'] = variants;
        return UnitDetail.fromJson(unitJson(sections: [section])) == null;
      }

      final missingTask = sectionJson('fall');
      final missingVariants = practiceVariantsJson();
      missingVariants[0].remove('cognitiveTask');
      missingTask['localPracticeVariants'] = missingVariants;
      expect(UnitDetail.fromJson(unitJson(sections: [missingTask])), isNull);

      final unknownVariant = sectionJson('fall');
      final unknownVariants = practiceVariantsJson();
      unknownVariants[0]['answer'] = '保存・公開しない未知field';
      unknownVariant['localPracticeVariants'] = unknownVariants;
      expect(UnitDetail.fromJson(unitJson(sections: [unknownVariant])), isNull);

      expect(
        rejects({...cognitiveTaskJson('foundation'), 'targets': <Object?>[]}),
        isTrue,
      );
      expect(
        rejects({
          ...cognitiveTaskJson('foundation'),
          'items': [
            {'id': 'correct-choice', 'text': '示唆するID'},
            {'id': 'choice-b', 'text': '別の項目'},
          ],
          'solution': {'selectedItemId': 'correct-choice'},
        }),
        isTrue,
      );
      expect(
        rejects({
          ...cognitiveTaskJson('foundation'),
          'solution': {'selectedItemId': 'unknown-item'},
        }),
        isTrue,
      );
      expect(
        rejects({
          ...cognitiveTaskJson('foundation'),
          'items': [
            {'id': 'only-item', 'text': '1件だけ'},
          ],
          'solution': {'selectedItemId': 'only-item'},
        }),
        isTrue,
      );
      expect(
        rejects({
          ...cognitiveTaskJson('conditions'),
          'solution': {
            'targetByItemId': {'setup-a': 'group-b', 'setup-b': 'group-a'},
          },
        }),
        isTrue,
      );
      expect(
        rejects({
          ...cognitiveTaskJson('conditions'),
          'targets': [
            {'id': 'group-a', 'label': '分類先が1件だけ'},
          ],
          'solution': {
            'targetByItemId': {
              'setup-a': 'group-a',
              'setup-b': 'group-a',
              'setup-c': 'group-a',
            },
          },
        }),
        isTrue,
      );
      expect(
        rejects({
          ...cognitiveTaskJson('transfer'),
          'items': [
            {'id': 'event-a', 'text': '出来事A'},
            {'id': 'event-b', 'text': '出来事B'},
            {'id': 'event-c', 'text': '出来事C'},
          ],
        }),
        isTrue,
      );
    });

    test('旧形式fixtureの比較文へcheckpoint正答を流用しない', () {
      final checkpoint = LocalCheckpoint.fromJson(checkpointJson())!;
      final section = Section(
        conceptKey: 'legacy',
        title: '旧形式',
        body: const ['本文'],
        tryIt: '旧形式の具体場面',
        localCheckpoint: checkpoint,
      );

      final variant = section.practiceVariantForAttempt(0);
      final correctText = checkpoint
          .optionFor(checkpoint.correctOptionId)!
          .text;
      expect(variant.expectedOutcome, contains('直接対応する比較結果がありません'));
      expect(variant.expectedReason, contains('流用せず'));
      expect(variant.expectedOutcome, isNot(correctText));
      expect(variant.expectedReason, isNot(checkpoint.explanation));
      expect(variant.cognitiveTask.kind, LocalCognitiveTaskKind.singleSelect);
      expect(variant.cognitiveTask.solution, isA<LocalSingleSelectSolution>());
    });

    test('正答にはhintを付けず、誤答2件にだけhintを要求する', () {
      final section = sectionJson('fall');
      final variants = practiceVariantsJson();
      final first = variants.first;
      final checkpoint = Map<String, Object?>.from(first['checkpoint']! as Map);
      final options = [
        for (final option in checkpoint['options']! as List)
          Map<String, Object?>.from(option as Map),
      ];
      options.firstWhere((option) => option['id'] == 'correct')['hint'] =
          '正答へ事前ヒントを付けてはいけない。';
      checkpoint['options'] = options;
      variants[0] = {...first, 'checkpoint': checkpoint};
      section['localPracticeVariants'] = variants;

      expect(UnitDetail.fromJson(unitJson(sections: [section])), isNull);
    });

    test('読了時間は 30 秒を下回らない', () {
      // 「およそ0分」と出ると始めてよいのか分からない
      final tiny = UnitDetail.fromJson(
        unitJson(
          sections: [
            {
              ...sectionJson('fall'),
              'body': ['短い。'],
              'tryIt': '',
            },
          ],
        ),
      )!;
      expect(tiny.readingTime.inSeconds, greaterThanOrEqualTo(30));
    });
  });

  group('UnitsClient', () {
    UnitsClient client(
      Map<String, Response<Object?> Function()> routes,
      SessionStore store,
    ) => UnitsClient(
      baseUrl: 'https://example.test',
      store: store,
      dio: fakeDio(routes),
    );

    test('取れたら保存する', () async {
      final store = MemorySessionStore();
      final c = client({
        'GET https://example.test/api/units': () =>
            json200('{"schemaVersion":10,"unit":${jsonEncode(unitJson())}}'),
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
            json200('{"schemaVersion":10,"unit":${jsonEncode(unitJson())}}'),
      }, store);
      await ok.detail('force-motion');

      final offline = client({
        'GET https://example.test/api/units': () => jsonRes(500, '{}'),
      }, store);
      final got = await offline.detail('force-motion');
      expect(got, isNotNull, reason: '保存したものを出していない');
      expect(
        got!.sectionFor('fall')?.body.first,
        '1つめの段落。',
        reason: '同梱教材より端末キャッシュを優先する',
      );
    });

    test('新規インストールでAPIが503でも同梱一覧と本文を出す', () async {
      final c = client({
        'GET https://example.test/api/units': () => jsonRes(500, '{}'),
      }, MemorySessionStore());

      final list = await c.list();
      expect(list.map((unit) => unit.id), contains('force-motion'));
      expect(
        list.firstWhere((unit) => unit.id == 'force-motion').concepts,
        isNotEmpty,
      );

      final detail = await c.detail('force-motion');
      expect(detail, isNotNull);
      expect(detail!.sectionFor('fall')?.body, isNotEmpty);
      expect(
        await c.cachedDetail('force-motion'),
        isNotNull,
        reason: '通信しない端末内経路でも同梱教材を読める',
      );
    });

    test('v10同梱カタログの全coverage・Story・Notation・固定needが揃う', () async {
      final c = UnitsClient(baseUrl: '', store: MemorySessionStore());
      final list = await c.list();
      expect(list, hasLength(8));
      expect(
        list.fold<int>(0, (count, unit) => count + unit.concepts.length),
        23,
      );

      final currentMagnetism = list.firstWhere(
        (unit) => unit.id == 'current-magnetism',
      );
      expect(currentMagnetism.concepts.map((concept) => concept.key), [
        'currentMagneticField',
        'magneticForce',
        'electromagneticInduction',
      ]);

      var cognitiveNeedCount = 0;
      var wrongNeedCount = 0;
      var notationNeedCount = 0;
      var notationTraceCount = 0;
      final practiceNeedCodes = <String>{};
      final notationNeedCodes = <String>{};
      final storyTitles = <String>{};
      final curriculumFields = <UnitCurriculumField>{};

      for (final summary in list) {
        final detail = await c.detail(summary.id);
        expect(detail, isNotNull, reason: '${summary.id}: 同梱詳細が無い');
        for (final concept in summary.concepts) {
          final section = detail!.sectionFor(concept.key);
          expect(section, isNotNull, reason: '${summary.id}/${concept.key}');
          expect(
            concept.storyTitle,
            section!.scienceStory?.title,
            reason: '${summary.id}/${concept.key}: 一覧と詳細の事件名が不一致',
          );
          curriculumFields.add(concept.field);
          expect(concept.grade, inInclusiveRange(1, 3));
          expect(concept.curriculumRefs, isNotEmpty);
          expect(concept.difficulty, inInclusiveRange(1, 5));
          expect(concept.safety.guidance.trim(), isNotEmpty);
          storyTitles.add(concept.storyTitle);
          final variants = section.localPracticeVariants;
          final notation = section.notationLab;
          expect(notation, isNotNull, reason: '${summary.id}/${concept.key}');
          expect(notation!.tasks, hasLength(inInclusiveRange(3, 4)));
          expect(section.scienceStory, isNotNull);
          expect(section.localSpeakingPractice, isNotNull);
          expect(
            section.localSpeakingPractice!.targetPhrase.runes.length,
            inInclusiveRange(12, 80),
          );
          expect(
            section.localSpeakingPractice!.acceptedTranscripts.first,
            section.localSpeakingPractice!.targetPhrase,
          );
          expect(
            section.scienceStory!.foundationNeedCode,
            'science.${concept.key}.foundation',
          );
          expect(
            notation.tasks.map((task) => task.id).toSet(),
            hasLength(notation.tasks.length),
          );
          for (final task in notation.tasks) {
            notationNeedCount++;
            notationNeedCodes.add(task.needCode!);
            expect(
              task.needCode,
              startsWith('science.${concept.key}.notation.'),
            );
            switch (task) {
              case LocalNotationArrangeTask():
                expect(task.tokens, hasLength(greaterThanOrEqualTo(2)));
                expect(
                  task.tokens.map((token) => token.id),
                  isNot(task.correctOrderIds),
                  reason: '${summary.id}/${concept.key}/${task.id}: 表示順で正答を示す',
                );
                final trace = task.tracePattern;
                if (trace != null) {
                  notationTraceCount++;
                  expect(trace.strokes, isNotEmpty);
                  expect(
                    trace.strokeOrderIds.toSet(),
                    trace.strokes.map((stroke) => stroke.id).toSet(),
                  );
                }
              case LocalNotationChoiceTask():
                expect(task.choices, hasLength(greaterThanOrEqualTo(2)));
                expect(
                  task.choices.map((choice) => choice.id),
                  contains(task.correctChoiceId),
                );
            }
          }
          expect(variants, hasLength(3));
          expect(
            variants.map((variant) => variant.stage),
            LocalPracticeStage.values,
          );
          expect(
            variants.map((variant) => variant.cognitiveTask.kind).toSet(),
            hasLength(greaterThanOrEqualTo(2)),
            reason: '${summary.id}/${concept.key}: 3周とも同じ操作',
          );
          expect(
            variants.map((variant) => variant.checkpoint.lure).toSet(),
            hasLength(3),
            reason: '${summary.id}/${concept.key}: 2周目以降も同じ問題',
          );
          expect(
            variants
                .map(
                  (variant) => jsonEncode([
                    variant.transferPrompt,
                    variant.expectedOutcome,
                    variant.expectedReason,
                  ]),
                )
                .toSet(),
            hasLength(3),
            reason: '${summary.id}/${concept.key}: 場面と直接回答を再利用',
          );
          expect(
            variants
                .map(
                  (variant) => variant.checkpoint.options.indexWhere(
                    (option) => option.id == variant.checkpoint.correctOptionId,
                  ),
                )
                .toSet(),
            {0, 1, 2},
            reason: '${summary.id}/${concept.key}: 正答位置を覚えて通過できる',
          );
          for (final variant in variants) {
            final expectedNeed = 'science.${concept.key}.${variant.stage.wire}';
            cognitiveNeedCount++;
            practiceNeedCodes.add(variant.cognitiveTask.needCode!);
            expect(variant.cognitiveTask.needCode, expectedNeed);
            expect(variant.recallPrompt.trim(), isNotEmpty);
            expect(variant.reasoningPrompt.trim(), isNotEmpty);
            expect(variant.transferPrompt.trim(), isNotEmpty);
            expect(variant.expectedOutcome.trim(), isNotEmpty);
            expect(variant.expectedReason.trim(), isNotEmpty);
            expect(variant.checkpoint.options, hasLength(3));
            final correct = variant.checkpoint.optionFor(
              variant.checkpoint.correctOptionId,
            )!;
            expect(variant.expectedOutcome, isNot(correct.text));
            expect(
              variant.expectedReason,
              isNot(variant.checkpoint.explanation),
            );
            for (final option in variant.checkpoint.options) {
              if (option.id == variant.checkpoint.correctOptionId) {
                expect(option.hint, isNull);
                expect(option.needCode, isNull);
              } else {
                expect(option.hint?.trim(), isNotEmpty);
                expect(option.needCode, expectedNeed);
                expect(option.needCode, isNot(option.id));
                wrongNeedCount++;
              }
            }
          }
        }
      }
      expect(cognitiveNeedCount, 69);
      expect(wrongNeedCount, 138);
      expect(notationNeedCount, 80);
      expect(notationTraceCount, 22);
      expect(practiceNeedCodes, hasLength(69));
      expect(notationNeedCodes, hasLength(80));
      expect(storyTitles, hasLength(23));
      expect(curriculumFields, UnitCurriculumField.values.toSet());
    });

    test('一覧も保存して出す', () async {
      final store = MemorySessionStore();
      final body = jsonEncode({
        'schemaVersion': 10,
        'units': [unitJson()..remove('sections')],
      });
      final ok = client({
        'GET https://example.test/api/units': () => json200(body),
      }, store);
      expect((await ok.list()).length, 1);

      final offline = client({
        'GET https://example.test/api/units': () => jsonRes(500, '{}'),
      }, store);
      final list = await offline.list();
      expect(list.length, 1);
      expect(list.first.concepts.length, 2);
      expect(list.first.brief, 'ざっくりした紹介。', reason: '同梱一覧より端末キャッシュを優先する');
    });

    test('online一覧の未知schemaはv10として部分採用しない', () async {
      final online = unitJson()
        ..remove('sections')
        ..['brief'] = 'onlineの一覧。';
      final bundled = unitJson()..['brief'] = '同梱正本の一覧。';
      final c = UnitsClient(
        baseUrl: 'https://example.test',
        store: MemorySessionStore(),
        dio: fakeDio({
          'GET https://example.test/api/units': () => json200(
            jsonEncode({
              'schemaVersion': 11,
              'units': [online],
            }),
          ),
        }),
        assetBundle: _JsonAssetBundle(
          jsonEncode({
            'schemaVersion': 10,
            'language': 'ja',
            'units': [bundled],
          }),
        ),
      );

      final got = await c.list();
      expect(got, hasLength(1));
      expect(got.single.brief, '同梱正本の一覧。');
    });

    test('online一覧のroot未知fieldがあれば全体を拒否する', () async {
      final online = unitJson()
        ..remove('sections')
        ..['brief'] = 'onlineの一覧。';
      final bundled = unitJson()..['brief'] = '同梱正本の一覧。';
      final c = UnitsClient(
        baseUrl: 'https://example.test',
        store: MemorySessionStore(),
        dio: fakeDio({
          'GET https://example.test/api/units': () => json200(
            jsonEncode({
              'schemaVersion': 10,
              'units': [online],
              'unexpected': true,
            }),
          ),
        }),
        assetBundle: _JsonAssetBundle(
          jsonEncode({
            'schemaVersion': 10,
            'language': 'ja',
            'units': [bundled],
          }),
        ),
      );

      final got = await c.list();
      expect(got, hasLength(1));
      expect(got.single.brief, '同梱正本の一覧。');
    });

    test('online一覧は壊れたunitが1件でもあれば全体を拒否する', () async {
      final validOnline = unitJson()
        ..remove('sections')
        ..['brief'] = '部分採用してはいけないonline一覧。';
      final brokenOnline = Map<String, Object?>.from(validOnline)
        ..['id'] = 'broken-unit'
        ..['title'] = '';
      final bundled = unitJson()..['brief'] = '同梱正本の一覧。';
      final c = UnitsClient(
        baseUrl: 'https://example.test',
        store: MemorySessionStore(),
        dio: fakeDio({
          'GET https://example.test/api/units': () => json200(
            jsonEncode({
              'schemaVersion': 10,
              'units': [validOnline, brokenOnline],
            }),
          ),
        }),
        assetBundle: _JsonAssetBundle(
          jsonEncode({
            'schemaVersion': 10,
            'language': 'ja',
            'units': [bundled],
          }),
        ),
      );

      final got = await c.list();
      expect(got, hasLength(1));
      expect(got.single.brief, '同梱正本の一覧。');
    });

    test('v10 cache一覧も壊れたunitを部分採用せず同梱へ退避する', () async {
      final cached = unitJson()
        ..remove('sections')
        ..['brief'] = '部分採用してはいけないcache一覧。';
      final brokenCached = Map<String, Object?>.from(cached)
        ..['id'] = 'broken-cache-unit'
        ..['unexpected'] = true;
      final store = MemorySessionStore();
      await store.setSetting(
        'units.v10.list',
        jsonEncode([cached, brokenCached]),
      );
      final bundled = unitJson()..['brief'] = '同梱正本の一覧。';
      final c = UnitsClient(
        baseUrl: 'https://example.test',
        store: store,
        dio: fakeDio({
          'GET https://example.test/api/units': () => jsonRes(503, '{}'),
        }),
        assetBundle: _JsonAssetBundle(
          jsonEncode({
            'schemaVersion': 10,
            'language': 'ja',
            'units': [bundled],
          }),
        ),
      );

      final got = await c.list();
      expect(got, hasLength(1));
      expect(got.single.brief, '同梱正本の一覧。');
    });

    test('接続先が無ければ通信しない', () async {
      final c = UnitsClient(baseUrl: '', store: MemorySessionStore());
      expect(await c.list(), isNotEmpty);
      expect(await c.detail('force-motion'), isNotNull);
    });

    test('壊れたキャッシュは同梱教材へ退避する', () async {
      final store = MemorySessionStore();
      await store.setSetting('units.list', '{broken');
      await store.setSetting(
        'units.detail.force-motion',
        jsonEncode({...unitJson(), 'sections': <Object?>[]}),
      );
      final c = client({
        'GET https://example.test/api/units': () => jsonRes(503, '{}'),
      }, store);

      expect((await c.list()).map((unit) => unit.id), contains('force-motion'));
      expect((await c.detail('force-motion'))?.sectionFor('fall'), isNotNull);
    });

    test('無version保存keyとneed正本の無い旧cacheは捨ててv10同梱教材へ退避する', () async {
      final store = MemorySessionStore();
      final oldDetail = unitJson();
      for (final section
          in (oldDetail['sections']! as List<Map<String, Object?>>)) {
        section.remove('notationLab');
      }
      await store.setSetting(
        'units.detail.force-motion',
        jsonEncode(oldDetail),
      );
      final c = client({
        'GET https://example.test/api/units': () => jsonRes(503, '{}'),
      }, store);

      final got = await c.detail('force-motion');
      expect(got?.sectionFor('fall')?.notationLab?.orderTasks, hasLength(2));
      expect(
        got?.sectionFor('fall')?.localCheckpoint.lure,
        isNot('重いものほど先に着く。'),
        reason: '旧キャッシュではなく正本から生成したv10同梱教材を使う',
      );
    });

    test('v9 cache keyの一覧とdetailをv10へ混ぜない', () async {
      final store = MemorySessionStore();
      await store.setSetting(
        'units.v9.list',
        jsonEncode([
          {
            'id': 'v9-only',
            'title': '旧一覧',
            'brief': 'v10へ混ぜない',
            'concepts': const <Object?>[],
            'sectionCount': 1,
          },
        ]),
      );
      final oldDetail = unitJson();
      for (final section
          in (oldDetail['sections']! as List<Map<String, Object?>>)) {
        section['body'] = ['v9 cacheだけの本文'];
      }
      await store.setSetting(
        'units.v9.detail.force-motion',
        jsonEncode(oldDetail),
      );
      final c = client({
        'GET https://example.test/api/units': () => jsonRes(503, '{}'),
      }, store);

      expect(
        (await c.list()).map((unit) => unit.id),
        isNot(contains('v9-only')),
      );
      final got = await c.detail('force-motion');
      expect(got?.sectionFor('fall')?.body, isNot(contains('v9 cacheだけの本文')));
      expect(
        got
            ?.sectionFor('fall')
            ?.localPracticeVariants
            .every((variant) => variant.listeningNeedCodes != null),
        isTrue,
      );
    });

    test('v9と未知schemaの同梱カタログはv10として読まない', () async {
      final c = UnitsClient(
        baseUrl: '',
        store: MemorySessionStore(),
        assetBundle: _JsonAssetBundle(
          jsonEncode({
            'schemaVersion': 9,
            'language': 'ja',
            'units': [unitJson()],
          }),
        ),
      );

      expect(await c.list(), isEmpty);
      expect(await c.detail('force-motion'), isNull);

      final future = UnitsClient(
        baseUrl: '',
        store: MemorySessionStore(),
        assetBundle: _JsonAssetBundle(
          jsonEncode({
            'schemaVersion': 11,
            'language': 'ja',
            'units': [unitJson()],
          }),
        ),
      );
      expect(await future.list(), isEmpty);
      expect(await future.detail('force-motion'), isNull);
    });

    test('同梱カタログにも無い単元は null のまま', () async {
      final c = client({
        'GET https://example.test/api/units': () => jsonRes(503, '{}'),
      }, MemorySessionStore());
      expect(await c.detail('unknown-unit'), isNull);
    });
  });
}
