import 'dart:async';

import 'package:dekisugi/services/units_client.dart';

/// `flutter test` はfake asyncで動くため、実isolateへ投げる `compute` の
/// 完了を `pumpAndSettle` が待てない。同梱カタログのdecodeだけ同期経路へ
/// 切り替える（生成物は同じ）。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  UnitsClient.debugSynchronousBundledCatalog = true;
  await testMain();
}
