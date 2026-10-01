import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Allows only the tiny anti-aliasing drift observed between Flutter's macOS
/// and Linux software rasterizers. Layout, palette, typography, and component
/// changes remain large enough to fail the comparison.
final class RasterStableGoldenComparator extends LocalFileComparator {
  RasterStableGoldenComparator(
    super.testFile, {
    this.maxDiffFraction = 0.00004,
  });

  final double maxDiffFraction;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= maxDiffFraction) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
