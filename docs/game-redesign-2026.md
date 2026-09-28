# デキすぎ君 — 全面ゲーム再設計 2026

## 目的

UIにポイントや色を足すのではなく、学習行為そのものをゲームの進行にする。
1ノードごとに要求する認知行為を変え、`予想 → 図式化 → 物語で判断 →
聞き取る → 説明する → 誤概念を直す → 別場面へ使う`を一本道に編成する。

8単元23概念×A/B/C（foundation / conditions / transfer）を科学内容の正本とし、
Path・Story・Labは参照する。正答や説明を別画面に複製しない。
教材はcatalog schema v10、個人学習と結晶経済・端末内League履歴の保存契約はSessionStore v13とする。

## アプリ構造

| タブ | 役割 | コア体験 |
|---|---|---|
| 学ぶ | 縦型Learning Path | 必修ノード、埋め込み復習、章ボス |
| 物語 | 理科の事件簿 | 23件の固有事件名、固定人物と会話、途中予想、人物別反応、科学的解決と短い落ち |
| 練習 | Personalized Practice | 期限が来た概念、Repair、Listen/Speak、任意Timed |
| 記号 | Notation Lab | 力の矢印と式を実際になぞり、単位・グラフも構造操作で確かめる |
| 競う | 意味ある週次挑戦 | 成人onlineは管理LAN上の実参加者5〜8人、local-onlyは同じ端末を手渡す代替。周回稼ぎを認めない |
| 自分 | 学習記録と設定 | 自分の説明、到達、quest、streak保護、privacy |

6タブは共通GameTokensで色・余白・角丸・タッチ領域・日本語typographyを揃える。
連続学習・結晶・heart・quest入口は`GameShell`がタブpageの外に保持し、
どのタブへ移動しても上部の同じ位置に固定する。
各activity routeも共通`GameActivityScaffold`で戻る・連続学習・結晶・heartを本文の外に固定し、
誤答保存後のheart変化を開いている画面へ反映する。キャラクターは飾りではなく、開始、思考中、
訂正、完了のphaseから決まる静的reactionを表示し、Reduce Motionでも意味を失わせない。
「学ぶ」はPlayer Statusと蛇行Pathに特化した専用面とし、「物語」「練習」「記号」
「競う」「自分」の5ハブは`GamePageScaffold` / `GameHeroSurface`で可読幅、solidな主役面、
見出し階層を共有する。全画面を同じcard配置にすることは統一とはみなさない。

Pathの基本列は次とする。

```text
Learn(A) → Diagram(B) → Story(A) → Listen(B)
         → Speak(C) → Boss(C)
                    ↘ wrong only: Repair
                    ↘ optional: Timed
                    ↘ unit内の全Boss後・次の学習日: Unit Legendary
```

必修ノードはネットワーク、生成AI、マイクのいずれが無くても完了可能にする。
音声には同じ位置に文字経路を置く。既存Live会話は任意の `Teach Live` 拡張で、
Path解放・Boss・学校提出の条件にしない。

## 進行状態

保存するのは事実だけに限定する。

- LearningEvent: node/activity/skill、結果、evidence段階、学習日、時刻
- Node progress: inProgress/cleared、attempts、best evidence
- Skill progress: 次回復習日、保持成功回数、catalog固定practice needと解消記録
- Wallet ledger: XP/gemsの付与理由とsource event
- Quest progress: 定義version、目標、進捗、完了
- Run checkpoint: nodeとactivity index、回答と分離した共有heartの鏡像
- Heart ledger: 安定loss IDと回復practice event IDだけ
- Gem spend ledger: 冪等spend ID、固定catalog参照、学習日、消費量
- Cosmetic loadout: 購入済みPathマスコットから選んだ固定product IDだけ

自由記述、録音、ASR全文、選んだ選択肢、反応時間は保存しない。学校課題のeventは
`schoolLocal` scopeへ隔離し、個人のPath・wallet・streak・questへ混ぜない。

## 報酬規則

XPは「押した回数」ではなく、初回の意味ある完了・異日の想起・転移だけに付ける。
同日同内容の反復、速度、誤答回数では増減させない。全付与はevent IDで冪等にする。

| 行為 | XP | 備考 |
|---|---:|---|
| Path nodeの初回完了 | 10 | 自由記述の正しさは判定しない |
| 期限到来後のspaced transfer | 10 | 前倒し・同日周回は0 |
| 完了済みnodeの再演 | 0 | 別日でも期限前ならXP farm不可 |
| Timed再周回 | 0 | Path結果は作らず、固定誤答の一般化needだけ保存可 |

個人XPは1日30まで。同じevent IDの再送、同じnodeの同日反復、期限前の
LegendaryではXPとquestを増やさない。

gemsはquest完了からだけ付与し、連続記録の保護補充（3個）、学習Heartsの
全回復（2個）、固定Pathマスコット（4個／6個）、任意Timedの日次券（1個）にだけ使える。
Timed券は同じ学習日に再入場できるが、Path・XP・正答・解説は購入できず、Match / Lightningは
無料のままとする。全消費は固定catalogで価格を再照合し、spend IDで冪等、残高不足時は原子的に
拒否する。実課金・ガチャは使わず、学校scopeでは付与・消費・装備を行わない。個人HeartsはPath、Repair、日次Listening、Notation、
Timed / Match / Lightning、Unit Legendaryの固定誤答ごとに1個減る。0では通常学習の
新規開始を止め、30分ごと1個、または専用のheart回復練習を1件完了すると1個戻す。
通常Practiceや学習日の変更で全回復はしない。`schoolLocal`は常に無制限で、誤答で減らず開始も遮断しない。

loss保存を待ってから画面内の再挑戦可否を判定する。最後の1個を失った複数問課題は次問を
開かず、回復導線へ戻す。学習eventのcommit後に回復記録だけが失敗した場合は、同じevent / recovery
IDと時刻で再実行し、二重event・二重回復を作らない。

streakはevidence `selfCompared`以上のeventがある学習日だけ1日進む。freeze日は記録を
維持するが、実際の学習日として水増ししない。直近学習日から1日だけ欠け、該当週のfreezeが
残っている朝はprojection上で先に仮保護し、学習完了前だけ減衰してcommit後に突然復活する表示を作らない。
実消費は次のmeaningful eventと同じtransactionで確定する。freezeなしで1日抜けた場合も全消失させず、
表示上の継続日数を7日ずつ減衰させる。長く離れたときは0まで下がるため、事実でない
「1日継続中」は残さない。freezeの不足は学習内容や過去の到達を消さない。

questは日次・月次の意味ある学習、local-onlyで同じ端末を手渡す実在2人のペア課題、
成人onlineで同じ管理LANへ参加する実在2人のFriends roomだけにする。
personal dailyは現在到達可能なPath、Story、Listening、Speaking、Diagram、Notation、転移、
期限復習の8種類から、4時境界の学習日ordinalでmeaningful action 1件を決定論的に選び、1結晶を付与する。
表示前に進捗0のcanonical definitionを冪等materializeし、同日中に候補が変わっても差し替えない。
候補が0なら達成不能なdailyを捏造せず、月間記録と次の復習日待ちを表示してPathを維持する。
各CTAは対応する実activityを直接開く。school dailyはこの端末のmeaningful action 1件だけで、
結晶を付与しない。personal monthlyは同じmeaningful event台帳の12件を目標にし、
達成時は8結晶を冪等付与する。
月間quest達成はその月の固定観測バッジを一意に解放し、購入品と分けてProfileに表示する。
XP獲得量やアプリ滞在時間を目標にしない。accountや永続的な友達graphは作らず、roomごとの
不透明credentialだけを使う。架空の友達や架空の進捗へ置き換えない。

## League境界

- 学校モード: LAN social、個人順位、gem、storeなし。「この端末の授業目標」だけ。
- 成人personal online: 明示同意後だけ、利用者が管理する自己署名TLSのLAN coordinatorへ接続する。
  Friendsは実在2人の共同状態だけ、Leagueは実在5〜8人の匿名順位とBronze→Diamond 10段tierを
  表示する。氏名・account・回答・正誤・音声・端末IDは送らない。5人未満では順位・人数を隠す。
  roomの生データを削除する前に参加資格ごとの最小terminal receiptをHMAC keyで確定し、長期offline端末も
  端末保存成功後にだけmembershipを削除する。保存・通信失敗では資格を保持して再試行する。
- personal local-only（18歳未満の本人利用／成人）: 利用者が2〜8人を明示して同じ端末を手渡す。
  不透明slotだけを保存し、途中順位は実eventだけから投影する。5〜8人の週だけslot 1を
  「この端末の学習者」として、実順位からBronze→Diamond 10段を週終了後に最大±1段で確定する。
  2〜4人は途中順位だけでtier履歴を作らず、架空ユーザー・偽順位・旧4段XP tierは主表示に使わない。
  複数週起動しなかった場合も、保存済みrunの終了週を古い順にbounded catch-upし、途中の実順位を失わない。
- local-onlyのペアquestと週次leagueは同じeventを二重計上しない。先に開始した仕組みへだけ
  eventを紐付け、もう片方の開始操作は理由を表示して無効にする。
- 成人onlineでは、同じmeaningful eventがFriendsの共同状態とLeagueの固定10 XPをそれぞれ更新できる。
  Friends応答はXP 0で、個人wallet XPは追加・二重付与しない。Friends報酬はroom共同完了の固定1結晶だけ。
- 公開Internet、学校local-only、成人local-onlyからLAN clientを構成しない。socialの通信失敗で
  Path、復習、streak、学習eventを巻き戻さない。

## UIシステム

Duolingoの商標・キャラクター・画面を複製せず、理科版 `Orbit Lab` とする。

- canvas `#F7F9FF` / ink `#17223A`
- path `#2457D6` / complete `#167344` / review `#006D71`
- story `#7046C8` / legendary `#F2B705` + dark ink
- gradient・glass・常時浮遊・粒子の連続再生は使わない
- ノードは72dp、押下100ms、完了演出だけ最大500ms
- 保存成功後の完了面は、笑顔のデキすぎ君、実際に付与したXP / 結晶、この画面だけの経過時間、
  「次の一歩をマップで見る」を一つの主CTAとして返す。回答を採点していない課題に正答率を作らない
- デキすぎ君は、AIのアンテナ、教わる立場を示す開いた本、非対称の腕と目線を共通輪郭とする。
  Path / Live / Hub / activityで別のキャラクターにせず、待機・手招き・聞く・考える・応援・説明・祝福・
  時間切れ・再挑戦の9反応を形とSemanticsの両方で分ける。音素タイミングが無いのに口パクを作らず、
  listening / speakingはヘッドホン・音の形、timeUp / retryは時計・再挑戦記号で静止時も識別できるようにする
- activityのキャラクターはaccent色の上へ直接置かず、solid surfaceと境界を持つ52dp領域へ置く。
  light / darkの代表accentすべてで輪郭と背景を3:1以上に保ち、activity iconは非重複の20dp領域に分ける
- 装備中のstandard / orbit / novaは6タブ、activity、保存成功後の祝福面まで同じ見た目を引き継ぎ、
  Speakingの「聞いています」はマイクが実際にrecording中のときだけ告知する
- Lesson / Diagram / Story / Listening / Speaking / Boss / Legendary / Notation / Timed系は
  同じGamePalette / GameTokensと共通activity HUDを使う。共通HUDは戻る・連続学習・結晶・heartを含む唯一の上top chromeとし、
  戻り先を決めつけず「前の画面へ戻る」と正しく読み上げ、Semanticsのactivate actionを持たせる。
  子activityのAppBarと二重にしない。画面ごとの`AppColors`や`ColorScheme`への
  逆戻りを許さず、320dp・文字200%と700dp以上の双方で本文を最後まで読めるようにする
- StoriesとNotationのHeroは装飾にしない。実在するin-progress / review-due / availableの優先1件から文言、reaction、
  単一の主CTAを同時に導出し、全完了でだけ祝福する。Local Leagueのembedded表示は外側HeroとルールCTAを正本にし、
  同じ見出しや操作を二重表示しない
- Heroと完了面は見出し・本文の要約を1回だけ読み上げ、マスコット状態、指標、補足、設定、CTAは独立した子nodeで保つ
- 320dp/文字200%ではpopupをanchor overlayではなくscrollable sheetへ切替
- locked/completed/review/legendaryは色だけでなく形、icon、文言を併記
- 700dp以上では本文を720dp以下に抑え、一覧は情報階層を変えず3列まで広げる
- 6タブrouteと各ハブの末尾到達を、320×568・文字200%・light/dark・Reduce Motion・Semanticsで自動検証する

Pathの蛇行位置は7行反復 `[-0.05, 0.72, 0.34, -0.38, -0.72, -0.18, 0.54]`。未来connectorは
dashed、完了済みはsolid。Unit bannerは固定高にせず、単元・目標・進捗を表示する。現在ノードは
外周リングと「次はここ」を併記し、深い進捗からのcold launchでも自動的に可視範囲へ寄せる。

## 学習上の不変条件

1. 23概念すべてにLearn/Diagram/Story/Listen/Speak/Bossがある。
2. A/B/Cの3variantを各章で必ず使う。
3. Repair Hubに出すのはcatalogへ一意対応できるcanonical active needだけ。期限復習はPersonalized
   Practice、中断runはResumeへ分離する。Timedは任意で、いずれも次章解放を止めない。
4. Storyの全分岐は有限で、観察・訂正へ合流する。
5. Speakは教材と正解を隠したまま、stageごとの問いに音声または文字で説明する。音声はRAM内で
   録音し、実際に最後まで再生した後だけ次へ進む。文字は本人が明示的に読み返す。自由説明の
   長さ、意味類似、confidenceを正誤判定や進行条件に使わない。
6. その説明後にcatalog固定checkpointを1問だけ問い返す。正解ならcanonical needの
   `demonstrated`、誤答なら同needの`observed`とheart 1個だけを通知し、正解を先出しせず
   ヒントを使った再録音／再入力と再生／再読を必須にする。録音、自由文、ASR候補、選択肢ID、
   反応時間は保存・送信しない。権限拒否・端末音声失敗時は訂正状態を保ったまま文字へ退避する。
7. Bossは全問回答後まで正解・hintを開示しない。
8. Unit Legendaryはunit内の全Boss後、最後のBoss完了日より後かつ期限到来後。
   「習得」ではなく「高難度課題クリア」と表示し、次の期限が来たら再挑戦状態へ戻す。
9. Timedの時間切れでstreak・Path・学校提出・通常Heartsを失わせない。
10. 電気実験はteacherRequiredと安全文を必須にし、家庭用コンセントを扱わない。
11. 固定誤答は回答そのものではなくcatalogのneedCodeだけを保存し、対応する構造課題を
    成功したときだけ解消する。Matchもcatalog variantのcanonical needだけを通知し、選択した
    target IDや誤答本文を保存しない。自由記述・音声はneed判定に使わない。
12. Listeningは音声を最後まで聞いた後だけprivate文字起こしを入力し、教材の固定文との差を確認して
    条件を判断する。同梱人音声がある場合はそれを優先し、無ければ端末TTSと出所を明示する。Speakingは
    正解非表示の説明→実再生／明示再読→固定問い返し→必要なら訂正→自己比較を通す。日次カードは
    同一4時学習日の実eventから個別に完了表示する。
13. Story一覧の事件名は各Sectionの固定Story正本から公開し、概念labelから汎用生成しない。
    一覧・詳細・同梱assetの事件名を一致させ、選択・回答・再生履歴は保存しない。
14. Notationの正答提出後はcatalog固定strokeをpointerで順になぞるまで完了にしない。
    軌跡はWidget State内だけに置き、保存・送信せず、screen readerでは同じstroke順を確認する。

## 完成判定の残り

自動検証はFlutter全テスト / analyze、server typecheck / test / catalog check、Memory / SQLiteの
同一contract、6タブroute、320×568・文字200%・light/dark・Reduce Motion・Semantics、
700dp以上の可読幅とgridを対象にする。iOS Simulatorのbuild / launchと画面確認は行うが、
Simulatorを実マイク録音・再生、権限ダイアログ、TTSの実機証拠には数えない。

完成宣言の前に残る人間・物理環境のgateは、Android / iOS物理端末でのマイク許可／拒否・
録音の実再生・TTS中断と最新6タブの目視、Friends 2台、League 5台相当の実機LAN、初見学習者による
5〜10分pilotである。Store提出はこれらを通した後の別工程とする。

ローカルでgreenでも、必要な新規production / test / asset / workflowがGit未追跡なら配布成果物には
含まれない。意図した全ファイルをレビューして追跡し、clean checkoutのCI、署名付きbuild、実機gateを
通すまではproduction completeと呼ばない。

## 参考にする製品判断

Duolingoの現行Pathで有効なのは装飾ではなく、概念の順序・間隔復習・Story・Practiceを
同じ一本道へ統合したことにある。questはPathを進める行為と一致させる。XPだけを
目的にした反復が学習を歪めるため、デキすぎ君では上記のevent規則で封じる。
