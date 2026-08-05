import '../config/motion.dart';
import '../services/live_session.dart';
import '../ui/_material.dart';
import 'character.dart';

/// キャラクターと状態表示をまとめた「舞台」。
///
/// **参考にできる既製実装が無い領域。** Google 公式の Flutter デモも、
/// 音声画面は接続中スピナーと静止ロゴを切り替えるだけで、
/// 「聞いている／考えている／話している」の描き分けは実装していない。
///
/// ここでの決め方:
///
/// | 状態 | 何で伝えるか | 動きの量 |
/// |---|---|---|
/// | 聞いている | 左右に開いた弧（静的ポーズ）+ 入力音量バー | まばたきだけ（3.75%） |
/// | 考えている | 頭上の点3つが順に立つ | 連続。ただし短い（実測 約1.3秒） |
/// | 話している | 声の大きさで体が動く | 音が鳴っている間だけ |
///
/// **どの状態も、色と形に加えて必ず文字を出す**（SC 1.4.1）。
/// アニメーションが止まっている端末でも状態が分かる必要がある。
class Stage extends StatelessWidget {
  const Stage({super.key, required this.live});

  final LiveSessionController live;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final speaking = live.state == LiveState.speaking;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 話しているあいだはタップで止められる。
          // **声で割り込ませない**（AEC が無い端末では AI の声を自分で拾い、
          // それが生徒の発話として記録される）ので、止める手段は操作で持つ
          Semantics(
            button: speaking,
            label: speaking ? 'デキすぎ君の話を止める' : null,
            child: GestureDetector(
              onTap: speaking ? live.silenceAi : null,
              // 透明な部分もタップを受ける
              behavior: HitTestBehavior.opaque,
              child: StreamBuilder<double>(
                stream: live.voiceLevel,
                initialData: 0,
                builder: (context, snap) => Character(
                  state: live.state,
                  voiceLevel: snap.data ?? 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 状態は文字でも出す。動きが止まっていても伝わるように
          AnimatedSwitcher(
            duration: Motion.state,
            switchInCurve: Motion.stateCurve,
            child: Text(
              _label(live.state),
              key: ValueKey(live.state),
              style: t.textTheme.titleSmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
          // 見えない操作は無いのと同じ。話している間だけ出す
          SizedBox(
            height: 20,
            child: AnimatedOpacity(
              opacity: speaking ? 1 : 0,
              duration: Motion.state,
              child: Text(
                'タップで止められます',
                style: t.textTheme.bodySmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _label(LiveState s) => switch (s) {
        LiveState.idle => 'まだ始まっていません',
        LiveState.connecting => 'つないでいます',
        LiveState.listening => '聞いています',
        LiveState.thinking => '考えています',
        LiveState.speaking => '話しています',
        LiveState.done => 'ひととおり終わりました',
        LiveState.outOfTime => 'きょうのぶんは終わりです',
        LiveState.failed => '続けられませんでした',
      };
}
