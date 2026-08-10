import 'dart:async';
import 'dart:math' as math;

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../services/live_session.dart';
import '../ui/_material.dart';

/// デキすぎ君。「教わるAI」だと輪郭だけでも分かるように作る。
///
/// アンテナはAI、胸の開いた本は学ぶ側、左右非対称の房は固有の輪郭を表す。
/// 状態は外付けアイコンだけに任せず、目線・腕・持ち物の静的なポーズでも示す。
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
    final c = context.appColors;
    final reduce = ReduceMotionScope.of(context);

    // 動きが要らない状態ではサブツリーのティッカーごと止める。
    // 実測 91.4% → 0.8%。Reduce Motion のときも止める
    final wantsTicker =
        !reduce &&
        (widget.state == LiveState.listening ||
            widget.state == LiveState.thinking);

    final art = TickerMode(
      enabled: wantsTicker,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_blink, _think]),
          builder: (context, _) => CustomPaint(
            key: ValueKey<String>('character-pose-${widget.state.name}'),
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
              signal: c.onCoolSurface,
            ),
          ),
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

  static String _semanticsLabel(LiveState state) => switch (state) {
    LiveState.idle => 'デキすぎ君が本を開いて、教わる準備をしています',
    LiveState.connecting => 'デキすぎ君がアンテナを上げて、接続を待っています',
    LiveState.listening => 'デキすぎ君が手を耳に添えて、聞いています',
    LiveState.thinking => 'デキすぎ君があごに手を添えて、考えています',
    LiveState.speaking => 'デキすぎ君が手を広げて、話しています',
    LiveState.done => 'デキすぎ君がノートを持って、完了を祝っています',
    LiveState.outOfTime => 'デキすぎ君が時計を持って、きょうの時間切れを知らせています',
    LiveState.failed => 'デキすぎ君が手を差し出して、再挑戦を案内しています',
  };
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
    required this.signal,
  });

  final LiveState state;

  /// 1.0 = 開いている、0.0 = 閉じている
  final double eyeOpen;

  /// 考え中の点の位相 0.0〜1.0
  final double thinkPhase;

  /// 声の大きさ 0.0〜1.0
  final double bounce;

  final Color body, face, accent, signal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w * 0.275; // 頭の半径
    // 声が大きいほど少し上がる。振れ幅は控えめに（跳ねすぎると落ち着かない）
    final headY = size.height * 0.42 - bounce * w * 0.025;
    final head = Offset(w / 2, headY);

    // 影は使わない。階層はソリッドな面と境界線だけで作る（DESIGN.md §6）
    final bodyPaint = Paint()..color = body;

    // 腕を体より先に描き、付け根を胴で隠す。手だけは最後に重ねるので、
    // 考えるときの「あごに手を置く」形も小さい表示で消えない。
    final hands = _paintArms(canvas, w, headY, r);

    // ① アンテナ。右へ傾く輪郭をPath側のマスコットと揃える。
    final antennaStart = Offset(head.dx + r * 0.31, headY - r * 0.92);
    final antennaTip = Offset(head.dx + r * 0.52, headY - r * 1.34);
    canvas.drawLine(
      antennaStart,
      antennaTip,
      Paint()
        ..color = body
        ..strokeWidth = r * 0.16
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(antennaTip, r * 0.16, Paint()..color = accent);

    // ② 体。**頭より横に広くする。**
    //    頭より狭いと、同じ色なので体ではなく「あご」に見える
    final bodyW = r * 2.36 * (1 + bounce * 0.03);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, headY + r * 1.27),
          width: bodyW,
          height: r * 0.96,
        ),
        Radius.circular(r * 0.38),
      ),
      bodyPaint,
    );

    // ③ 頭。話しているときだけ、声に合わせてわずかに横へ広がる
    final rx = r * (1 + bounce * 0.05);
    final ry = r * (1 - bounce * 0.04);
    canvas.drawOval(
      Rect.fromCenter(center: head, width: rx * 2, height: ry * 2),
      bodyPaint,
    );

    for (final hand in hands) {
      canvas.drawCircle(hand, w * 0.047, bodyPaint);
    }

    // 「答える先生」ではなく「教わる生徒」であることを、胸の開いた本で示す。
    // 装飾は1つに絞り、72dp表示でも線が潰れない太さにする。
    if (state != LiveState.done && state != LiveState.outOfTime) {
      _paintBookMark(canvas, w, headY, r);
    }

    if (state == LiveState.listening) _paintEar(canvas, head, r);
    if (state == LiveState.speaking) _paintVoice(canvas, head, r);
    _paintEyes(canvas, head, r);
    if (state == LiveState.done) _paintNotebook(canvas, head, r);
    if (state == LiveState.connecting) {
      _paintConnecting(canvas, w, antennaTip);
    }
    if (state == LiveState.outOfTime) {
      _paintClock(canvas, w, headY, r);
    }
    if (state == LiveState.failed) {
      _paintRetry(canvas, w, headY);
    }

    // 房は右上に立っているので、点は左上に出す（重ねると何の記号か読めない）
    if (state == LiveState.thinking) _paintThinking(canvas, w, headY - r, r);
  }

  /// 状態を、腕の輪郭だけでも読み分けられる静的ポーズへ変換する。
  List<Offset> _paintArms(Canvas canvas, double w, double headY, double r) {
    final shoulderY = headY + r * 0.98;
    final lowY = headY + r * 1.52;
    final left = Offset(w * 0.30, shoulderY);
    final right = Offset(w * 0.70, shoulderY);
    final restingLeft = (
      left,
      Offset(w * 0.13, headY + r * 1.18),
      Offset(w * 0.17, lowY),
    );
    final restingRight = (
      right,
      Offset(w * 0.87, headY + r * 1.18),
      Offset(w * 0.83, lowY),
    );
    final arms = switch (state) {
      LiveState.idle => [restingLeft, restingRight],
      LiveState.connecting => [
        restingLeft,
        (
          right,
          Offset(w * 0.84, headY + r * 0.47),
          Offset(w * 0.86, headY - r * 0.32),
        ),
      ],
      LiveState.listening => [
        (
          left,
          Offset(w * 0.12, headY + r * 0.50),
          Offset(w * 0.14, headY + r * 0.02),
        ),
        restingRight,
      ],
      LiveState.thinking => [
        restingLeft,
        (
          right,
          Offset(w * 0.82, headY + r * 0.66),
          Offset(w * 0.69, headY + r * 0.48),
        ),
      ],
      LiveState.speaking => [
        (
          left,
          Offset(w * 0.16, headY + r * 0.70),
          Offset(w * 0.08, headY + r * 0.44),
        ),
        (
          right,
          Offset(w * 0.84, headY + r * 0.74),
          Offset(w * 0.91, headY + r * 0.56),
        ),
      ],
      LiveState.done => [
        (
          left,
          Offset(w * 0.16, headY + r * 0.18),
          Offset(w * 0.13, headY - r * 0.52),
        ),
        (
          right,
          Offset(w * 0.84, headY + r * 0.18),
          Offset(w * 0.87, headY - r * 0.52),
        ),
      ],
      LiveState.outOfTime => [
        (
          left,
          Offset(w * 0.31, headY + r * 1.22),
          Offset(w * 0.42, headY + r * 1.34),
        ),
        (
          right,
          Offset(w * 0.69, headY + r * 1.22),
          Offset(w * 0.58, headY + r * 1.34),
        ),
      ],
      LiveState.failed => [
        restingLeft,
        (
          right,
          Offset(w * 0.84, headY + r * 0.80),
          Offset(w * 0.91, headY + r * 0.49),
        ),
      ],
    };
    final paint = Paint()
      ..color = body
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final (start, control, hand) in arms) {
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(control.dx, control.dy, hand.dx, hand.dy),
        paint,
      );
    }
    return [for (final (_, _, hand) in arms) hand];
  }

  void _paintBookMark(Canvas canvas, double w, double headY, double r) {
    final center = Offset(w * 0.5, headY + r * 1.32);
    final paint = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.026
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy + w * 0.055)
        ..lineTo(center.dx, center.dy - w * 0.045)
        ..quadraticBezierTo(
          center.dx - w * 0.055,
          center.dy - w * 0.075,
          center.dx - w * 0.11,
          center.dy - w * 0.035,
        )
        ..lineTo(center.dx - w * 0.11, center.dy + w * 0.055)
        ..quadraticBezierTo(
          center.dx - w * 0.055,
          center.dy + w * 0.02,
          center.dx,
          center.dy + w * 0.055,
        )
        ..quadraticBezierTo(
          center.dx + w * 0.055,
          center.dy + w * 0.02,
          center.dx + w * 0.11,
          center.dy + w * 0.055,
        )
        ..lineTo(center.dx + w * 0.11, center.dy - w * 0.035)
        ..quadraticBezierTo(
          center.dx + w * 0.055,
          center.dy - w * 0.075,
          center.dx,
          center.dy - w * 0.045,
        ),
      paint,
    );
  }

  /// 接続中。スピナーを回し続けず、アンテナから届く3つの点で待機を示す。
  void _paintConnecting(Canvas canvas, double w, Offset antennaTip) {
    final paint = Paint()..color = signal;
    for (var index = 0; index < 3; index++) {
      canvas.drawCircle(
        Offset(
          antennaTip.dx + w * (0.085 + index * 0.065),
          antennaTip.dy + w * (0.015 + index * 0.045),
        ),
        w * (0.018 + index * 0.004),
        paint,
      );
    }
  }

  /// 時間切れは罰の顔にせず、両手で持つ時計として穏やかに区別する。
  void _paintClock(Canvas canvas, double w, double headY, double r) {
    final center = Offset(w * 0.5, headY + r * 1.31);
    canvas.drawCircle(center, w * 0.095, Paint()..color = accent);
    final hand = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.024
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(0, -w * 0.05), hand);
    canvas.drawLine(center, center + Offset(w * 0.042, w * 0.018), hand);
    canvas.drawCircle(center, w * 0.013, Paint()..color = signal);
  }

  /// 失敗は落胆・罰ではなく「もう一度」の案内。開いた手の横へ再試行の形を置く。
  void _paintRetry(Canvas canvas, double w, double headY) {
    final center = Offset(w * 0.875, headY - w * 0.015);
    final radius = w * 0.075;
    final paint = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.35,
      math.pi * 1.45,
      false,
      paint,
    );
    final tip = Offset(
      center.dx + math.cos(math.pi * 1.10) * radius,
      center.dy + math.sin(math.pi * 1.10) * radius,
    );
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + w * 0.055, tip.dy - w * 0.006)
        ..lineTo(tip.dx + w * 0.026, tip.dy - w * 0.050),
      paint,
    );
  }

  /// 話しているしるし。**動きが止まっていても状態が分かるように、
  /// 声が無くても最低限の高さで描く。**
  void _paintVoice(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;

    // 頭の右に3本。声が大きいほど伸びる
    for (var i = 0; i < 3; i++) {
      final base = 0.18 + i * 0.06;
      final h = r * (base + bounce * (0.22 - i * 0.05));
      // 描画範囲に収める。r*1.5 を超えると SizedBox の外にはみ出て切れる
      final x = center.dx + r * (1.12 + i * 0.17);
      canvas.drawLine(
        Offset(x, center.dy - h),
        Offset(x, center.dy + h),
        paint,
      );
    }
  }

  void _paintEyes(Canvas canvas, Offset center, double r) {
    final dx = r * 0.40;
    final eyeR = r * 0.20;
    // まばたきは縦だけ潰す。横まで縮めると目が消えたように見える
    final h = eyeR * 2 * eyeOpen.clamp(0.08, 1.0);

    for (final side in [-1.0, 1.0]) {
      final c = Offset(center.dx + dx * side, center.dy - r * 0.05);
      if (state == LiveState.done) {
        // 口を足さず、閉じた目の弧だけで祝福を示す。
        canvas.drawArc(
          Rect.fromCenter(center: c, width: eyeR * 2.05, height: eyeR * 1.45),
          math.pi * 1.08,
          math.pi * 0.84,
          false,
          Paint()
            ..color = face
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.065
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      if (state == LiveState.outOfTime) {
        // 眠らせたり悲しませたりせず、落ち着いた水平の目にする。
        canvas.drawLine(
          Offset(c.dx - eyeR * 0.68, c.dy),
          Offset(c.dx + eyeR * 0.68, c.dy),
          Paint()
            ..color = face
            ..strokeWidth = r * 0.065
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: eyeR * 2, height: h),
          Radius.circular(eyeR),
        ),
        Paint()..color = face,
      );
      // 目線。thinkingは上、connectingはアンテナ側、speakingは相手側へ向ける。
      // まばたき中は出さない。
      if (eyeOpen > 0.5) {
        final gaze = switch (state) {
          LiveState.thinking => Offset(-eyeR * 0.28, -eyeR * 0.28),
          LiveState.connecting => Offset(eyeR * 0.30, -eyeR * 0.20),
          LiveState.speaking => Offset(eyeR * 0.22, 0),
          LiveState.failed => Offset(eyeR * 0.22, -eyeR * 0.06),
          _ => Offset(eyeR * 0.20, -eyeR * 0.22),
        };
        canvas.drawCircle(c + gaze, eyeR * 0.29, Paint()..color = body);
      }
    }

    final brow = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    if (state == LiveState.thinking) {
      // 片眉だけ上げ、点3つが見えない小サイズでも思案を残す。
      canvas.drawLine(
        Offset(center.dx - r * 0.52, center.dy - r * 0.35),
        Offset(center.dx - r * 0.27, center.dy - r * 0.40),
        brow,
      );
    } else if (state == LiveState.failed) {
      // 両眉をつり上げず、再試行の形を見る片眉だけで問いかける。
      canvas.drawLine(
        Offset(center.dx + r * 0.27, center.dy - r * 0.40),
        Offset(center.dx + r * 0.51, center.dy - r * 0.34),
        brow,
      );
    }
  }

  /// 完了時に本人の言葉を受け取った「ノート」を持つ。
  ///
  /// 紙吹雪や星ではなく、実際に残る成果物そのものを完了ポーズにする。
  /// 口や疑似リップシンクは追加しない。
  void _paintNotebook(Canvas canvas, Offset center, double r) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + r * 1.18),
        width: r * 1.34,
        height: r * 0.72,
      ),
      Radius.circular(r * 0.12),
    );
    canvas.drawRRect(rect, Paint()..color = accent);

    final line = Paint()
      ..color = body
      ..strokeWidth = r * 0.055
      ..strokeCap = StrokeCap.round;
    for (final offset in [-0.16, 0.06, 0.28]) {
      canvas.drawLine(
        Offset(center.dx - r * 0.42, center.dy + r * (1.18 + offset)),
        Offset(center.dx + r * 0.42, center.dy + r * (1.18 + offset)),
        line,
      );
    }
  }

  /// 考え中の点3つ。順に立ち上がる。
  void _paintThinking(Canvas canvas, double w, double top, double r) {
    final paint = Paint()..color = signal;
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
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    // 体の左右に開いた弧。「耳を傾けている」を形で出す
    for (final side in [-1.0, 1.0]) {
      final rect = Rect.fromCircle(
        center: Offset(center.dx + r * 1.02 * side, center.dy),
        radius: r * 0.3,
      );
      canvas.drawArc(
        rect,
        side > 0 ? -math.pi / 2 : math.pi / 2,
        math.pi,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.state != state ||
      old.eyeOpen != eyeOpen ||
      old.thinkPhase != thinkPhase ||
      old.bounce != bounce ||
      old.body != body ||
      old.face != face ||
      old.accent != accent ||
      old.signal != signal;
}
