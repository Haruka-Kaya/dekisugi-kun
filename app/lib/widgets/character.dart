import 'dart:async';

import '../config/app_language.dart';
import '../config/app_theme.dart';
import '../config/motion.dart';
import '../services/live_session.dart';
import '../ui/_material.dart';
import 'dekisugi_character_art.dart';

/// デキすぎ君。「教わるAI」だと輪郭だけでも分かるように作る。
///
/// アンテナはAI、胸の開いた本は学ぶ側、左右非対称のポーズは状態を表す。
/// 描画本体はPathと共有し、画面を移っても別のキャラクターへ変わらない。
///
/// ## 口が無い理由
///
/// Gemini Live は**音素タイミングを返さない**ので、口の形は原理的に作れない。
/// 口を置いて適当に開閉させると、音と合っていないことが必ずばれる。
/// **最初から持たせない**のが正しい。
///
/// 表情は目・腕・体の動きだけで作る。聞く、考える、話す、完了は
/// アニメーションを止めても違う形として残る。
///
/// ## 待機中に動かさない理由
///
/// 実測で、毎フレーム描き続けると 1コアの 71〜91% を食う。
/// Rive の有無に関わらずで、主犯はパイプラインを毎フレーム回すこと自体。
/// fps を落としても効かない（Rive は ~61% がフレーム非依存）。
/// **効くのは止めることだけ。**
///
/// なので待機中は静止し、動くのは4秒に1回・150msのまばたきだけ（稼働率 3.75%）。
class Character extends StatefulWidget {
  const Character({
    super.key,
    required this.state,
    this.voiceLevel = 0,
    this.size = 160,
    this.excludeFromSemantics = false,
  });

  final LiveState state;

  /// AI の声の大きさ（0.0〜1.0）。話しているときの体の動きに使う。
  final double voiceLevel;

  final double size;

  /// 親が同じ内容を操作ラベルとして返す場合だけ、重複読み上げを避ける。
  final bool excludeFromSemantics;

  @override
  State<Character> createState() => _CharacterState();
}

class _CharacterState extends State<Character> with TickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: Motion.blink,
  );
  late final AnimationController _think = AnimationController(
    vsync: this,
    duration: Durations.extralong2,
  );
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Character oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _sync();
  }

  void _sync() {
    _blinkTimer?.cancel();
    _blinkTimer = null;

    switch (widget.state) {
      case LiveState.listening:
        _think.stop();
        _think.value = 0;
        _scheduleBlink();
      case LiveState.thinking:
        _think.repeat();
      case LiveState.speaking:
        _think.stop();
        _think.value = 0;
      case LiveState.idle:
      case LiveState.connecting:
      case LiveState.done:
      case LiveState.outOfTime:
      case LiveState.failed:
        _think.stop();
        _think.value = 0;
        _blink.stop();
        _blink.value = 0;
    }
  }

  void _scheduleBlink() {
    final jitter = Duration(
      milliseconds: (Motion.blinkInterval.inMilliseconds * 0.3).round(),
    );
    final wait = Motion.blinkInterval - (jitter ~/ 2) + (jitter * _rand());
    _blinkTimer = Timer(wait, () async {
      if (!mounted || widget.state != LiveState.listening) return;
      await _blink.forward();
      await _blink.reverse();
      if (mounted && widget.state == LiveState.listening) _scheduleBlink();
    });
  }

  double _rand() => (DateTime.now().microsecondsSinceEpoch % 1000) / 1000;

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blink.dispose();
    _think.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = ReduceMotionScope.of(context);
    final wantsTicker =
        !reduceMotion &&
        (widget.state == LiveState.listening ||
            widget.state == LiveState.thinking);

    final art = TickerMode(
      enabled: wantsTicker,
      child: AnimatedBuilder(
        animation: Listenable.merge([_blink, _think]),
        builder: (context, _) => DekisugiCharacterArt(
          pose: _pose(widget.state),
          size: widget.size,
          body: colors.charBody,
          face: colors.charFace,
          accent: colors.charAccent,
          signal: colors.onCoolSurface,
          ornament: colors.charAccent,
          ornamentSignal: colors.onCoolSurface,
          eyeOpen: reduceMotion ? 1.0 : 1.0 - _blink.value,
          thinkPhase: reduceMotion ? 0 : _think.value,
          voiceBounce: reduceMotion ? 0 : widget.voiceLevel.clamp(0.0, 1.0),
          paintKey: ValueKey<String>('character-pose-${widget.state.name}'),
        ),
      ),
    );
    if (widget.excludeFromSemantics) {
      return ExcludeSemantics(child: art);
    }
    return Semantics(
      container: true,
      image: true,
      label: _semanticsLabel(widget.state),
      child: ExcludeSemantics(child: art),
    );
  }

  static DekisugiCharacterPose _pose(LiveState state) => switch (state) {
    LiveState.idle => DekisugiCharacterPose.idle,
    LiveState.connecting => DekisugiCharacterPose.connecting,
    LiveState.listening => DekisugiCharacterPose.listening,
    LiveState.thinking => DekisugiCharacterPose.thinking,
    LiveState.speaking => DekisugiCharacterPose.speaking,
    LiveState.done => DekisugiCharacterPose.celebrate,
    LiveState.outOfTime => DekisugiCharacterPose.outOfTime,
    LiveState.failed => DekisugiCharacterPose.retry,
  };

  static String _semanticsLabel(LiveState state) => switch (state) {
    LiveState.idle => t(
      'デキすぎ君が本を開いて、教わる準備をしています',
      'Dekisugi-kun opens a book, ready to be taught',
    ),
    LiveState.connecting => t(
      'デキすぎ君がアンテナを上げて、接続を待っています',
      'Dekisugi-kun raises an antenna, waiting to connect',
    ),
    LiveState.listening => t(
      'デキすぎ君が手を耳に添えて、聞いています',
      'Dekisugi-kun cups a hand to his ear, listening',
    ),
    LiveState.thinking => t(
      'デキすぎ君があごに手を添えて、考えています',
      'Dekisugi-kun rests his chin on his hand, thinking',
    ),
    LiveState.speaking => t(
      'デキすぎ君が手を広げて、話しています',
      'Dekisugi-kun spreads his hands, speaking',
    ),
    LiveState.done => t(
      'デキすぎ君がノートを持って、完了を祝っています',
      'Dekisugi-kun holds his notebook, celebrating',
    ),
    LiveState.outOfTime => t(
      'デキすぎ君が時計を持って、きょうの時間切れを知らせています',
      "Dekisugi-kun holds a clock: today's time is up",
    ),
    LiveState.failed => t(
      'デキすぎ君が手を差し出して、再挑戦を案内しています',
      'Dekisugi-kun reaches out, inviting you to try again',
    ),
  };
}
