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
        '次の観察': (p.onAction, p.action),
        '観察済み': (p.onEvidence, p.evidence),
        '再観察': (p.onRevisit, p.revisit),
        '未解放': (p.onLocked, p.locked),
        '事件ファイル': (p.onCaseFile, p.caseFile),
        '総合検証': (p.onFieldTest, p.fieldTest),
        '試行余力badge': (p.onAttempt, p.attempt),
      };
      for (final pair in pairs.entries) {
        expect(
          _contrast(pair.value.$1, pair.value.$2),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key}/${pair.key}',
        );
      }
    });

    test('${entry.key}のField Notebook役割は互換色へ一意に接続する', () {
      final p = entry.value;
      expect(p.paper, p.canvas);
      expect(p.bench, p.surface);
      expect(p.benchRaised, p.surfaceRaised);
      expect(p.action, p.pathActive);
      expect(p.evidence, p.pathComplete);
      expect(p.revisit, p.pathReview);
      expect(p.locked, p.pathLocked);
      expect(p.caseFile, p.story);
      expect(p.fieldTest, p.legendary);
      expect(p.continuity, p.streak);
      expect(p.crystal, p.gem);
      expect(p.attempt, p.heart);
    });
  }

  test('Field Notebookの面は低角丸、強罫線は4dpで固定する', () {
    expect(GameTokens.radiusXs, 2);
    expect(GameTokens.radiusSm, 6);
    expect(GameTokens.radiusMd, 10);
    expect(GameTokens.radiusLg, 14);
    expect(GameTokens.radiusSheet, 18);
    expect(GameTokens.accentRuleWidth, 4);
  });
}
