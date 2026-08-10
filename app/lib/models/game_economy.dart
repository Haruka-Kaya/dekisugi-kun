import 'package:flutter/foundation.dart';

import '../learning/domain/learning_economy.dart';

/// 固定catalogと保存済み所有状態から作る、結晶交換面専用DTO。
@immutable
final class GameCosmeticItemView {
  const GameCosmeticItemView({
    required this.productId,
    required this.title,
    required this.description,
    required this.gemCost,
    required this.mascotStyle,
    required this.owned,
    required this.equipped,
    required this.canPurchase,
  });

  final String productId;
  final String title;
  final String description;
  final int gemCost;
  final LearningPathMascotStyle mascotStyle;
  final bool owned;
  final bool equipped;
  final bool canPurchase;
}
