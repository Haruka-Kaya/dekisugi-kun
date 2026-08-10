# ゲーム全面刷新 — 完成条件と現在証拠

更新日: 2026-08-10

この表は「それらしい画面がある」ではなく、production導線・保存契約・E2E・実機表示の4点で完成を判定する。
安全上の代替や縮小実装は、元の要求と同等でない限り完成に数えない。

| 明示要件 | 現在状態 | 完成を証明する一次証拠 | 残作業 |
|---|---|---|---|
| すごろく型Learning Path | 実装済み | `GamePathProjection`、`PathScreen`、蛇行connector、状態別の形・icon・文言、外周リング付き「次はここ」、深い進捗のcold launch自動可視化、Home journey E2E、iPhone 17 Simulator実画面 | なし |
| Stories＋読み聞かせ | 実装済み（実機音声QA待ち） | schema v9の11固有episode、一覧の固有事件名、固定人物・公開順会話・3選択肢別反応・科学的解決・落ち、可視sceneだけを読むWidget / MethodChannel contract＋Android / iOS native bridge実装 | Android / iOS実機で声質と中断を最終確認する |
| 日次Listening / Speaking | 実装済み（実機音声QA待ち） | Listeningは音声完了後だけprivate文字起こし→教材文比較→意味判断へ進み、schema v9で11concept×3stageの聞き取りneedと意味needを別code化。同梱人音声と端末TTS fallbackを出所表示し、再生不能では完了・rewardを作らない。Speakingはschema v9の`localSpeakingPractice`、Android `createOnDeviceSpeechRecognizer` / iOS `requiresOnDeviceRecognition`の端末内限定bridge、認識候補の正規化後完全一致gate、目標文そのものだけを受理する文字代替。別mission planner・別screen・同日完了投影・Home E2E | 現catalogには人音声assetが無いためTTS fallback。Android / iOS実機で端末内ASR、マイク拒否、TTS / 将来の人音声中断を最終確認する |
| 理科の文字学習相当（式・単位・矢印・グラフ） | 実装済み | catalog schema v9、22固定trace、pointer順序・距離・lift判定、screen reader順序確認、token・symbol・graph、exact Repair E2E | なし |
| Streak | 実装済み | 4時学習日投影、meaningful event限定、利用可能なfreezeは学習前から1日の欠けを仮保護し、未保護の欠けだけ1日ごと7日減衰。長期離脱→0の回帰 | 物理端末で午前4時境界を確認 |
| Streak Freeze | 実装済み | Memory / SQLite共通contract、週1自動利用、結晶補充、同週／週跨ぎ／03:59→04:00のpure projection。完了前に減衰して完了後に突然復活せず、freeze日は継続を維持するが学習日数には加算しない | 物理端末で午前4時境界を確認 |
| 他の学習者との週次League | 実装済み（複数実機QA待ち） | onlineは自己署名TLS＋証明書pinのLAN coordinatorと5〜8個の独立credentialによる匿名順位。room削除前に104週・最大4096件の最小terminal receiptへ確定し、offline端末はMemory / SQLite保存成功→membership削除の順でexact-once回収する。local-onlyは同じ端末を手渡す実在2〜8枠を使い、保存済み終了run週を古い順・最大104週/passでcatch-upし、5〜8人の週だけslot 1の実順位からBronze→Diamondを最大±1段で原子的・冪等確定する。空週と5人未満はtier履歴を捏造せず、旧4段XP tier・架空相手を主表示しない。client / server / store / Home E2E | onlineは5台相当の実機LAN参加・再接続・週終了、local-onlyは実在5〜8人の端末手渡し・週跨ぎを最終確認する |
| Daily / Monthly Quest | 実装済み | personal dailyは到達可能なPath / Story / Listening / Speaking / Diagram / Notation / 転移 / 期限復習の8種から4時学習日ごとにmeaningful 1件を決定論的に選び、進捗0のcanonical definitionを表示前にmaterializeして同日固定する。各CTAは対応する実activityを直接開く。候補0ではdailyを捏造せず月間記録と復習日待ちを表示してPathを維持。school dailyは1件・報酬0、personal monthlyは12件・8結晶。Memory / SQLite再起動、同日候補変化、8 CTA、月間badge一意解放のplanner / store / Home E2E | なし |
| Friends Quest | 実装済み（onlineの複数実機LAN QA待ち） | onlineは成人同意後の2人LAN room、共同状態だけを返すAPI、共同完了1結晶のroom単位冪等付与、退出失敗・再起動・復旧E2E。local-onlyは同じ端末の実在2枠を共通Quest sheetへ0/2→1/2→2/2で投影し、CTAをProfileへ分岐、氏名・友達graphを保存せず3結晶を冪等付与 | onlineを2台の実機LANで参加・共同完了・退出再試行する |
| Gems / items / challenge fee | 実装済み | 固定catalog、v12冪等spend、残高非負、Path mascot購入・装備、Timed日次券、Memory / SQLite共通contract・migration・再起動・Home E2E | なし（学校scopeは経済無効、実課金・進行・正答購入なし） |
| 誤答で減るHearts、0で停止、時間／回復練習 | 実装済み | 個人全固定課題のloss DTO、v11冪等台帳、30分/1回復、専用回復practice、保存fail-first再試行、route内retry前の残数再確認、Legendary系の初回誤答即終了、Homeの320×568・文200% E2E、SQLite再起動 | なし（学校は無制限・非遮断） |
| Unit末Legendary | 実装済み | `path:v2:<unit>:unit:legendary`、翌学習日解放、旧履歴互換、Home E2E | なし |
| Timed / Match / Lightning | 実装済み | 3つの別screen・別route、monotonic deadlineとbackground復帰時の時間切れ照合、時間切れ時はheart / XP / progressの更新0。Timed確認→日次1回消費→同日再入場、学校無消費、Match / Lightning無料のHome E2E | なし |
| Personalized Practice | 実装済み | 期限復習、Resume、Repairを別の事実から投影。Repair入口はcatalogへ一意対応できるcanonical active needだけで、中断runはResumeだけに出す。Match誤答は選択肢IDでなく同じcatalog needだけを保存し、対応するexact Repair成功でのみ解消するplanner / projection / Home E2E | なし |
| 画像方向の全面UI | 実装済み・自動QA済み（物理実機目視待ち） | 6タブshellと共通GameTokens。連続学習・結晶・heart・quest入口はタブpageの外に固定し、全activity routeも共通`GameActivityScaffold`で戻る／連続／結晶／heart HUDを保持する。誤答保存後のheartを開いた画面へ反映し、デキすぎ君は開始・思考・訂正・完了でSemanticsを含むreactionを変える。Story / Speaking / Bossを含む理科activityはGamePaletteへ統一。保存成功後だけ笑顔・500ms以下の祝福・実XP / 結晶 / 非保存の今回時間・「次の一歩」CTAを表示し、測っていない正答率を作らない。320×568・文字200%・light/dark・Reduce Motion、700dp以上、Semantics、6タブ／代表activity routeをwidget testで固定し、Android 16 emulatorでPathと実Lessonの固定HUD・overflowなしを目視 | 最新6タブ・代表activity・祝福面をAndroid / iOS物理端末で最終目視し、初見学習者5〜10分pilotを行う |

## Stories / Notation の完成境界

- Storiesは各conceptに1本の固定episodeをcatalog正本として持つ。題名、固定登場人物、会話、観察前の選択、誤答時の人物別反応、科学的な解決、短い落ちを必須にし、汎用promptの差し替えだけでは完成に数えない
- 読み上げへ渡せるのは、そのsceneで既に画面へ公開した会話だけ。正答・理由・後続sceneは遷移前にTTSへ渡さず、scene遷移、Back、background、disposeで停止する
- Storyの誤答は固定need codeとheart lossだけを通知し、選択肢ID、会話の再生履歴、回答本文は保存しない。総当たりで先へ進めない
- Notationの「なぞる」は、catalogに固定した正規化strokeを実際のpointerで順に通る操作を指す。説明文、token並べ替え、完了ボタンだけをfinger tracingの代用にしない
- 指軌跡はWidget State内だけに置き、保存・送信・need DTOへ含めない。画面外、順序違い、離れすぎた軌跡は完了にせず、Reduce Motionとscreen reader向けには同じ意味を順序操作で確認できる代替を用意する
- catalogは未知field、欠落stroke、範囲外座標、短すぎるstroke、重複IDをfail-closedし、server正本と同梱assetの一致を機械検証する
- 実装証拠は、11件の固有title/setting/punchline fixture、一覧・詳細・assetのtitle一致、22件のtrace invariant、全分岐/TTS停止/pointer/a11y/320×568・文字200% widget testで固定する

## Speaking / Practice / Quest の完成境界

- Speakingはcatalog schema v9の`targetPhrase`と明示した表記揺れだけを正本にする。Android / iOSともオンデバイス認識を強制し、通常・cloud recognizerへfallbackしない。候補はRAM内の完全一致判定にだけ使い、画面、LearningEvent、Store、networkへ出さない
- 声の経路は無音・無関係な発話・認識失敗で先へ進めず、正規化後に正本と完全一致した場合だけ発音gateを通す。端末内認識が使えない場合の文字代替も`targetPhrase`そのものだけを受理し、完了画面に「発音は未確認です」と表示するため、文字一致を発音確認の証拠にしない
- Repair Hubに出すのは同じscopeのcatalog対応済みactive needだけ。期限復習はPersonalized Practice、中断runはResumeへ分離し、未知・競合needを推測して課題へ結び付けない。Matchはcatalog variantのcanonical needを使い、誤答本文やtarget IDを保存せず、同じneedに対応する構造課題のexact Repair成功だけで解消する
- personal daily questは到達可能な8種類から4時学習日ordinalで1種類を決定論的に選び、表示前にprogress 0でmaterializeして同日definitionを途中変更しない。meaningful event 1件で進み1結晶、候補0ではdailyを作らない。school dailyは1件・無報酬、personal monthlyは同じ台帳の12件で8結晶と固定badgeを付与する

## 全体gate

- 自動: Flutter 1148/1148・analyze 0、server 351/351・typecheck・catalog check・依存脆弱性0、Memory / SQLite同一contract
- 自動UI: 6タブroute、320×568・文字200%・light/dark・Reduce Motion・Semantics、700dp以上の可読幅とgrid
- build: Android debug APKとiOS Simulator debug buildは成功。物理端末・配布署名の証拠には数えない
- Git成果物: 必要な新規production / test / asset / workflowを意図的に追跡し、clean checkout CIが通るまで未完
- Simulator: iOS build / launchと主要画面の目視。Simulatorは端末内ASR、マイク、TTSの実機証拠には数えない
- 未完の物理端末: Android / iOSの端末内ASR・マイク拒否・TTS中断、最新6タブの最終目視
- 未完の複数端末: Friends 2台、League 5台相当の実機LAN参加・再接続・退出
- 未完の人間評価: 初見学習者による5〜10分pilot（所要時間、中断点、再挑戦率）
