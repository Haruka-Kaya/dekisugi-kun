import 'package:flutter/services.dart';

import '../config/app_language.dart' as lang;
import '../ui/_material.dart';
import '../widgets/readable_width.dart';

/// Optional, device-local before/after check. No network or persistence.
/// These draft items are not a validated measure of learning efficacy.
class UnderstandingCheckScreen extends StatefulWidget {
  const UnderstandingCheckScreen({super.key});

  @override
  State<UnderstandingCheckScreen> createState() =>
      _UnderstandingCheckScreenState();
}

class _UnderstandingCheckScreenState extends State<UnderstandingCheckScreen> {
  int _step = -1;
  int? _selected;
  final _answers = <int>[];
  final _explanation = TextEditingController();
  bool _hidden = false;
  bool _feedback = false;

  @override
  void dispose() {
    _explanation.dispose();
    super.dispose();
  }

  int _count(int start, int end) => List.generate(
    end - start,
    (i) => start + i,
  ).where((i) => _answers[i] == _items[i].correct).length;

  Future<void> _copy() async {
    // Aggregate counts only, deliberately excluding the explanation/answers.
    await Clipboard.setData(
      ClipboardData(
        text:
            'protocol,before_correct,before_total,after_correct,after_total,transfer_correct,transfer_total\n'
            'fall-check-v1,${_count(0, 3)},3,${_count(3, 6)},3,${_count(6, 7)},1\n'
            'Draft same-session self-check; not proof of efficacy or long-term retention.',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lang.t('集計をコピーしました', 'Counts copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questionIndex = _step < 3 ? _step : _step - 1;
    final result = _step == 8;
    final lesson = _step == 3;
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('理解を確かめる（無料）', 'Understanding check · Free')),
      ),
      body: ReadableWidth(
        child: ListView(
          key: ValueKey(_step),
          padding: const EdgeInsets.all(20),
          children: [
            if (_step == -1) ...[
              Text(
                lang.t('落下：学ぶ前と後で確かめる', 'Falling: check before and after'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                lang.t(
                  '先に3問、教材を読んで説明、別の3問、最後に新しい場面の1問。教材を閉じてデキすぎ君に教えます。正答は最後まで出しません。',
                  'Answer 3 questions, read and teach with the material hidden, answer 3 different questions, then try 1 new situation. Correct answers appear only at the end.',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                lang.t(
                  'これは未検証の自己確認です。短時間の変化は長期的な学習効果の証明になりません。回答・説明・点数は保存も送信もしません。閉じると消えます。集計のコピーは自分で選べます。',
                  'This is a draft self-check, not a validated test. A same-session change does not prove lasting learning. Answers, explanation and counts are never saved or sent. They disappear when you leave. You can choose to copy aggregate counts.',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('check-start'),
                onPressed: () => setState(() => _step = 0),
                child: Text(lang.t('確認を始める', 'Start check')),
              ),
            ] else if (lesson) ...[
              Text(
                lang.t('このあと、デキすぎ君に説明します', 'Next, you will teach Dekisugi-kun'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (!_hidden) ...[
                Text(
                  lang.t(
                    '重力だけが働くとき、同じ場所で落ちる物の加速度は質量によらず同じです。空気抵抗があると、形や表面積が落下に影響します。比較するには、高さ・放す時刻・初速度などの条件をそろえます。',
                    'When gravity is the only force, objects at the same location fall with the same acceleration regardless of mass. With air resistance, shape and surface area affect falling. To compare objects fairly, match height, release time and initial velocity.',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const ValueKey('check-hide'),
                  onPressed: () => setState(() => _hidden = true),
                  child: Text(lang.t('教材を閉じて教える', 'Hide material and teach')),
                ),
              ] else ...[
                Text(
                  lang.t(
                    'デキすぎ君「重い物はいつでも先に落ちるんだよね？」条件も含めて説明してください。',
                    'Dekisugi-kun: “Heavier objects always land first, right?” Teach him why the conditions matter.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('check-explanation'),
                  controller: _explanation,
                  minLines: 3,
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: lang.t('あなたの説明', 'Your explanation'),
                  ),
                ),
                const SizedBox(height: 16),
                if (!_feedback)
                  FilledButton(
                    key: const ValueKey('check-teach'),
                    onPressed: _explanation.text.trim().isEmpty
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            setState(() => _feedback = true);
                          },
                    child: Text(lang.t('デキすぎ君に教える', 'Teach Dekisugi-kun')),
                  ),
                if (_feedback) ...[
                  Text(
                    lang.t(
                      'デキすぎ君「『いつでも』は違うね。空気抵抗がなければ質量だけでは差がつかない。空気があると形も関係するね。」これは固定の返事で、説明の自動採点ではありません。',
                      'Dekisugi-kun: “Always was too strong. Without air resistance, mass alone does not change the fall. In air, shape matters too.” This is fixed feedback, not automatic grading of your explanation.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang.t(
                      'デキすぎ君「では、月で同じ高さから放したらどうなる？」次の問題で確かめよう。',
                      'Dekisugi-kun: “What if they were released from the same height on the Moon?” Try the next questions.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey('check-after'),
                    onPressed: () => setState(() => _step = 4),
                    child: Text(lang.t('学んだ後の確認へ', 'Check after teaching')),
                  ),
                ],
              ],
            ] else if (result) ...[
              Text(
                lang.t('今回の確認', 'This session'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                lang.t(
                  '学ぶ前 ${_count(0, 3)}/3 → 学んだ後 ${_count(3, 6)}/3\n新しい場面 ${_count(6, 7)}/1',
                  'Before ${_count(0, 3)}/3 → After ${_count(3, 6)}/3\nNew situation ${_count(6, 7)}/1',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                lang.t(
                  '問題の難しさはそろっていると未検証です。正答数の差だけで上達を断定できません。時間を空け、違う問題でも説明できるか確かめてください。',
                  'These forms have not been validated as equally difficult. A count difference cannot establish improvement. Try different questions after a delay and explain your reasoning.',
                ),
              ),
              const SizedBox(height: 20),
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '${item.prompt}\n${lang.t('正答', 'Correct answer')}: ${item.options[item.correct]}\n${item.reason}',
                  ),
                ),
              OutlinedButton.icon(
                key: const ValueKey('check-copy'),
                onPressed: _copy,
                icon: const Icon(Icons.copy),
                label: Text(
                  lang.t('集計だけコピー（任意）', 'Copy counts only · Optional'),
                ),
              ),
            ] else ...[
              Text(
                questionIndex < 3
                    ? lang.t(
                        '学ぶ前 ${questionIndex + 1}/3',
                        'Before learning ${questionIndex + 1}/3',
                      )
                    : questionIndex < 6
                    ? lang.t(
                        '学んだ後 ${questionIndex - 2}/3',
                        'After teaching ${questionIndex - 2}/3',
                      )
                    : lang.t('新しい場面 1/1', 'New situation 1/1'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                _items[questionIndex].prompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _items[questionIndex].options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    key: ValueKey('check-option-$i'),
                    onPressed: () => setState(() => _selected = i),
                    child: Row(
                      children: [
                        Icon(
                          _selected == i
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_items[questionIndex].options[i])),
                      ],
                    ),
                  ),
                ),
              FilledButton(
                key: const ValueKey('check-next'),
                onPressed: _selected == null
                    ? null
                    : () => setState(() {
                        _answers.add(_selected!);
                        _selected = null;
                        _step++;
                      }),
                child: Text(lang.t('回答を決めて次へ', 'Confirm and continue')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Item {
  const _Item(this.prompt, this.options, this.correct, this.reason);
  final String prompt;
  final List<String> options;
  final int correct;
  final String reason;
}

List<_Item> get _items => [
  _Item(
    lang.t(
      '真空の同じ高さで、重い球と軽い球を同時に静かに放すと？',
      'In a vacuum, a heavy and a light ball are released together from rest at the same height. What happens?',
    ),
    [
      lang.t('重い球が先', 'Heavy ball first'),
      lang.t('同時に着く', 'They land together'),
      lang.t('軽い球が先', 'Light ball first'),
    ],
    1,
    lang.t(
      '質量だけでは落下の加速度は変わりません。',
      'Mass alone does not change gravitational acceleration.',
    ),
  ),
  _Item(
    lang.t(
      '空気中で、同じ紙を丸めると平らな紙より速く落ちる理由は？',
      'Why does a crumpled sheet usually fall faster than the same sheet laid flat in air?',
    ),
    [
      lang.t('空気抵抗の影響が変わる', 'Air resistance changes'),
      lang.t('重力が消える', 'Gravity disappears'),
      lang.t('質量が増える', 'Mass increases'),
    ],
    0,
    lang.t(
      '形と表面積で空気抵抗の影響が変わります。',
      'Shape and surface area change the effect of air resistance.',
    ),
  ),
  _Item(
    lang.t(
      '2つの球の落下時間を公平に比べる条件は？',
      'Which setup fairly compares two balls falling?',
    ),
    [
      lang.t('片方だけ投げ下ろす', 'Throw only one downward'),
      lang.t('高さを変える', 'Use different heights'),
      lang.t(
        '同じ高さから同時に静かに放す',
        'Release both together from rest at the same height',
      ),
    ],
    2,
    lang.t(
      '高さ・放す時刻・初速度をそろえます。',
      'Match height, release time and initial velocity.',
    ),
  ),
  _Item(
    lang.t(
      '空気がほぼない月で、羽とハンマーを同じ高さから同時に静かに放すと？',
      'On the Moon, with negligible air, a feather and hammer are released together from rest at the same height. What happens?',
    ),
    [
      lang.t('同時に着く', 'They land together'),
      lang.t('ハンマーが先', 'Hammer first'),
      lang.t('羽が浮く', 'The feather floats'),
    ],
    0,
    lang.t(
      '空気抵抗がなければ、質量だけで差はつきません。',
      'Without air resistance, mass alone does not create a difference.',
    ),
  ),
  _Item(
    lang.t(
      '同じ物にパラシュートを付けると落下が遅くなる主な理由は？',
      'Why does adding a parachute mainly slow the fall of the same object?',
    ),
    [
      lang.t('重力がなくなる', 'Gravity vanishes'),
      lang.t('空気抵抗が増える', 'Air resistance increases'),
      lang.t('時間が止まる', 'Time stops'),
    ],
    1,
    lang.t('パラシュートが空気抵抗を増やします。', 'The parachute increases air resistance.'),
  ),
  _Item(
    lang.t(
      '小石を高い所から、別の石を低い所から放した結果だけで「重い方が速い」と言える？',
      'One stone is released higher than another. Can their landing times alone show that heavier objects fall faster?',
    ),
    [
      lang.t('どんな条件でも言える', 'Yes, in all conditions'),
      lang.t('重い方だけ見ればよい', 'Only watch the heavier one'),
      lang.t('高さなどの条件が違うので言えない', 'No; conditions such as height differ'),
    ],
    2,
    lang.t(
      '質量以外の条件がそろっていません。',
      'Conditions other than mass are not controlled.',
    ),
  ),
  _Item(
    lang.t(
      '空気のない落下塔で、平らな紙と同じ紙を丸めたものを同じ高さから同時に静かに放すと？',
      'In an evacuated drop tower, a flat sheet and an identical crumpled sheet are released together from rest at the same height. What happens?',
    ),
    [
      lang.t('丸めた紙が先', 'Crumpled sheet first'),
      lang.t('平らな紙が先', 'Flat sheet first'),
      lang.t('同時に着く', 'They land together'),
    ],
    2,
    lang.t(
      '空気抵抗がなければ、形による空気抵抗の差もなくなります。',
      'Without air, the difference in air resistance due to shape disappears.',
    ),
  ),
];
