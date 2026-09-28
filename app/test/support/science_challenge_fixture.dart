import 'package:dekisugi/models/unit.dart';

const challengeCheckpoint = LocalCheckpoint(
  lure: '空気のない場所でも、重い球のほうが先に着く。',
  options: [
    LocalCheckpointOption(
      id: 'heavy-first',
      text: '重い球が先に着く。',
      hint: '重力と動かしにくさを一緒に比べます。',
      needCode: 'science.fall.transfer',
    ),
    LocalCheckpointOption(id: 'same-time', text: '2つは同時に着く。'),
    LocalCheckpointOption(
      id: 'light-first',
      text: '軽い球が先に着く。',
      hint: '重さだけで落下加速度は変わりません。',
      needCode: 'science.fall.transfer',
    ),
  ],
  correctOptionId: 'same-time',
  explanation: '空気抵抗を無視すれば、落下加速度は重さによりません。',
);

const challengeTask = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  needCode: 'science.fall.transfer',
  items: [
    LocalCognitiveTaskItem(id: 'task-heavy', text: '重い球が先に着く'),
    LocalCognitiveTaskItem(id: 'task-together', text: '2つは同時に着く'),
    LocalCognitiveTaskItem(id: 'task-light', text: '軽い球が先に着く'),
  ],
  targets: [],
  solution: LocalSingleSelectSolution(selectedItemId: 'task-together'),
);

const challengeVariant = LocalPracticeVariant(
  stage: LocalPracticeStage.transfer,
  recallPrompt: '落下の原理を思い出す。',
  reasoningPrompt: '条件と結び付ける。',
  transferPrompt: '真空中で重さだけが違う2球を同時に放すと、どうなる？',
  expectedOutcome: '2個の球は同時に底へ着きます。',
  expectedReason: '真空中の落下加速度は重さによらないためです。',
  cognitiveTask: challengeTask,
  checkpoint: challengeCheckpoint,
  listeningNeedCodes: LocalListeningNeedCodes(
    transcript: 'science.fall.listening.transfer.transcript',
    meaning: 'science.fall.listening.transfer.meaning',
  ),
);

const challengePracticeAttempt = 2;

const challengeSection = Section(
  conceptKey: 'fall',
  title: '落下の速さ',
  body: ['空気抵抗を無視すれば、落下加速度は重さによりません。'],
  tryIt: '真空中で2個の球を落として比べる。',
  localCheckpoint: challengeCheckpoint,
  localPracticeVariants: [
    LocalPracticeVariant(
      stage: LocalPracticeStage.foundation,
      recallPrompt: '落下の原理を思い出す。',
      reasoningPrompt: '重さと加速度を結び付ける。',
      transferPrompt: '同じ形の2個の球を空気中で落とすと、どうなる？',
      expectedOutcome: '空気抵抗の差が小さければ、ほぼ同時に着きます。',
      expectedReason: '形をそろえると空気抵抗の差を小さくできるためです。',
      cognitiveTask: challengeTask,
      checkpoint: challengeCheckpoint,
      listeningNeedCodes: LocalListeningNeedCodes(
        transcript: 'science.fall.listening.foundation.transcript',
        meaning: 'science.fall.listening.foundation.meaning',
      ),
    ),
    LocalPracticeVariant(
      stage: LocalPracticeStage.conditions,
      recallPrompt: '条件を思い出す。',
      reasoningPrompt: '条件を比べる。',
      transferPrompt: '空気抵抗がある場面を比べる。',
      expectedOutcome: '形によって着地時刻に差が出ます。',
      expectedReason: '空気抵抗の影響が異なるためです。',
      cognitiveTask: challengeTask,
      checkpoint: challengeCheckpoint,
      listeningNeedCodes: LocalListeningNeedCodes(
        transcript: 'science.fall.listening.conditions.transcript',
        meaning: 'science.fall.listening.conditions.meaning',
      ),
    ),
    challengeVariant,
  ],
);
