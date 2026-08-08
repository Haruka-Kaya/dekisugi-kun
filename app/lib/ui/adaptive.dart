import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import '_material.dart';

/// プラットフォームで作法が違うものだけを、ここに集める。
///
/// ## なぜ「iOS らしく」ではなく「Android に見えないように」なのか
///
/// この製品のデザインは `DESIGN.md` の数値（コントラスト 3:1、タップ域 48dp、
/// 和文の行送り、ソリッドな面と境界線）で組んであり、**どちらのOSの流儀でもない**。
/// 面・色・余白は共通のままでよい。
///
/// 一方で**OS が作法を持っているもの**は別で、
/// そこだけ Material のまま出すと「Android の移植」に見える。
/// 実機の iPad で最も目立ったのが**時刻ピッカーの丸い文字盤**だった。
///
/// ここに入れてよいのは次の3つだけ:
///
/// 1. **日付・時刻の選択** — 操作の型そのものが違う。合わせないと誤操作が増える
/// 2. **スイッチ** — 形が OS の記号になっている
/// 3. **タップの波紋** — 波紋は Android の署名。iOS には無い
///
/// **色や角丸をプラットフォームで変えないこと。** そこまで分けると
/// 「1つの製品」ではなく「2つの製品」になり、DESIGN.md の根拠も二重になる。

/// iOS / iPadOS か。**テストから差し替えられるようにしておく。**
bool get isApple {
  if (kDebugOverridePlatform case final v?) return v;
  // web では Platform を触れない
  return !kIsWeb && (Platform.isIOS || Platform.isMacOS);
}

/// テスト専用。`null` なら実際のプラットフォームを見る。
@visibleForTesting
bool? kDebugOverridePlatform;

/// 日付を選ぶ。
///
/// iOS ではホイール。Material のカレンダーを出すと、
/// **iPad で「Android アプリだ」と分かる最初の一手**になる。
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? helpText,
}) async {
  if (!isApple) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
    );
  }

  var picked = initial;
  final ok = await _cupertinoSheet(
    context,
    title: helpText,
    child: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: initial,
      minimumDate: first,
      maximumDate: last,
      onDateTimeChanged: (v) => picked = v,
    ),
  );
  return ok == true ? picked : null;
}

/// 時刻を選ぶ。**分は使わないので「時」だけ返す。**
///
/// 通知は1日1通で、分単位の精度に意味が無い。
/// 選ばせる幅を狭めるほど、選ぶのが楽になる。
Future<int?> pickHour(
  BuildContext context, {
  required int initial,
  String? helpText,
}) async {
  if (!isApple) {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial, minute: 0),
      helpText: helpText,
    );
    return t?.hour;
  }

  var picked = initial;
  final ok = await _cupertinoSheet(
    context,
    title: helpText,
    child: CupertinoPicker(
      itemExtent: 36,
      scrollController: FixedExtentScrollController(initialItem: initial),
      onSelectedItemChanged: (i) => picked = i,
      children: [
        for (var h = 0; h < 24; h++) Center(child: Text('$h:00')),
      ],
    ),
  );
  return ok == true ? picked : null;
}

/// 下から出るシート。**iOS の作法に合わせるのはここだけ。**
Future<bool?> _cupertinoSheet(
  BuildContext context, {
  required Widget child,
  String? title,
}) {
  final scheme = Theme.of(context).colorScheme;
  final t = Theme.of(context).textTheme;

  return showCupertinoModalPopup<bool>(
    context: context,
    builder: (ctx) => Container(
      height: 320,
      // **色は共通のトークンから取る。** ここで Cupertino の既定色を使うと、
      // 画面の他の部分と地の色が食い違う
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('やめる'),
                  ),
                  Expanded(
                    child: Text(
                      title ?? '',
                      textAlign: TextAlign.center,
                      style: t.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('決定'),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}
