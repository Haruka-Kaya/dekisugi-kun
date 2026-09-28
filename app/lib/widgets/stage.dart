import '../config/app_radius.dart';
import '../config/app_theme.dart';
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
    final c = context.appColors;

    final speaking = live.state == LiveState.speaking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.heroSurface,
          borderRadius: BorderRadius.circular(AppRadius.stage),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 話しているあいだはタップで止められる。
              // **声で割り込ませない**（AEC が無い端末では AI の声を自分で拾い、
              // それが生徒の発話として記録される）ので、止める手段は操作で持つ
              Semantics(
                button: speaking,
                label: speaking ? 'デキすぎ君の話を止める' : 'デキすぎ君',
                child: GestureDetector(
                  onTap: speaking ? live.silenceAi : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 166,
                    height: 166,
                    decoration: BoxDecoration(
                      color: c.coolSurface,
                      shape: BoxShape.circle,
                    ),
                    child: StreamBuilder<double>(
                      stream: live.voiceLevel,
                      initialData: 0,
                      builder: (context, snap) => Character(
                        state: live.state,
                        voiceLevel: snap.data ?? 0,
                        size: 150,
                        // 親の操作ラベルと直下の状態テキストが同じ内容を返す。
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // AnimatedSwitcher の旧・新Textを読み上げツリーへ重ねない。
              Semantics(
                liveRegion: true,
                label: _label(live.state),
                child: ExcludeSemantics(
                  child: AnimatedSwitcher(
                    duration: Motion.state,
                    switchInCurve: Motion.stateCurve,
                    child: Text(
                      _label(live.state),
                      key: ValueKey(live.state),
                      style: t.textTheme.titleMedium
                          ?.copyWith(color: c.onHeroSurface)
                          .jaWeight(FontWeight.w700),
                    ),
                  ),
                ),
              ),
              // 200%文字でも固定高で切らない。必要なときだけ自然高で出す。
              AnimatedSwitcher(
                duration: Motion.state,
                switchInCurve: Motion.stateCurve,
                child: speaking
                    ? Text(
                        'キャラクターをタップすると止められます',
                        key: const ValueKey('silence-hint'),
                        style: t.textTheme.bodySmall?.copyWith(
                          color: c.heroMuted,
                        ),
                        textAlign: TextAlign.center,
                      )
                    : const SizedBox.shrink(key: ValueKey('no-silence-hint')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _label(LiveState s) => switch (s) {
    LiveState.idle => '声でも文字でも、準備できています',
    LiveState.connecting => 'つないでいます',
    LiveState.listening => '聞いています',
    LiveState.thinking => '考えています',
    LiveState.speaking => '話しています',
    LiveState.done => 'ひととおり終わりました',
    LiveState.outOfTime => 'きょうのぶんは終わりです',
    LiveState.failed => '続けられませんでした',
  };
}
