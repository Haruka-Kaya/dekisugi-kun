import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/app_language.dart';
import '../config/game_tokens.dart';
import '../ui/_material.dart';

typedef QrScannerViewBuilder =
    Widget Function(BuildContext context, ValueChanged<String> onScanned);

/// カメラから1つのQR文字列だけを返す画面。
///
/// 値の用途や有効性は呼び出し側が確認する。読み取りによる接続・参加・教材開始は
/// 一切行わず、カメラ映像も保存しない。
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.scannerBuilder});

  static const cameraUnavailableMessage =
      'カメラを開始できませんでした。前の画面でコードを文字入力できます。';

  /// 実機カメラを使えないWidget test向け。productionではnull。
  final QrScannerViewBuilder? scannerBuilder;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _completed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete(String rawValue) {
    final value = rawValue.trim();
    if (_completed || value.isEmpty) return;
    _completed = true;
    _controller.stop();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final scanner =
        widget.scannerBuilder?.call(context, _complete) ??
        MobileScanner(
          key: const ValueKey('qr-camera-preview'),
          controller: _controller,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final value = barcode.rawValue;
              if (value != null) {
                _complete(value);
                return;
              }
            }
          },
          errorBuilder: (context, error) => ColoredBox(
            color: colors.surface,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(GameTokens.spaceLg),
                child: Text(
              t(
                QrScanScreen.cameraUnavailableMessage,
                'Could not start the camera. You can type the code on the previous screen.',
              ),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: colors.ink),
                ),
              ),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(t('QRを読み取る', 'Scan QR code')),
        leading: IconButton(
          key: const ValueKey('qr-scan-cancel'),
          tooltip: t('前の画面へ戻る', 'Back to previous screen'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: scanner),
            Container(
              width: double.infinity,
              color: colors.surface,
              padding: const EdgeInsets.all(GameTokens.spaceLg),
              child: Text(
                t('QRを読み取った後も、内容を確認してから操作を続けます。映像や読み取った値を保存しません。', 'After scanning, you will review the contents before continuing. Camera images and scanned values are not saved.'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
