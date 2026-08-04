/// UI レイヤの import 集約点。
///
/// **画面・ウィジェットからは `package:flutter/material.dart` を直接 import せず、
/// このファイルを import すること。**
///
/// 理由: Material / Cupertino は Flutter 3.44 のブランチカット（2026-04-07）で
/// コアフレームワーク内に凍結され、今後の更新は `material_ui` / `cupertino_ui` という
/// 独立パッケージ側でのみ行われる。将来の置換をこの1ファイルの書き換えで済ませる。
///
/// 移行はまだしない。`material_ui` は 0.0.2（pre-1.0）で、pub の semver 慣習上
/// パッチ間でも破壊的変更が許容される。いま必要なのは import の集約だけ。
library;

export 'package:flutter/material.dart';
