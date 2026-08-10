import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import '_material.dart';

/// プラットフォームで作法が違うものだけを、ここに集める。
///
/// ## なぜ「iOS らしく」ではなく「Android に見えないように」なのか
///
/// この製品のデザインは共通トークン（コントラスト 3:1、タップ域 48dp、
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
/// 「1つの製品」ではなく「2つの製品」になり、判断根拠も二重になる。

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
  // 保存済みの考査日が過ぎていても、ピッカー自体は開けなければならない。
  // Material/Cupertino とも initial が範囲外だと assert するため、
  // 「日付」へ正規化してから現在の選択可能範囲へ収める。
  final firstDate = _dateOnly(first);
  final lastDate = _dateOnly(last);
  assert(!lastDate.isBefore(firstDate));
  final initialDate = _clampDate(_dateOnly(initial), firstDate, lastDate);

  if (!isApple) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    );
  }

  var picked = initialDate;
  final ok = await _cupertinoSheet(
    context,
    title: helpText,
    child: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: initialDate,
      minimumDate: firstDate,
      maximumDate: lastDate,
      itemExtent: _pickerItemExtent(context),
      onDateTimeChanged: (v) => picked = v,
    ),
  );
  return ok == true ? picked : null;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
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
      itemExtent: _pickerItemExtent(context),
      scrollController: FixedExtentScrollController(initialItem: initial),
      onSelectedItemChanged: (i) => picked = i,
      children: [for (var h = 0; h < 24; h++) Center(child: Text('$h:00'))],
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
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final scale = media.textScaler.scale(1);
      final desired = 320.0 + math.max(0, scale - 1) * 96;
      final height = math.min(desired, media.size.height * 0.78);
      return Container(
        height: height,
        // **色は共通のトークンから取る。** ここで Cupertino の既定色を使うと、
        // 画面の他の部分と地の色が食い違う
        color: scheme.surface,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
                child: Column(
                  children: [
                    if (title?.isNotEmpty == true) ...[
                      Text(
                        title!,
                        textAlign: TextAlign.center,
                        style: t.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('やめる'),
                        ),
                        CupertinoButton.filled(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('決定'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      );
    },
  );
}

double _pickerItemExtent(BuildContext context) {
  final fontSize = Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16;
  return math.max(44, MediaQuery.textScalerOf(context).scale(fontSize) + 18);
}
