import 'dart:math' as math;

import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final entry in {
    'light': GamePalette.light,
    'dark': GamePalette.dark,
  }.entries) {
    test('${entry.key}の状態foreground/backgroundは4.5:1以上', () {
      final p = entry.value;
      final pairs = <String, (Color, Color)>{
        '本文': (p.ink, p.canvas),
        '補助本文': (p.inkMuted, p.canvas),
        'Path': (p.onPathActive, p.pathActive),
        '完了': (p.onPathComplete, p.pathComplete),
        '復習': (p.onPathReview, p.pathReview),
        '未解放': (p.onPathLocked, p.pathLocked),
        'Story': (p.onStory, p.story),
        'Legendary': (p.onLegendary, p.legendary),
        'Quest件数badge': (p.onHeart, p.heart),
      };
      for (final pair in pairs.entries) {
        expect(
          _contrast(pair.value.$1, pair.value.$2),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}/${pair.key}',
        );
      }
    });
  }
}
