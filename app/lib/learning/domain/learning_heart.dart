/// 固定課題の誤答を、回答や選択内容を渡さず通知するためのDTO。
///
/// [fixedTaskId] はcatalog内の問題位置だけを表す安定ID。選んだ選択肢、
/// 入力本文、音声、正誤、反応時間は含めない。保存層の冪等loss IDは、Homeが
/// run IDと連番を組み合わせて生成する。
final class LearningHeartLossEvidence {
  const LearningHeartLossEvidence({required this.fixedTaskId})
    : assert(fixedTaskId != '');

  final String fixedTaskId;
}

typedef LearningHeartLossReported =
    void Function(LearningHeartLossEvidence evidence);
