import '../../config/app_language.dart';
import 'learning_karte_projection.dart';

/// A local, transparent next-review suggestion, not a learner diagnosis.
String familyReviewPlan(LearningKarteView view) {
  final active = view.concepts.where((entry) => entry.hasActiveNeeds);
  final practiced = view.concepts.where((entry) => entry.taught);
  final next =
      active.firstOrNull ?? practiced.firstOrNull ?? view.concepts.firstOrNull;
  if (next == null) {
    return t(
      '教材を選んで、一度説明してから復習プランを作ります。',
      'Choose a lesson and teach once to create a review plan.',
    );
  }
  return [
    t('家族で使う復習プラン', 'Family review plan'),
    t(
      '次のテーマ：${next.label}（${next.unitTitle}）',
      'Next topic: ${next.label} (${next.unitTitle})',
    ),
    next.hasActiveNeeds
        ? t(
            '選んだ理由：このテーマに、まだ一緒に確かめる観察記録があります。',
            'Why this topic: its record includes a question still being explored.',
          )
        : next.taught
        ? t(
            '選んだ理由：一度取り組んだテーマを、間隔を空けて思い出します。',
            'Why this topic: revisit a topic already practiced, after a delay.',
          )
        : t(
            '選んだ理由：まだ観察記録がないテーマです。能力の判定ではありません。',
            'Why this topic: no observation is recorded yet. This is not an ability judgment.',
          ),
    '',
    t(
      '1. 次の復習で、教材を閉じて説明してもらう。',
      '1. At the next review, ask for an explanation with the material hidden.',
    ),
    t(
      '保護者の問い：「${next.label}の仕組みを、自分の言葉で教えて。どんな条件が大切？」',
      'Parent prompt: “Explain ‘${next.label}’ in your own words. Which conditions matter?”',
    ),
    t(
      '2. 新しい場面：「条件を一つ変えたら、予想はどう変わる？なぜ？」',
      '2. New situation: “If one condition changes, how does your prediction change? Why?”',
    ),
    t(
      '3. 教材と照らし合わせ、条件と理由を確かめる。翌日以降、別の例でも説明してもらう。',
      '3. Reopen the material and check the conditions and reasoning. On a later day, ask about a different example.',
    ),
    '',
    t(
      '記録から分かるのは、固定の確認に取り組んだことです。自力での理解・応用・定着は、この問いで別に確かめてください。',
      'The record shows work on fixed checks. Independent understanding, transfer and retention must be checked separately with these prompts.',
    ),
    t(
      'レポートは端末内で生成します。回答本文・音声・個人の点数を含みません。共有は保護者へコピーする場合だけです。',
      'Generated on this device. No answer text, audio or personal scores are included. Sharing happens only when you choose to copy it.',
    ),
  ].join('\n');
}
