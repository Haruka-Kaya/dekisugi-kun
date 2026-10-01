import 'dart:convert';
import 'dart:io';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/dekisugi_character_art.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _sourceKey = ValueKey<String>('native-brand-source');

Directory get _appRoot {
  final current = Directory.current;
  if (File('${current.path}/pubspec.yaml').existsSync()) return current;
  return Directory('${current.path}/app');
}

DekisugiCharacterArt _character({
  required Color body,
  required Color face,
  required Color accent,
  required Color signal,
  double size = 1024,
}) => DekisugiCharacterArt(
  pose: DekisugiCharacterPose.idle,
  decoration: DekisugiCharacterDecoration.standard,
  size: size,
  body: body,
  face: face,
  accent: accent,
  signal: signal,
  ornament: accent,
  ornamentSignal: signal,
);

Future<void> _expectSourceGolden(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  required String filename,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(key: _sourceKey, child: child),
      ),
    ),
  );
  await tester.pump();
  await expectLater(
    find.byKey(_sourceKey),
    matchesGoldenFile('goldens/$filename'),
  );
}

Widget _featureGraphic() {
  const palette = GamePalette.light;
  const character = AppColors.light;
  return SizedBox(
    width: 1024,
    height: 500,
    child: ColoredBox(
      color: palette.canvas,
      child: Row(
        children: [
          SizedBox(
            width: 480,
            child: Center(
              child: _character(
                body: character.charBody,
                face: character.charFace,
                accent: character.charAccent,
                signal: palette.ink,
                size: 420,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 40, right: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'デキすぎ君',
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '観察から、\n説明へ。',
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 48,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '予想・比較・教え返しを、探究ノートに。',
                    style: TextStyle(
                      fontFamily: 'NotoSansJP',
                      fontSize: 22,
                      height: 1.5,
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

int _pngColorType(Uint8List bytes) {
  expect(bytes.sublist(1, 4), <int>[0x50, 0x4E, 0x47]);
  // PNG signature 8 bytes + IHDR length/type 8 bytes + width/height/bit depth。
  return bytes[25];
}

Future<(int, int)> _pngSize(File file) async {
  final bytes = await file.readAsBytes();
  expect(bytes.sublist(12, 16), <int>[0x49, 0x48, 0x44, 0x52]);
  int uint32(int offset) =>
      bytes[offset] << 24 |
      bytes[offset + 1] << 16 |
      bytes[offset + 2] << 8 |
      bytes[offset + 3];
  return (uint32(16), uint32(20));
}

void _expectPng(
  String relativePath, {
  required int width,
  required int height,
  required int colorType,
}) {
  final file = File('${_appRoot.path}/$relativePath');
  test(relativePath, () async {
    expect(file.existsSync(), isTrue, reason: relativePath);
    expect(await _pngSize(file), (width, height));
    expect(_pngColorType(await file.readAsBytes()), colorType);
  });
}

void main() {
  for (final entry in const <(String, AppColors, GamePalette)>[
    ('light', AppColors.light, GamePalette.light),
    ('dark', AppColors.dark, GamePalette.dark),
  ]) {
    testWidgets('runtime正本のidle character source — ${entry.$1}', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      await _expectSourceGolden(
        tester,
        size: const Size.square(512),
        filename: 'native_brand_character_${entry.$1}.png',
        child: _character(
          body: entry.$2.charBody,
          face: entry.$2.charFace,
          accent: entry.$2.charAccent,
          signal: entry.$3.ink,
          size: 512,
        ),
      );
    });
  }

  testWidgets('runtime正本のAndroid themed icon source', (tester) async {
    addTearDown(tester.view.reset);
    await _expectSourceGolden(
      tester,
      size: const Size.square(512),
      filename: 'native_brand_character_monochrome.png',
      child: _character(
        body: Colors.black,
        face: Colors.white,
        accent: Colors.black,
        signal: Colors.white,
        size: 512,
      ),
    );
  });

  testWidgets('Field Notebook store feature source', (tester) async {
    addTearDown(tester.view.reset);
    final loader = FontLoader('NotoSansJP')
      ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Variable.ttf'));
    await loader.load();
    await _expectSourceGolden(
      tester,
      size: const Size(1024, 500),
      filename: 'native_brand_feature.png',
      child: _featureGraphic(),
    );
  });

  group('native brand PNG contract', () {
    const androidSizes = <String, (int, int)>{
      'mdpi': (48, 108),
      'hdpi': (72, 162),
      'xhdpi': (96, 216),
      'xxhdpi': (144, 324),
      'xxxhdpi': (192, 432),
    };
    for (final entry in androidSizes.entries) {
      _expectPng(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        width: entry.value.$1,
        height: entry.value.$1,
        colorType: 2,
      );
      _expectPng(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png',
        width: entry.value.$2,
        height: entry.value.$2,
        colorType: 6,
      );
      _expectPng(
        'android/app/src/main/res/mipmap-night-${entry.key}/ic_launcher.png',
        width: entry.value.$1,
        height: entry.value.$1,
        colorType: 2,
      );
      _expectPng(
        'android/app/src/main/res/mipmap-night-${entry.key}/ic_launcher_foreground.png',
        width: entry.value.$2,
        height: entry.value.$2,
        colorType: 6,
      );
    }

    _expectPng(
      'android/app/src/main/res/drawable-nodpi/ic_launcher_monochrome.png',
      width: 108,
      height: 108,
      colorType: 6,
    );
    for (final prefix in ['drawable-nodpi', 'drawable-night-nodpi']) {
      _expectPng(
        'android/app/src/main/res/$prefix/launch_mascot.png',
        width: 336,
        height: 370,
        colorType: 6,
      );
      _expectPng(
        'android/app/src/main/res/$prefix/launch_mascot_v31.png',
        width: 288,
        height: 288,
        colorType: 6,
      );
    }

    const iosIcons = <String, int>{
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final entry in iosIcons.entries) {
      _expectPng(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
        width: entry.value,
        height: entry.value,
        colorType: 2,
      );
    }

    for (final item in const <(String, int, int)>[
      ('LaunchImage.png', 168, 185),
      ('LaunchImage@2x.png', 336, 370),
      ('LaunchImage@3x.png', 504, 555),
      ('LaunchImage-dark.png', 168, 185),
      ('LaunchImage-dark@2x.png', 336, 370),
      ('LaunchImage-dark@3x.png', 504, 555),
    ]) {
      _expectPng(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/${item.$1}',
        width: item.$2,
        height: item.$3,
        colorType: 6,
      );
    }

    _expectPng(
      '../docs/store/icon-1024.png',
      width: 1024,
      height: 1024,
      colorType: 2,
    );
    _expectPng(
      '../docs/store/icon-512.png',
      width: 512,
      height: 512,
      colorType: 6,
    );
    _expectPng(
      '../docs/store/feature-1024x500.png',
      width: 1024,
      height: 500,
      colorType: 2,
    );
  });

  test('Android adaptive・themed・API 31 splash参照が実在する', () {
    final res = Directory('${_appRoot.path}/android/app/src/main/res').path;
    final v33 = File(
      '$res/mipmap-anydpi-v33/ic_launcher.xml',
    ).readAsStringSync();
    expect(v33, contains('@mipmap/ic_launcher_foreground'));
    expect(v33, contains('@drawable/ic_launcher_monochrome'));
    expect(
      File('$res/drawable-nodpi/ic_launcher_monochrome.png').existsSync(),
      isTrue,
    );

    for (final qualifier in ['values-v31', 'values-night-v31']) {
      final styles = File('$res/$qualifier/styles.xml').readAsStringSync();
      expect(styles, contains('android:windowSplashScreenBackground'));
      expect(styles, contains('@drawable/launch_mascot_v31'));
    }
  });

  test('iOS asset catalogの全参照が実在しdark launchを持つ', () {
    final assets = Directory('${_appRoot.path}/ios/Runner/Assets.xcassets');
    for (final setName in ['AppIcon.appiconset', 'LaunchImage.imageset']) {
      final set = Directory('${assets.path}/$setName');
      final contents =
          jsonDecode(File('${set.path}/Contents.json').readAsStringSync())
              as Map<String, Object?>;
      final images = contents['images']! as List<Object?>;
      for (final item in images.cast<Map<String, Object?>>()) {
        final filename = item['filename'] as String?;
        if (filename != null) {
          expect(
            File('${set.path}/$filename').existsSync(),
            isTrue,
            reason: '$setName/$filename',
          );
        }
      }
    }

    final launch =
        jsonDecode(
              File(
                '${assets.path}/LaunchImage.imageset/Contents.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final images = (launch['images']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final dark = images.where((item) {
      final appearances = item['appearances'] as List<Object?>?;
      return appearances?.cast<Map<String, Object?>>().any(
            (appearance) =>
                appearance['appearance'] == 'luminosity' &&
                appearance['value'] == 'dark',
          ) ??
          false;
    });
    expect(dark, hasLength(3));
  });
}
