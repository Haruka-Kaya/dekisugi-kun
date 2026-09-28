import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/unit.dart';
import '../ui/_material.dart';

/// 端末内の科学タスクに対する、画面内だけの回答。
///
/// 正答は持たず、保存用の変換も提供しない。呼び出し元がrouteを破棄すると
/// 一緒に消える、操作中の表示状態だけを表す。
sealed class CognitiveTaskResponse {
  const CognitiveTaskResponse();
}

class SingleSelectTaskResponse extends CognitiveTaskResponse {
  const SingleSelectTaskResponse(this.selectedItemId);

  final String selectedItemId;
}

class ClassifyTaskResponse extends CognitiveTaskResponse {
  ClassifyTaskResponse(Map<String, String> targetByItemId)
    : targetByItemId = Map.unmodifiable(targetByItemId);

  final Map<String, String> targetByItemId;
}

class SequenceTaskResponse extends CognitiveTaskResponse {
  SequenceTaskResponse(List<String> orderedItemIds)
    : orderedItemIds = List.unmodifiable(orderedItemIds);

  final List<String> orderedItemIds;
}

/// 正答を含まないpromptだけを受け取る、3種類の科学タスク入力。
///
/// 正誤判定はせず、回答が完成したかどうかも呼び出し元が
/// [isCognitiveTaskResponseComplete] で確認する。選択肢の順番は教材の著者順を
/// そのまま使い、ランダム化しない。
class CognitiveTaskInput extends StatelessWidget {
  const CognitiveTaskInput({
    super.key,
    required this.prompt,
    required this.response,
    required this.onChanged,
  });

  final LocalCognitiveTaskPrompt prompt;
  final CognitiveTaskResponse? response;
  final ValueChanged<CognitiveTaskResponse> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('cognitive-task-input'),
      container: true,
      label: _operationLabel(prompt.operation),
      child: switch (prompt.kind) {
        LocalCognitiveTaskKind.singleSelect => _SingleSelectInput(
          items: prompt.items,
          response: response is SingleSelectTaskResponse
              ? response! as SingleSelectTaskResponse
              : null,
          onChanged: onChanged,
        ),
        LocalCognitiveTaskKind.classify => _ClassifyInput(
          items: prompt.items,
          targets: prompt.targets,
          response: response is ClassifyTaskResponse
              ? response! as ClassifyTaskResponse
              : null,
          onChanged: onChanged,
        ),
        LocalCognitiveTaskKind.sequence => _SequenceInput(
          items: prompt.items,
          response: response is SequenceTaskResponse
              ? response! as SequenceTaskResponse
              : null,
          onChanged: onChanged,
        ),
      },
    );
  }
}

bool isCognitiveTaskResponseComplete(
  LocalCognitiveTaskPrompt prompt,
  CognitiveTaskResponse? response,
) => switch ((prompt.kind, response)) {
  (
    LocalCognitiveTaskKind.singleSelect,
    SingleSelectTaskResponse(:final selectedItemId),
  ) =>
    prompt.items.any((item) => item.id == selectedItemId),
  (
    LocalCognitiveTaskKind.classify,
    ClassifyTaskResponse(:final targetByItemId),
  ) =>
    targetByItemId.length == prompt.items.length &&
        prompt.items.every(
          (item) => prompt.targets.any(
            (target) => target.id == targetByItemId[item.id],
          ),
        ),
  (
    LocalCognitiveTaskKind.sequence,
    SequenceTaskResponse(:final orderedItemIds),
  ) =>
    orderedItemIds.length == prompt.items.length &&
        orderedItemIds.toSet().length == prompt.items.length &&
        prompt.items.every((item) => orderedItemIds.contains(item.id)),
  _ => false,
};

/// 本人が組んだ回答を、理由を書く画面と比較画面へ同じ表現で渡す。
///
/// 教材のsolutionは参照せず、本人が選んだIDをpromptの表示文へ戻すだけ。
String cognitiveTaskResponseSummary(
  LocalCognitiveTaskPrompt prompt,
  CognitiveTaskResponse response,
) {
  String itemText(String id) =>
      prompt.items
          .where((item) => item.id == id)
          .map((item) => item.text)
          .firstOrNull ??
      '';
  String targetLabel(String id) =>
      prompt.targets
          .where((target) => target.id == id)
          .map((target) => target.label)
          .firstOrNull ??
      '';

  return switch (response) {
    SingleSelectTaskResponse(:final selectedItemId) => itemText(selectedItemId),
    ClassifyTaskResponse(:final targetByItemId) =>
      prompt.items
          .where((item) => targetByItemId.containsKey(item.id))
          .map(
            (item) => '${item.text} → ${targetLabel(targetByItemId[item.id]!)}',
          )
          .join('\n'),
    SequenceTaskResponse(:final orderedItemIds) =>
      orderedItemIds
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}. ${itemText(entry.value)}')
          .join('\n'),
  };
}

/// 比較・完了画面でだけ、教材のsolutionを表示文へ戻す。
///
/// 入力用の [CognitiveTaskInput] からは呼ばず、同widgetは引き続き
/// [LocalCognitiveTaskPrompt] しか受け取らない。
String cognitiveTaskSolutionSummary(LocalCognitiveTask task) {
  final response = switch (task.solution) {
    LocalSingleSelectSolution(:final selectedItemId) =>
      SingleSelectTaskResponse(selectedItemId),
    LocalClassifySolution(:final targetByItemId) => ClassifyTaskResponse(
      targetByItemId,
    ),
    LocalSequenceSolution(:final orderedItemIds) => SequenceTaskResponse(
      orderedItemIds,
    ),
  };
  return cognitiveTaskResponseSummary(task.prompt, response);
}

class CognitiveTaskResponseSummary extends StatelessWidget {
  const CognitiveTaskResponseSummary({
    super.key,
    required this.prompt,
    required this.response,
    this.label = '組んだ答え',
  });

  final LocalCognitiveTaskPrompt prompt;
  final CognitiveTaskResponse response;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final summary = cognitiveTaskResponseSummary(prompt, response);
    return Semantics(
      key: const ValueKey('cognitive-task-response-summary'),
      container: true,
      label: '$label。$summary',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
          decoration: BoxDecoration(
            color: colors.legendary,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.textTheme.labelMedium
                    ?.copyWith(color: colors.onLegendary)
                    .jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                summary,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: colors.onLegendary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SingleSelectInput extends StatelessWidget {
  const _SingleSelectInput({
    required this.items,
    required this.response,
    required this.onChanged,
  });

  final List<LocalCognitiveTaskItem> items;
  final SingleSelectTaskResponse? response;
  final ValueChanged<CognitiveTaskResponse> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TaskInstruction(
          icon: Icons.touch_app_outlined,
          title: '予想を1つ決める',
          body: '答えはまだ表示しません。いまの考えに一番近いものを選びます。',
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++) ...[
          _ChoiceCard(
            key: ValueKey('cognitive-task-choice-${items[i].id}'),
            label:
                '選択肢${i + 1}、全${items.length}件中。${items[i].text}'
                '${response?.selectedItemId == items[i].id ? '。選択中' : ''}',
            text: items[i].text,
            selected: response?.selectedItemId == items[i].id,
            onTap: () => onChanged(SingleSelectTaskResponse(items[i].id)),
          ),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ClassifyInput extends StatelessWidget {
  const _ClassifyInput({
    required this.items,
    required this.targets,
    required this.response,
    required this.onChanged,
  });

  final List<LocalCognitiveTaskItem> items;
  final List<LocalCognitiveTaskTarget> targets;
  final ClassifyTaskResponse? response;
  final ValueChanged<CognitiveTaskResponse> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TaskInstruction(
          icon: Icons.category_outlined,
          title: '一つずつ分類する',
          body: 'カードごとに分類先を選びます。すべて決めるまで答えは表示されません。',
        ),
        const SizedBox(height: 12),
        for (var itemIndex = 0; itemIndex < items.length; itemIndex++) ...[
          Material(
            key: ValueKey(
              'cognitive-task-classify-item-${items[itemIndex].id}',
            ),
            color: colors.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colors.border),
              borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'カード ${itemIndex + 1} / ${items.length}',
                    style: t.textTheme.labelMedium
                        ?.copyWith(color: colors.inkMuted)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(items[itemIndex].text, style: t.textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  for (
                    var targetIndex = 0;
                    targetIndex < targets.length;
                    targetIndex++
                  ) ...[
                    _TargetButton(
                      key: ValueKey(
                        'cognitive-task-classify-${items[itemIndex].id}-${targets[targetIndex].id}',
                      ),
                      semanticsLabel:
                          'カード${itemIndex + 1}、全${items.length}件中。'
                          '${items[itemIndex].text}。分類先、${targets[targetIndex].label}'
                          '${response?.targetByItemId[items[itemIndex].id] == targets[targetIndex].id ? '。選択中' : ''}',
                      label: targets[targetIndex].label,
                      selected:
                          response?.targetByItemId[items[itemIndex].id] ==
                          targets[targetIndex].id,
                      onPressed: () {
                        final next = <String, String>{
                          ...?response?.targetByItemId,
                          items[itemIndex].id: targets[targetIndex].id,
                        };
                        onChanged(ClassifyTaskResponse(next));
                      },
                    ),
                    if (targetIndex != targets.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          if (itemIndex != items.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SequenceInput extends StatelessWidget {
  const _SequenceInput({
    required this.items,
    required this.response,
    required this.onChanged,
  });

  final List<LocalCognitiveTaskItem> items;
  final SequenceTaskResponse? response;
  final ValueChanged<CognitiveTaskResponse> onChanged;

  @override
  Widget build(BuildContext context) {
    final orderedIds = response?.orderedItemIds ?? const <String>[];
    final ordered = orderedIds
        .map((id) => items.where((item) => item.id == id).firstOrNull)
        .nonNulls
        .toList();
    final remaining = items
        .where((item) => !orderedIds.contains(item.id))
        .toList();
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _TaskInstruction(
          icon: Icons.format_list_numbered_outlined,
          title: '起きる順に組む',
          body: '未配置のカードを、最初に起きるものからタップします。選んだカードは取り消せます。',
        ),
        const SizedBox(height: 14),
        Text('組んだ順序', style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700)),
        const SizedBox(height: 8),
        if (ordered.isEmpty)
          Container(
            key: const ValueKey('cognitive-task-sequence-empty'),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(GameTokens.radiusMd),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'まだカードを置いていません。',
              style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
          )
        else
          for (var i = 0; i < ordered.length; i++) ...[
            _SequencePlacedCard(
              key: ValueKey('cognitive-task-sequence-placed-${ordered[i].id}'),
              index: i,
              total: items.length,
              item: ordered[i],
              onRemove: () {
                final next = [...orderedIds]..remove(ordered[i].id);
                onChanged(SequenceTaskResponse(next));
              },
            ),
            if (i != ordered.length - 1) const SizedBox(height: 8),
          ],
        const SizedBox(height: 16),
        Text('未配置', style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700)),
        const SizedBox(height: 8),
        if (remaining.isEmpty)
          Text(
            'すべてのカードを置きました。',
            key: const ValueKey('cognitive-task-sequence-all-placed'),
            style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
          )
        else
          for (var i = 0; i < remaining.length; i++) ...[
            Semantics(
              button: true,
              onTap: () => onChanged(
                SequenceTaskResponse([...orderedIds, remaining[i].id]),
              ),
              label:
                  '未配置項目${i + 1}、全${remaining.length}件中。'
                  '${remaining[i].text}。タップすると${ordered.length + 1}番目へ追加',
              child: ExcludeSemantics(
                child: OutlinedButton.icon(
                  key: ValueKey(
                    'cognitive-task-sequence-add-${remaining[i].id}',
                  ),
                  onPressed: () => onChanged(
                    SequenceTaskResponse([...orderedIds, remaining[i].id]),
                  ),
                  icon: const Icon(Icons.add),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(remaining[i].text),
                  ),
                ),
              ),
            ),
            if (i != remaining.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _TaskInstruction extends StatelessWidget {
  const _TaskInstruction({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.pathReview),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colors.pathActive : colors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? colors.pathActive : colors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? colors.onPathActive : colors.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        text,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: selected ? colors.onPathActive : colors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetButton extends StatelessWidget {
  const _TargetButton({
    super.key,
    required this.semanticsLabel,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String semanticsLabel;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: selected
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.check_circle_outline),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(label),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(GameTokens.minTouchTarget),
                  backgroundColor: colors.pathActive,
                  foregroundColor: colors.onPathActive,
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.radio_button_unchecked),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(label),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(GameTokens.minTouchTarget),
                  foregroundColor: colors.ink,
                  side: BorderSide(color: colors.border),
                ),
              ),
      ),
    );
  }
}

class _SequencePlacedCard extends StatelessWidget {
  const _SequencePlacedCard({
    super.key,
    required this.index,
    required this.total,
    required this.item,
    required this.onRemove,
  });

  final int index;
  final int total;
  final LocalCognitiveTaskItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      button: true,
      onTap: onRemove,
      label: '${index + 1}番目、全$total件中。${item.text}。タップすると順序から取り消す',
      child: ExcludeSemantics(
        child: Material(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.pathActive,
                        borderRadius: BorderRadius.circular(
                          GameTokens.radiusPill,
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: colors.onPathActive)
                            .jaWeight(FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          item.text,
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.undo, color: colors.ink),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _operationLabel(LocalCognitiveOperation operation) =>
    switch (operation) {
      LocalCognitiveOperation.prediction => '科学タスク、結果を予測する',
      LocalCognitiveOperation.conditionClassify => '科学タスク、条件を分類する',
      LocalCognitiveOperation.causalOrder => '科学タスク、原因と結果を順に組む',
      LocalCognitiveOperation.forceDirection => '科学タスク、力や向きを考える',
      LocalCognitiveOperation.quantityCompare => '科学タスク、数量を比べる',
      LocalCognitiveOperation.experimentPlan => '科学タスク、実験の条件を組む',
    };
