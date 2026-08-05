import 'dart:async';
import 'dart:math' as math;

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../services/live_session.dart';
import '../ui/_material.dart';

/// デキすぎ君。**丸と目だけ**で作る。
///
/// ## 口が無い理由
///
/// Gemini Live は**音素タイミングを返さない**ので、口の形は原理的に作れない。
/// 口を置いて適当に開閉させると、音と合っていないことが必ずばれる。
/// **最初から持たせない**のが正しい。
///
/// 表情は目と体の動きだけで作る。Duolingo の設計（幾何学的・大きな目・
/// 単純なシルエット）に合わせれば、絵を描かなくても成立する。
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
  });

  final LiveState state;

  /// AI の声の大きさ（0.0〜1.0）。話しているときの体の動きに使う。
  final double voiceLevel;

  final double size;

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
    duration: Durations.extralong2, // 800ms で点3つが1巡
  );
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(Character old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _sync();
  }

  /// 状態に合わせて、必要なものだけ動かす。
  void _sync() {
    _blinkTimer?.cancel();
    _blinkTimer = null;

    switch (widget.state) {
      case LiveState.listening:
        // 動くのはまばたきだけ。**連続アニメーションは持たない**
        _think.stop();
        _think.value = 0;
        _scheduleBlink();
      case LiveState.thinking:
        // この状態は短い（実測 voice-to-voice 約1.3秒）ので連続で許容する
        _think.repeat();
      case LiveState.speaking:
        // 体の動きは voiceLevel が駆動する。コントローラは要らない
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
    // 間隔を少し散らす。きっちり4秒だと機械が瞬いているように見える
    final jitter = Duration(
        milliseconds: (Motion.blinkInterval.inMilliseconds * 0.3).round());
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
    final c = context.appColors;
    final reduce = ReduceMotionScope.of(context);

    // 動きが要らない状態ではサブツリーのティッカーごと止める。
    // 実測 91.4% → 0.8%。Reduce Motion のときも止める
    final wantsTicker = !reduce &&
        (widget.state == LiveState.listening ||
            widget.state == LiveState.thinking);

    return TickerMode(
      enabled: wantsTicker,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_blink, _think]),
          builder: (context, _) => CustomPaint(
            painter: _CharacterPainter(
              state: widget.state,
              // Reduce Motion では目を閉じたまま止めない。開いた状態で固定する
              eyeOpen: reduce ? 1.0 : 1.0 - _blink.value,
              thinkPhase: reduce ? 0 : _think.value,
              // 声に合わせた体の動き。**口ではない**ので音素の精度を主張しない
              bounce: reduce ? 0 : widget.voiceLevel.clamp(0.0, 1.0),
              body: c.charBody,
              face: c.charFace,
              accent: c.charAccent,
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterPainter extends CustomPainter {
  _CharacterPainter({
    required this.state,
    required this.eyeOpen,
    required this.thinkPhase,
    required this.bounce,
    required this.body,
    required this.face,
    required this.accent,
  });

  final LiveState state;

  /// 1.0 = 開いている、0.0 = 閉じている
  final double eyeOpen;

  /// 考え中の点の位相 0.0〜1.0
  final double thinkPhase;

  /// 声の大きさ 0.0〜1.0
  final double bounce;

  final Color body, face, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w * 0.29; // 頭の半径
    // 声が大きいほど少し上がる。振れ幅は控えめに（跳ねすぎると落ち着かない）
    final headY = size.height * 0.44 - bounce * w * 0.025;
    final head = Offset(w / 2, headY);

    // 影は使わない。階層はソリッドな面と境界線だけで作る（DESIGN.md §6）
    final bodyPaint = Paint()..color = body;

    // ① 房。**シルエットで誰か分かるようにする**ための飾り。
    //    Duolingo の設計原則でいう「単純だが識別できる輪郭」
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(w / 2 + r * 0.35, headY - r * 1.12),
            width: r * 0.18,
            height: r * 0.42),
        Radius.circular(r * 0.09),
      ),
      bodyPaint,
    );
    canvas.drawCircle(
        Offset(w / 2 + r * 0.35, headY - r * 1.35), r * 0.15, Paint()..color = accent);

    // ② 体。**頭より横に広くする。**
    //    頭より狭いと、同じ色なので体ではなく「あご」に見える
    final bodyW = r * 2.3 * (1 + bounce * 0.03);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(w / 2, headY + r * 1.28),
            width: bodyW,
            height: r * 0.9),
        Radius.circular(r * 0.34),
      ),
      bodyPaint,
    );

    // ③ 頭。話しているときだけ、声に合わせてわずかに横へ広がる
    final rx = r * (1 + bounce * 0.05);
    final ry = r * (1 - bounce * 0.04);
    canvas.drawOval(
        Rect.fromCenter(center: head, width: rx * 2, height: ry * 2), bodyPaint);

    if (state == LiveState.listening) _paintEar(canvas, head, r);
    if (state == LiveState.speaking) _paintVoice(canvas, head, r);
    _paintEyes(canvas, head, r);

    // 房は右上に立っているので、点は左上に出す（重ねると何の記号か読めない）
    if (state == LiveState.thinking) _paintThinking(canvas, w, headY - r, r);
  }

  /// 話しているしるし。**動きが止まっていても状態が分かるように、
  /// 声が無くても最低限の高さで描く。**
  void _paintVoice(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;

    // 頭の右に3本。声が大きいほど伸びる
    for (var i = 0; i < 3; i++) {
      final base = 0.18 + i * 0.06;
      final h = r * (base + bounce * (0.22 - i * 0.05));
      // 描画範囲に収める。r*1.5 を超えると SizedBox の外にはみ出て切れる
      final x = center.dx + r * (1.12 + i * 0.17);
      canvas.drawLine(Offset(x, center.dy - h), Offset(x, center.dy + h), paint);
    }
  }

  void _paintEyes(Canvas canvas, Offset center, double r) {
    final paint = Paint()..color = face;
    final dx = r * 0.40;
    final eyeR = r * 0.20;
    // まばたきは縦だけ潰す。横まで縮めると目が消えたように見える
    final h = eyeR * 2 * eyeOpen.clamp(0.08, 1.0);

    for (final side in [-1.0, 1.0]) {
      final c = Offset(center.dx + dx * side, center.dy - r * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: eyeR * 2, height: h),
          Radius.circular(eyeR),
        ),
        paint,
      );
      // 瞳のハイライト。目が閉じているときは出さない
      if (eyeOpen > 0.5) {
        canvas.drawCircle(
          Offset(c.dx + eyeR * 0.32, c.dy - eyeR * 0.34),
          eyeR * 0.26,
          Paint()..color = body,
        );
      }
    }
  }

  /// 考え中の点3つ。順に立ち上がる。
  void _paintThinking(Canvas canvas, double w, double top, double r) {
    final paint = Paint()..color = accent;
    final dotR = w * 0.028;
    for (var i = 0; i < 3; i++) {
      // 各点が 1/3 ずつ位相をずらして持ち上がる
      final t = (thinkPhase * 3 - i).clamp(0.0, 1.0);
      final lift = math.sin(t * math.pi) * w * 0.03;
      canvas.drawCircle(
        // 房（右上）を避けて左上に出す
        Offset(w / 2 - r * 0.75 + (i - 1) * dotR * 3.0, top - w * 0.05 - lift),
        dotR,
        paint,
      );
    }
  }

  /// 聞いているしるし。**動かさない静的なポーズ**で状態を示す。
  void _paintEar(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    // 体の左右に開いた弧。「耳を傾けている」を形で出す
    for (final side in [-1.0, 1.0]) {
      final rect = Rect.fromCircle(
        center: Offset(center.dx + r * 1.02 * side, center.dy),
        radius: r * 0.3,
      );
      canvas.drawArc(rect, side > 0 ? -math.pi / 2 : math.pi / 2, math.pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.state != state ||
      old.eyeOpen != eyeOpen ||
      old.thinkPhase != thinkPhase ||
      old.bounce != bounce ||
      old.body != body;
}
