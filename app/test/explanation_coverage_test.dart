import 'package:dekisugi/learning/domain/explanation_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractCueTerms', () {
    test('漢字・カタカナ・英数字の連なりを拾い、足場語と1字を落とす', () {
      final terms = extractCueTerms(
        '空気抵抗を無視すれば、落下の速さは重さによらない。'
        'ニュートンでCO2を調べる場合の説明。',
      );
      expect(terms, containsAll(['空気抵抗', '無視', '落下', 'CO2']));
      // 「重さ」「速さ」の「さ」はひらがななので漢字runには残らない。
      expect(terms, isNot(contains('重')));
      expect(terms, isNot(contains('説明')));
      expect(terms, isNot(contains('場合')));
      expect(terms, isNot(contains('速')));
    });
  });

  group('assessExplanation', () {
    const sources = [
      '空気抵抗を無視すれば落下の速さは重さによらない。',
      '重さや空気の条件で結果と原理が変わる。',
    ];

    test('無関係な文字列は聞き取れない', () {
      final coverage = assessExplanation('asdf qwerty', sources: sources);
      expect(coverage.isAssessable, isTrue);
      expect(coverage.matchedTerms, isEmpty);
      expect(coverage.isSufficient, isFalse);
    });

    test('概念の言葉が点在する説明は聞き取れる', () {
      final coverage = assessExplanation(
        '空気抵抗を無視すると重さによらず、形や空気の条件も見る。',
        sources: sources,
      );
      expect(coverage.matchedTerms, containsAll(['空気抵抗', '無視', '条件']));
      expect(coverage.isSufficient, isTrue);
    });

    test('語幹の漢字でも同じ言葉として拾う', () {
      final coverage = assessExplanation(
        '重いほど速く落ちると思う。',
        sources: const ['重力の大きさと落下の速さの関係です。'],
      );
      // 「重い」は「重力」の語幹、「落ちる」は「落下」の語幹。
      expect(coverage.matchedTerms, containsAll(['重力', '落下']));
      expect(coverage.isSufficient, isTrue);
    });

    test('ひらがな表記はカタカナ語へ届く', () {
      final coverage = assessExplanation(
        'えねるぎーが移ると温度が上がる',
        sources: const ['エネルギー保存と温度上昇の関係です。'],
      );
      expect(coverage.matchedTerms, contains('エネルギー'));
    });

    test('cueが取れない教材では塞がない', () {
      final coverage = assessExplanation('asdf', sources: const ['そうだね。']);
      expect(coverage.isAssessable, isFalse);
      expect(coverage.isSufficient, isTrue);
    });

    test('1語だけでは足りない概念はもう少し聞く', () {
      final coverage = assessExplanation(
        '落下について説明する',
        sources: sources,
      );
      expect(coverage.matchedTerms, contains('落下'));
      expect(coverage.requiredHits, 2);
      expect(coverage.isSufficient, isFalse);
    });
  });
}
