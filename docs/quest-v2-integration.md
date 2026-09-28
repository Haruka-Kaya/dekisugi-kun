# Quest V2 production統合契約

更新日: 2026-08-10

## 現行監査

| 項目 | production導線の現在証拠 | 判定 |
|---|---|---|
| Dailyの日替わり内容 | 到達可能なPath、日次Listening / Speaking、未完了Notation、期限復習から8種を巡回し、固有origin / activity kind / evidenceだけを1件数える | 成立 |
| Dailyの固有CTA | plannerの`destination + focus`をHomeが実タブとLesson / Story / Listening / Speaking / Diagram / Notation / Transfer / due routeへ接続する | 成立。8 routeのHome E2Eあり |
| Monthly | 同じmeaningful event台帳12件、8結晶、`LearningMonthlyBadgeProjection`による一意badge、Home E2E | 成立 |
| local-only Friends | 共通Quest sheet、同一端末の実2枠、0/2→1/2→2/2、3結晶の冪等付与、Home E2E | 成立 |
| 成人同意済みLAN Friends | client / coordinatorの共同snapshotを共通Quest sheetへ投影し、1/2から固有CTAでLAN画面を開く。1結晶はroom単位で冪等 | 成立 |
| school境界 | 学校dailyは端末内1件・無報酬。Monthly / Friends / 個人walletへ混ぜない | 成立 |
| under-18本人利用 | `LearningScope.personal`のlocal-only経路で個人学習は可能、LAN socialは無効 | 成立。V2でもLAN sourceを拒否する |

## 独立実装したplanner / projection API

`app/lib/learning/services/learning_quest_plan_v2.dart`を正本にし、HomeとStoreが次のAPIを直接使う。

- `LearningDailyQuestAvailabilityProjection`
  - 現在の未完了Path node、未完了の日次Listening / Speaking、未完了Notation、期限到来済み復習だけから候補を作る
  - 完了済みnodeの単なる周回を候補にしない
- `LearningQuestPlannerV2`
  - 予想、Story、Listening、Speaking、図、Notation、転移、期限復習の8種類
  - すべて固有title、description、CTA label、destination、focusを持つ
  - 日ordinalで候補を決定論的に巡回し、4時境界を`dayKeyOf`へ一本化する
  - V1の同日materialized rowを復元し、更新日当日に途中差し替えない
  - 意味のある候補が0ならdailyを作成・保存せず、Monthlyに「次の復習日を待つ」と表示する
  - Monthly 12件 / 8結晶 / badgeの既存definitionを維持する
  - V2 instance keyからorigin / activity kind / evidence / target / rewardを含む完全なcanonical definitionを復元する
- `LearningQuestBoardProjectionV2`
  - Daily / Monthly / Friendsを同じboard itemへ束ねる
  - `personalLocalOnly` / `personalLanConsented` / `schoolLocal`を交差させない
  - participant ID、氏名、回答、音声、友達graphを受け取らない
- `LearningFriendsQuestBoardSource`
  - local invite / local実run / LAN invite / LAN共同snapshotを共通表示へ変換する
  - LANは0/2、自分の寄与後1/2、共同完了2/2だけを公開する

## 実装済みStore API

現Storeは、Questに一致する最初のmeaningful eventをcommitした時だけ`learning_quest_progress`行を作る。V2は現在の到達可能候補から日替わり内容を選ぶため、表示後に別activityを終えて候補集合が変わると、最初のeventより前に同日のvariantが差し替わりうる。

この競合を避けるため、`SessionStore`と`LearningProgressStore`へ次のAPIを実装した。

```dart
Future<LearningQuestMaterializationResult>
materializeLearningQuestDefinitions({
  required LearningScope scope,
  required Iterable<LearningQuestDefinition> definitions,
});
```

成立済み契約:

- `personal`のcanonical V2 daily / monthlyだけを受ける。schoolは空listだけをno-opとして受け、非空listと`local-coop:`を拒否する
- 未存在行を`progress = 0`、`completedAt = null`、`rewardedAt = null`で1 transactionに挿入する
- `LearningQuestMaterializationResult.insertedCount`で初回挿入数を返し、同じ完全definitionの再送は0件のno-opになる
- 同じinstanceのtarget / version / reward / allowed origins / allowed activity kinds / minimum evidence不一致を、既存行の有無にかかわらず書き込み前にfail closedする
- 同じ学習日に別daily variantが既にある場合は全体をrollbackする
- materializeだけではevent、node、skill、day、streak、XP、結晶、badgeを作らない
- Memory / SQLiteで同一挙動にし、SQLite再起動後も0件definitionを復元する
- 通常の`commitLearningEvent`も同じcanonical照合を通し、materializeを迂回したfilter改変を拒否する
- plannerの`definitionsToMaterialize`だけを入力に使い、画面が独自definitionを作らない

### migration不要とするmetadata境界

既存`learning_quest_progress`行が保存するdefinition metadataは`quest_instance_id`、`target`、`definition_version`だけで、filtersと`rewardGems`の列はない。今回のV2は次の不変条件を同じplanner catalogへ固定したため、schema v13のまま安全に扱える。

- 8種類のdaily keyとmonthlyの`twelve-actions` keyは重複せず、instance IDから定義全体を一意に復元できる
- Storeはmaterializeとcommitの両方で、入力definitionをinstance IDから復元した正本と完全比較する
- production Homeはcanonical planner出力だけをmaterializeするため、画面独自のV2行を作らない

将来、同じinstance keyのままfiltersや報酬を動的変更する要件が入る場合、この境界は使えない。その場合はschemaを更新し、canonical definition signature（少なくともreward、origin集合、activity kind集合、minimum evidence）を行へ保存して照合する。keyまたはdefinition versionを変えずに意味だけを変える実装は禁止する。

契約テストはMemory / SQLiteの両実装で、progress 0・報酬0、同definition再送、metadata改変拒否、school無報酬を実行する。別のfile-backed SQLiteテストでclose→open後の0件復元・同日variant固定・再送no-op・初回対象activityの正常報酬も確認する。

## production統合済みの順序

1. rulesなしでcatalogと現在snapshotを読む
2. Path / due / Notationの事実からavailabilityを投影する
3. audienceをlocal-only、成人LAN同意済み、schoolのいずれかへ明示してV2 planを作る
4. `definitionsToMaterialize`を上記Store APIへ渡す
5. snapshotを再読込し、同じV2 planを復元する
6. 以後の学習commitへ`plan.commitRules`を渡す
7. local runまたはLAN snapshotをFriends sourceへ変換し、共通boardを作る
8. CTAの`destination + focus`をHomeが実際のタブ・スクロール先・LAN routeへ接続する

候補0ではdailyを捏造せずMonthlyだけを表示し、Pathを維持する。materialize自体が失敗した場合もQuest rules / boardだけをfail closedにし、Quest sheetへ再試行を出してPathと既存進捗をblankにしない。

## production受入テスト

- 8種類それぞれについて、Quest sheetの固有CTAから対応する実activity routeを開くHome E2E
- Homeの実Lesson完了でmaterialize済みdailyが1/1・結晶1個になり、Store契約で無関係なmeaningful activityは0/1のまま、対象activityだけが進む
- 03:59表示→別activity→04:00前の再表示でもvariant固定、04:00で新definitionへ切替
- materialize直後のOS終了→SQLite再起動でも同じ0/1 variant
- 候補0はdaily行を作らず、復習日待ちのMonthly CTAとPathを維持
- materialize保存失敗時は旧plannerへ黙ってfallbackせず、Pathを維持して再試行可能なQuest unavailable表示
- under-18 / local-onlyではLAN CTAが存在せず、成人同意済みではlocal pairを混ぜない
- LAN Friendsの待機0/2、自分寄与1/2、共同完了2/2、報酬記録済みをpure projectionで固定し、Homeでは実1/2とLAN routeをE2E確認
- 同じevent / room / contributionの再送で進捗・結晶・badgeが増えない

Store、planner、Home materialize、同plan commit / projection、8種CTA、Monthly badge、local / LAN Friends共通boardまでproduction接続済み。学校は無報酬・Friendsなし、local-onlyはLANなし、成人LAN同意経路はlocal pairなしを維持する。
