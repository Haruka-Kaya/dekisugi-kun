import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart' show HapticFeedback;

import '../ui/_material.dart';

/// 演出の決まりごと。**数値を自作しない。**
///
/// `Durations` と `Easing` は Material Design のトークンデータベースから
/// 生成された定数で、M3 仕様そのものと同一視してよい（Flutter に実値で入っている）。
/// ここでは「どの場面でどれを使うか」だけを決める。
abstract final class Motion {
  /// 繰り返し起きる操作。チップの色変化、状態バッジの切り替えなど。
  ///
  /// M3 の standard スキームは "utilitarian UI elements and **recurring
  /// interactions**" 向けと定義されている。全部を跳ねさせない。
  static const Duration quick = Durations.short2; // 100ms
  static const Curve quickCurve = Easing.standard;

  /// 状態が変わったことを見せる。「聞いている→考えている」など。
  static const Duration state = Durations.medium2; // 300ms
  static const Curve stateCurve = Easing.standard;

  /// 達成の瞬間だけ。概念が「説明できた」に変わったとき。
  ///
  /// `emphasizedDecelerate` は仕様上**「画面内に入ってくる要素」用**。
  static const Duration celebrate = Durations.long2; // 500ms
  static const Curve celebrateCurve = Easing.emphasizedDecelerate;

  /// まばたき。1回ぶん（開く→閉じる→開く の片道）。
  static const Duration blink = Durations.short3; // 150ms

  /// まばたきの間隔。**待機中に動くのはここだけ。**
  ///
  /// 実測で、毎フレーム描き続けると 1コアの 71〜91% を食う（Rive の有無に関わらず）。
  /// 主犯はパイプラインを毎フレーム回すこと自体で、fps を落としても効かない。
  /// **効くのは止めること。** 4秒に150ms なら稼働率 3.75%。
  static const Duration blinkInterval = Duration(seconds: 4);

  /// 達成の触覚。
  ///
  /// **`successNotification()` を使わない。** Android API 30 未満で完全に無音で、
  /// 中高生の端末は古い可能性が高い。
  ///
  /// **触覚だけに頼らないこと。** これは色・形・文言に添えるものであって、
  /// これ単体で達成を伝えてはいけない。鳴らない端末では何も起きない。
  static Future<void> celebrateHaptic() => HapticFeedback.mediumImpact();
}

/// 端末の「アニメーションを減らす」設定。
///
/// **口が2つあり、片方しか見ないと半分の利用者に効かない。**
/// - `MediaQuery.disableAnimationsOf` は Android の「アニメーションを削除」専用
/// - iOS の「視差効果を減らす」は `AccessibilityFeatures.reduceMotion` にしか出ない
///
/// 後者は MediaQuery に反映されないので、変化を自分で購読する必要がある。
class ReduceMotionScope extends StatefulWidget {
  const ReduceMotionScope({super.key, required this.child});

  final Widget child;

  /// いま「動きを減らす」べきか。
  static bool of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_ReduceMotionMarker>();
    // Android 側（MediaQuery）は毎回読む。こちらは変化で自動的に再構築される
    return (scope?.platformReduceMotion ?? false) ||
        MediaQuery.disableAnimationsOf(context);
  }

  @override
  State<ReduceMotionScope> createState() => _ReduceMotionScopeState();
}

class _ReduceMotionScopeState extends State<ReduceMotionScope> {
  late bool _reduce = PlatformDispatcher.instance.accessibilityFeatures.reduceMotion;
  VoidCallback? _previous;

  @override
  void initState() {
    super.initState();
    // 既存のハンドラを潰さない。設定変更は稀なので、繋いで両方呼ぶ
    _previous = PlatformDispatcher.instance.onAccessibilityFeaturesChanged;
    PlatformDispatcher.instance.onAccessibilityFeaturesChanged = () {
      _previous?.call();
      final now = PlatformDispatcher.instance.accessibilityFeatures.reduceMotion;
      if (mounted && now != _reduce) setState(() => _reduce = now);
    };
  }

  @override
  void dispose() {
    PlatformDispatcher.instance.onAccessibilityFeaturesChanged = _previous;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ReduceMotionMarker(platformReduceMotion: _reduce, child: widget.child);
}

class _ReduceMotionMarker extends InheritedWidget {
  const _ReduceMotionMarker({
    required this.platformReduceMotion,
    required super.child,
  });

  final bool platformReduceMotion;

  @override
  bool updateShouldNotify(_ReduceMotionMarker old) =>
      old.platformReduceMotion != platformReduceMotion;
}
