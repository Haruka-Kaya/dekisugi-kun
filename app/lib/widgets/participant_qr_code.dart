import 'dart:math' as math;

import 'package:qr_flutter/qr_flutter.dart';

import '../config/game_tokens.dart';
import '../ui/_material.dart';

/// 参加・教材番号を共有するためのQR表示。
///
/// 呼び出し側が渡すpayloadは参加資格または教材番号だけに限る。管理キー、
/// 生徒名、回答、音声、端末IDはこのwidgetへ渡さない。
class ParticipantQrCode extends StatelessWidget {
  const ParticipantQrCode({
    super.key,
    required this.data,
    required this.semanticLabel,
    this.maxSize = 224,
  });

  final String data;
  final String semanticLabel;
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('participant-qr-code'),
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 幅の狭いsheetやsplit viewでも、最低サイズを優先して親から
            // はみ出さない。十分な幅がある通常画面ではmaxSizeまで表示する。
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : maxSize;
            final size = math
                .min(maxSize, math.max(0.0, availableWidth))
                .toDouble();
            return Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(GameTokens.spaceSm),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.border, width: 2),
                borderRadius: BorderRadius.circular(GameTokens.radiusSm),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                gapless: true,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: colors.ink,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: colors.ink,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
