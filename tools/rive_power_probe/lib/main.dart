// Rive の常時アニメーションが CPU・電池に与える影響を実機で測るためのプローブ。
//
// 1条件 = 1プロセスにする（状態の持ち越しを避けるため）。モードは --dart-define で渡す:
//   flutter run --release --dart-define=PROBE_MODE=running
//   flutter run --release --dart-define=PROBE_MODE=frozen
//   flutter run --release --dart-define=PROBE_MODE=static
//
//   running … Rive を再生し続ける（TickerMode: true）
//   frozen  … Rive を描画するがティッカーを止める（TickerMode: false）
//   static  … Rive を一切生成しない。素の Flutter 描画だけのベースライン
//
// 測定自体はアプリ側では行わない。adb（dumpsys batterystats / gfxinfo / proc stat）で外から取る。
// 画面の明るさとスリープは測定スクリプト側で固定する。

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

const String kProbeMode =
    String.fromEnvironment('PROBE_MODE', defaultValue: 'running');

/// 有効なモード。ここに無い値が来たら黙って static 相当に落ちるのではなく、
/// 画面に大きく出して測定を無効と分かるようにする（実際に一度これで測り損ねた）。
const Set<String> kValidModes = {'running', 'frozen', 'static', 'flutter_anim'};
bool get kModeValid => kValidModes.contains(kProbeMode);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ProbeApp());
}

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rive power probe',
      debugShowCheckedModeBanner: false,
      home: const ProbePage(),
    );
  }
}

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});

  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage>
    with SingleTickerProviderStateMixin {
  File? _riveFile;
  RiveWidgetController? _controller;
  AnimationController? _anim;
  String _status = 'init';

  bool get _needsRive => kProbeMode == 'running' || kProbeMode == 'frozen';

  @override
  void initState() {
    super.initState();
    if (_needsRive) {
      _load();
    } else if (kProbeMode == 'flutter_anim') {
      // 対照条件: Rive を使わない素の Flutter 連続アニメーション。
      // これが無いと「Rive が重い」のか「120Hz で回り続けること自体が重い」のかを分けられない。
      _anim = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      )..repeat();
      _status = 'flutter animation (no rive)';
    } else {
      _status = 'static (rive not loaded)';
    }
  }

  Future<void> _load() async {
    try {
      _riveFile = await File.asset(
        'assets/little_machine.riv',
        riveFactory: Factory.rive,
      );
      _controller = RiveWidgetController(_riveFile!);
      if (!mounted) return;
      setState(() => _status = 'rive ready');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'rive FAILED: $e');
    }
  }

  @override
  void dispose() {
    _anim?.dispose();
    _controller?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101318),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // 条件が取り違えられていないことを画面と screencap で確認できるようにする
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                kModeValid
                    ? 'MODE=$kProbeMode  |  $_status'
                    : '*** INVALID MODE: "$kProbeMode" — 測定は無効 ***',
                style: TextStyle(
                  color: kModeValid
                      ? const Color(0xFF8FA0B8)
                      : const Color(0xFFFF5252),
                  fontSize: kModeValid ? 13 : 16,
                  fontWeight: kModeValid ? FontWeight.normal : FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(child: Center(child: _buildStage())),
          ],
        ),
      ),
    );
  }

  Widget _buildStage() {
    // 3条件で描画面積を揃える。面積が変わると GPU 負荷の比較にならない。
    const double side = 320;

    if (kProbeMode == 'flutter_anim') {
      // 毎フレーム再描画されるが、描くもの自体は軽い。
      // これで「Flutter の連続アニメーション基盤のコスト」だけが出る。
      return SizedBox(
        width: side,
        height: side,
        child: AnimatedBuilder(
          animation: _anim!,
          builder: (context, _) => CustomPaint(
            painter: _SpinPainter(_anim!.value),
            size: const Size(side, side),
          ),
        ),
      );
    }
    if (!_needsRive) {
      return Container(
        width: side,
        height: side,
        color: const Color(0xFF243044),
      );
    }
    if (_controller == null) {
      return const SizedBox(
        width: side,
        height: side,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      width: side,
      height: side,
      // frozen はティッカーを止めるだけで、ウィジェットツリーからは外さない。
      // 「描画はするが進まない」状態を作り、running との差分を再生コストに絞る。
      child: TickerMode(
        enabled: kProbeMode == 'running',
        child: RiveWidget(controller: _controller!),
      ),
    );
  }
}

/// 対照条件用の軽い描画。毎フレーム呼ばれるが、内容は単純な図形のみ。
class _SpinPainter extends CustomPainter {
  _SpinPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // NOTE: PaintingStyle は rive_native と dart:ui の両方から export されて衝突する。
    // fill は Paint の既定なので指定しない。
    final p = Paint()..color = const Color(0xFF4C7FD4);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF243044));
    for (int i = 0; i < 12; i++) {
      final a = (t * 2 * 3.1415926) + i * (3.1415926 / 6);
      canvas.drawCircle(
        c + Offset(120 * math.cos(a), 120 * math.sin(a)),
        10,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_SpinPainter old) => old.t != t;
}
