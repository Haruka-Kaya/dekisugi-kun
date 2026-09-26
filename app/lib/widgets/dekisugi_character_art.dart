import 'dart:math' as math;

import '../ui/_material.dart';

/// 画面の用途から独立した、デキすぎ君の静的なポーズ。
///
/// Live会話とLearning Pathは別の状態モデルを持つが、見た目の正本はこの列挙へ
/// 変換して共有する。同じ意味の状態を、画面ごとに別の顔や輪郭で描かない。
enum DekisugiCharacterPose {
  idle,
  invite,
  connecting,
  listening,
  thinking,
  encourage,
  speaking,
  celebrate,
  outOfTime,
  retry,
}

/// 結晶やPlusで選べる見た目は、本体を置き換えず装飾だけを足す。
enum DekisugiCharacterDecoration { standard, orbit, nova, aurora }

/// デキすぎ君の描画正本。
///
/// Semanticsと状態遷移は呼び出し側が持つ。このWidgetは口なし・右へ傾く
/// アンテナ・胸の開いた本・共通の頭身を、LiveとPathの両方へ同じ形で返す。
class DekisugiCharacterArt extends StatelessWidget {
  const DekisugiCharacterArt({
    super.key,
    required this.pose,
    required this.size,
    required this.body,
    required this.face,
    required this.accent,
    required this.signal,
    required this.ornament,
    required this.ornamentSignal,
    this.decoration = DekisugiCharacterDecoration.standard,
    this.eyeOpen = 1,
    this.thinkPhase = 0,
    this.voiceBounce = 0,
    this.paintKey,
  });

  final DekisugiCharacterPose pose;
  final DekisugiCharacterDecoration decoration;
  final double size;
  final double eyeOpen;
  final double thinkPhase;
  final double voiceBounce;
  final Color body;
  final Color face;
  final Color accent;
  final Color signal;
  final Color ornament;
  final Color ornamentSignal;

  /// 既存の画面テストが、意味のある描画面を直接特定するためのKey。
  final Key? paintKey;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      key: paintKey,
      painter: _DekisugiCharacterPainter(
        pose: pose,
        decoration: decoration,
        eyeOpen: eyeOpen,
        thinkPhase: thinkPhase,
        voiceBounce: voiceBounce,
        body: body,
        face: face,
        accent: accent,
        signal: signal,
        ornament: ornament,
        ornamentSignal: ornamentSignal,
      ),
    ),
  );
}

class _DekisugiCharacterPainter extends CustomPainter {
  const _DekisugiCharacterPainter({
    required this.pose,
    required this.decoration,
    required this.eyeOpen,
    required this.thinkPhase,
    required this.voiceBounce,
    required this.body,
    required this.face,
    required this.accent,
    required this.signal,
    required this.ornament,
    required this.ornamentSignal,
  });

  final DekisugiCharacterPose pose;
  final DekisugiCharacterDecoration decoration;
  final double eyeOpen;
  final double thinkPhase;
  final double voiceBounce;
  final Color body;
  final Color face;
  final Color accent;
  final Color signal;
  final Color ornament;
  final Color ornamentSignal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w * 0.275;
    final bounce = voiceBounce.clamp(0.0, 1.0);
    final headY = size.height * 0.42 - bounce * w * 0.025;
    final head = Offset(w / 2, headY);

    _paintDecorationBehind(canvas, w, headY);

    // 腕を体より先に描き、付け根を胴で隠す。手は最後に重ねる。
    final hands = _paintArms(canvas, w, headY, r);
    final bodyPaint = Paint()..color = body;

    // AIであることを示す、右へ傾いた共通アンテナ。
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

    // 頭より横に広い胴で、どのサイズでも「あご」ではなく体に見せる。
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

    canvas.drawOval(
      Rect.fromCenter(
        center: head,
        width: r * (1 + bounce * 0.05) * 2,
        height: r * (1 - bounce * 0.04) * 2,
      ),
      bodyPaint,
    );

    for (final hand in hands) {
      canvas.drawCircle(hand, w * 0.047, bodyPaint);
    }

    // 「答える先生」ではなく「教わる生徒」である共通記号。
    if (pose != DekisugiCharacterPose.celebrate &&
        pose != DekisugiCharacterPose.outOfTime) {
      _paintOpenBook(canvas, w, headY, r);
    }

    if (pose == DekisugiCharacterPose.listening) {
      _paintListeningEars(canvas, head, r);
    }
    if (pose == DekisugiCharacterPose.speaking) {
      _paintVoice(canvas, head, r, bounce);
    }
    _paintEyes(canvas, head, r);
    if (pose == DekisugiCharacterPose.celebrate) {
      _paintNotebook(canvas, head, r);
    }
    if (pose == DekisugiCharacterPose.connecting) {
      _paintConnecting(canvas, w, antennaTip);
    }
    if (pose == DekisugiCharacterPose.outOfTime) {
      _paintClock(canvas, w, headY, r);
    }
    if (pose == DekisugiCharacterPose.retry) {
      _paintRetry(canvas, w, headY);
    }
    if (pose == DekisugiCharacterPose.thinking) {
      _paintThinking(canvas, w, headY - r, r);
    }
    if (pose == DekisugiCharacterPose.encourage) {
      _paintEncourageMark(canvas, w, headY, r);
    }

    _paintDecorationFront(canvas, w, headY, r);
  }

  void _paintDecorationBehind(Canvas canvas, double w, double headY) {
    if (decoration == DekisugiCharacterDecoration.aurora) {
      _paintAurora(canvas, w, headY);
      return;
    }
    if (decoration != DekisugiCharacterDecoration.orbit) return;
    canvas.save();
    canvas.translate(w * 0.5, headY + w * 0.05);
    canvas.rotate(-0.28);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.90, height: w * 0.38),
      Paint()
        ..color = ornament
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045,
    );
    canvas.drawCircle(
      Offset(w * 0.40, 0),
      w * 0.062,
      Paint()..color = ornamentSignal,
    );
    canvas.restore();
  }

  /// Plusサポーターの装飾。頭上を横切る二重のオーロラ帯だけを足す。
  void _paintAurora(Canvas canvas, double w, double headY) {
    canvas.save();
    canvas.translate(w * 0.5, headY - w * 0.30);
    canvas.rotate(-0.10);
    for (final (dy, alpha, width) in [
      (0.0, 0.85, 0.055),
      (w * 0.055, 0.40, 0.038),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, dy),
          width: w * 0.96,
          height: w * 0.22,
        ),
        Paint()
          ..color = ornament.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * width,
      );
    }
    canvas.drawCircle(
      Offset(-w * 0.34, w * 0.02),
      w * 0.028,
      Paint()..color = ornamentSignal,
    );
    canvas.restore();
  }

  void _paintDecorationFront(Canvas canvas, double w, double headY, double r) {
    if (decoration != DekisugiCharacterDecoration.nova) return;
    // 反応を表す右下のcheck/時計と意味を混ぜないよう、装飾は左胸に固定する。
    final center = Offset(w * 0.28, headY + r * 1.27);
    final star = Path();
    for (var index = 0; index < 10; index++) {
      final angle = -math.pi / 2 + index * math.pi / 5;
      final distance = index.isEven ? w * 0.075 : w * 0.033;
      final point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      if (index == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = ornament);
    canvas.drawCircle(center, w * 0.018, Paint()..color = ornamentSignal);
  }

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
    final arms = switch (pose) {
      DekisugiCharacterPose.idle => [restingLeft, restingRight],
      DekisugiCharacterPose.invite || DekisugiCharacterPose.connecting => [
        restingLeft,
        (
          right,
          Offset(w * 0.84, headY + r * 0.47),
          Offset(w * 0.86, headY - r * 0.32),
        ),
      ],
      DekisugiCharacterPose.listening => [
        (
          left,
          Offset(w * 0.12, headY + r * 0.50),
          Offset(w * 0.14, headY + r * 0.02),
        ),
        restingRight,
      ],
      DekisugiCharacterPose.thinking => [
        restingLeft,
        (
          right,
          Offset(w * 0.82, headY + r * 0.66),
          Offset(w * 0.69, headY + r * 0.48),
        ),
      ],
      DekisugiCharacterPose.encourage => [
        (
          left,
          Offset(w * 0.16, headY + r * 0.56),
          Offset(w * 0.09, headY + r * 0.24),
        ),
        (
          right,
          Offset(w * 0.84, headY + r * 0.56),
          Offset(w * 0.91, headY + r * 0.24),
        ),
      ],
      DekisugiCharacterPose.speaking => [
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
      DekisugiCharacterPose.celebrate => [
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
      DekisugiCharacterPose.outOfTime => [
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
      DekisugiCharacterPose.retry => [
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

  void _paintOpenBook(Canvas canvas, double w, double headY, double r) {
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

  void _paintVoice(Canvas canvas, Offset center, double r, double bounce) {
    final paint = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 3; index++) {
      final base = 0.18 + index * 0.06;
      final height = r * (base + bounce * (0.22 - index * 0.05));
      final x = center.dx + r * (1.12 + index * 0.17);
      canvas.drawLine(
        Offset(x, center.dy - height),
        Offset(x, center.dy + height),
        paint,
      );
    }
  }

  void _paintEyes(Canvas canvas, Offset center, double r) {
    final dx = r * 0.40;
    final eyeR = r * 0.20;
    final height = eyeR * 2 * eyeOpen.clamp(0.08, 1.0);

    for (final side in [-1.0, 1.0]) {
      final eyeCenter = Offset(center.dx + dx * side, center.dy - r * 0.05);
      if (pose == DekisugiCharacterPose.celebrate) {
        canvas.drawArc(
          Rect.fromCenter(
            center: eyeCenter,
            width: eyeR * 2.05,
            height: eyeR * 1.45,
          ),
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
      if (pose == DekisugiCharacterPose.outOfTime) {
        canvas.drawLine(
          Offset(eyeCenter.dx - eyeR * 0.68, eyeCenter.dy),
          Offset(eyeCenter.dx + eyeR * 0.68, eyeCenter.dy),
          Paint()
            ..color = face
            ..strokeWidth = r * 0.065
            ..strokeCap = StrokeCap.round,
        );
        continue;
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: eyeCenter, width: eyeR * 2, height: height),
          Radius.circular(eyeR),
        ),
        Paint()..color = face,
      );
      if (eyeOpen > 0.5) {
        final gaze = switch (pose) {
          DekisugiCharacterPose.thinking => Offset(-eyeR * 0.28, -eyeR * 0.28),
          DekisugiCharacterPose.invite ||
          DekisugiCharacterPose.connecting => Offset(eyeR * 0.30, -eyeR * 0.20),
          DekisugiCharacterPose.speaking => Offset(eyeR * 0.22, 0),
          DekisugiCharacterPose.retry => Offset(eyeR * 0.22, -eyeR * 0.06),
          _ => Offset(eyeR * 0.20, -eyeR * 0.22),
        };
        canvas.drawCircle(eyeCenter + gaze, eyeR * 0.29, Paint()..color = body);
      }
    }

    final brow = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.045
      ..strokeCap = StrokeCap.round;
    if (pose == DekisugiCharacterPose.thinking) {
      canvas.drawLine(
        Offset(center.dx - r * 0.52, center.dy - r * 0.35),
        Offset(center.dx - r * 0.27, center.dy - r * 0.40),
        brow,
      );
    } else if (pose == DekisugiCharacterPose.retry) {
      canvas.drawLine(
        Offset(center.dx + r * 0.27, center.dy - r * 0.40),
        Offset(center.dx + r * 0.51, center.dy - r * 0.34),
        brow,
      );
    }
  }

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

  void _paintThinking(Canvas canvas, double w, double top, double r) {
    final paint = Paint()..color = signal;
    final dotR = w * 0.028;
    for (var index = 0; index < 3; index++) {
      final phase = (thinkPhase * 3 - index).clamp(0.0, 1.0);
      final lift = math.sin(phase * math.pi) * w * 0.03;
      canvas.drawCircle(
        Offset(
          w / 2 - r * 0.75 + (index - 1) * dotR * 3.0,
          top - w * 0.05 - lift,
        ),
        dotR,
        paint,
      );
    }
  }

  void _paintListeningEars(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(center.dx + r * 1.02 * side, center.dy),
          radius: r * 0.3,
        ),
        side > 0 ? -math.pi / 2 : math.pi / 2,
        math.pi,
        false,
        paint,
      );
    }
  }

  void _paintEncourageMark(Canvas canvas, double w, double headY, double r) {
    final center = Offset(w * 0.78, headY + r * 1.35);
    canvas.drawCircle(center, w * 0.10, Paint()..color = accent);
    final check = Paint()
      ..color = signal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - w * 0.045, center.dy)
        ..lineTo(center.dx - w * 0.008, center.dy + w * 0.035)
        ..lineTo(center.dx + w * 0.055, center.dy - w * 0.045),
      check,
    );
  }

  @override
  bool shouldRepaint(covariant _DekisugiCharacterPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.decoration != decoration ||
      oldDelegate.eyeOpen != eyeOpen ||
      oldDelegate.thinkPhase != thinkPhase ||
      oldDelegate.voiceBounce != voiceBounce ||
      oldDelegate.body != body ||
      oldDelegate.face != face ||
      oldDelegate.accent != accent ||
      oldDelegate.signal != signal ||
      oldDelegate.ornament != ornament ||
      oldDelegate.ornamentSignal != ornamentSignal;
}
