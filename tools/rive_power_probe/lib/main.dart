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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

const String kProbeMode =
    String.fromEnvironment('PROBE_MODE', defaultValue: 'running');

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

class _ProbePageState extends State<ProbePage> {
  File? _riveFile;
  RiveWidgetController? _controller;
  String _status = 'init';

  bool get _needsRive => kProbeMode == 'running' || kProbeMode == 'frozen';

  @override
  void initState() {
    super.initState();
    if (_needsRive) {
      _load();
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
                'MODE=$kProbeMode  |  $_status',
                style: const TextStyle(
                  color: Color(0xFF8FA0B8),
                  fontSize: 13,
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
