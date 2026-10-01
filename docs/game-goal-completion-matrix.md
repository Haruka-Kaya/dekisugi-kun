# ゲーム全面刷新 — 完成条件と現在証拠

更新日: 2026-10-01

この表は「それらしい画面がある」ではなく、production導線・保存契約・E2E・実機表示の4点で完成を判定する。
安全上の代替や縮小実装は、元の要求と同等でない限り完成に数えない。

画面表示はField Notebook語彙を正本にする。本文中に現れるLearning Path / Path / Story / Stories /
Listening / Speaking / Notation / Practice / Resume / Repair / Quest / Friends / League / Legendary /
XP / Heart / Streak / Streak Freeze / Matchはすべて、既存ID・enum・保存済みeventを読むためだけの
内部互換名であり、画面表示には使わない。

| 明示要件 | 現在状態 | 完成を証明する一次証拠 | 残作業 |
|---|---|---|---|
| 中学理科教材の広さ | 12単元35概念を実装済み | MEXT理科編を参照するcatalog schema v10、12単元35概念、105のfoundation / conditions / transfer variant、35固有Story、35×3のListening聞き取り／意味need、116 tagged notation task。server正本・公開JSON・同梱asset・Dart parserをexact keysで同期し、未知fieldをfail-closed | 化学変化、イオン、生命の連続性、科学技術・自然環境まで収録。教員による学年配置・用語・安全性pilotが必要 |
| 探究ノート（内部Learning Path） | 実装済み | `GamePathProjection`と保存IDは維持し、表示を左の実験レール＋横長の探究ログへ変更。円形マス・蛇行connector・疑似立体rim・押下translationを廃止し、状態別の罫線・icon・文言、角形markerと「次はここ」、深い進捗のcold launch自動可視化、Home journey E2Eを保持 | 最新Field Notebook画面をAndroid / iOS物理端末で最終目視する |
| 理科事件＋読み聞かせ（内部Stories） | 実装済み（実機音声QA待ち） | schema v10の35固有episode、一覧の固有事件名、固定人物・公開順会話・3選択肢別反応・科学的解決・落ち、可視sceneだけを読むWidget / MethodChannel contract＋Android / iOS native bridge実装 | Android / iOS実機で声質と中断を最終確認する |
| 日次聞き取り観察／教え返し（内部Listening / Speaking） | 実装済み（実機音声QA待ち） | 聞き取り観察は音声完了後だけprivate文字起こし→教材文比較→意味判断へ進み、schema v10で35concept×3stageの聞き取りneedと意味needを別code化。同梱人音声と端末TTS fallbackを出所表示し、再生不能では完了・rewardを作らない。教え返しは正解非表示のstage別単一promptへ音声または文字で説明し、音声は実feed/drain完了まで再生、文字は明示再読後に固定問い返しへ進む。誤答はcanonical need＋試行余力1回だけを保存し、ヒント後の言い直しと再生／再読を必須にする。録音・自由文・選択肢IDはRAM外へ出さないHome E2E | 現catalogには人音声assetが無いため聞き取り観察はTTS fallback。Android / iOS物理端末でマイク許可／拒否、録音の実再生、TTS / 将来の人音声中断を最終確認する |
| 理科の文字学習相当（式・単位・矢印・グラフ） | 実装済み | catalog schema v10、物理のstrokeに加えて分類・順序・モデル・グラフを表すtagged notation task、pointer順序・距離・lift判定、screen reader順序確認、対応する修復実験のE2E | なし |
| 連続観測（内部Streak） | 実装済み | 4時学習日投影、meaningful event限定、利用可能な保護は学習前から1日の欠けを仮保護し、未保護の欠けだけ1日ごと7日減衰。長期離脱→0の回帰 | 物理端末で午前4時境界を確認 |
| 観測記録の保護（内部Streak Freeze） | 実装済み | Memory / SQLite共通contract、週1自動利用、結晶補充、同週／週跨ぎ／03:59→04:00のpure projection。完了前に減衰して完了後に突然復活せず、保護日は継続を維持するが学習日数には加算しない | 物理端末で午前4時境界を確認 |
| 実参加者との共同観測（内部League） | 実装済み（複数実機QA待ち） | onlineは自己署名TLS＋証明書pinのLAN coordinatorと5〜8個の独立credentialによる匿名順位。room削除前に104週・最大4096件の最小terminal receiptへ確定し、offline端末はMemory / SQLite保存成功→membership削除の順でexact-once回収する。local-onlyは同じ端末を手渡す実在2〜8枠を使い、保存済み終了run週を古い順・最大104週/passでcatch-upし、5〜8人の週だけslot 1の実順位から内部10段tierを最大±1段で原子的・冪等確定する。表示は「観測級01〜10」とし、空週と5人未満は履歴を捏造せず、旧4段XP tier・架空相手を主表示しない。client / server / store / Home E2E | onlineは5台相当の実機LAN参加・再接続・週終了、local-onlyは実在5〜8人の端末手渡し・週跨ぎを最終確認する |
| 今日／今月／共同の観察予定（内部Quest） | 実装済み | personal dailyは到達可能な探究ノート / 事件 / 聞き取り / 教え返し / 図解 / Notation / 転移 / 期限復習の8種から4時学習日ごとにmeaningful 1件を決定論的に選び、進捗0のcanonical definitionを表示前にmaterializeして同日固定する。各CTAは対応する実activityを直接開く。候補0ではdailyを捏造せず月間記録と再観察日待ちを表示して探究ノートを維持。school dailyは1件・報酬0、personal monthlyは12件・8結晶。Memory / SQLite再起動、同日候補変化、8 CTA、月間badge一意解放のplanner / store / Home E2E | なし |
| ふたりの共同観察（内部Friends Quest） | 実装済み（onlineの複数実機LAN QA待ち） | onlineは成人同意後の2人LAN room、共同状態だけを返すAPI、共同完了1結晶のroom単位冪等付与、退出失敗・再起動・復旧E2E。local-onlyは同じ端末の実在2枠を共通の観察予定へ0/2→1/2→2/2で投影し、CTAを研究室へ分岐、氏名・友達graphを保存せず3結晶を冪等付与 | onlineを2台の実機LANで参加・共同完了・退出再試行する |
| 結晶／観察装備／時間観察券 | 実装済み | 固定catalog、v12冪等spend、残高非負、探究ノートのマスコット購入・装備、時間観察の日次券、Memory / SQLite共通contract・migration・再起動・Home E2E | なし（学校scopeは経済無効、実課金・進行・正答購入なし） |
| 誤答で減る試行余力、0で停止、時間／回復実験 | 実装済み | 個人全固定課題のloss DTO、v11冪等台帳、30分/1回復、専用回復実験、保存fail-first再試行、route内retry前の残数再確認、高難度検証系の初回誤答即終了、Homeの320×568・文200% E2E、SQLite再起動 | なし（学校は無制限・非遮断） |
| 単元末の高難度検証（内部Unit Legendary） | 実装済み | `path:v2:<unit>:unit:legendary`、翌学習日解放、旧履歴互換、Home E2E | なし |
| 時間観察／対応づけ実験／連続観察 | 実装済み | 3つの別screen・別route、monotonic deadlineとbackground復帰時の時間切れ照合、時間切れ時は試行余力 / 探究記録 / progressの更新0。時間観察の確認→日次1回消費→同日再入場、学校無消費、対応づけ実験 / 連続観察無料のHome E2E | なし |
| 個別再観察（内部Personalized Practice） | 実装済み | 期限復習、中断再開（内部Resume）、修復実験（内部Repair）を別の事実から投影。修復実験の入口はcatalogへ一意対応できるcanonical active needだけで、中断runは中断再開だけに出す。対応づけ実験（内部Match）の誤答は選択肢IDでなく同じcatalog needだけを保存し、対応する修復実験の成功でのみ解消するplanner / projection / Home E2E | なし |
| 独自Field Notebook UI | 実装済み・自動QA完了（物理実機目視待ち） | warm paper / ink / mineral色、低角丸、solid面と4px分類罫線を共通GameTokensへ実装。6領域は「探究／事件／実験／図解／共同／研究室」、上部はbolt・diamond・heart・trophy列でなく「観測日／結晶／試行／予定」の研究計器、Pathは実験レール＋探究ログ、Hero / activityはLab Brief、保存成功後は放射・紙吹雪なしの観察記録票へ変更する。全activity routeは`GameActivityScaffold`の単一top chromeを維持し、誤答保存後の試行余力を即時反映する。デキすぎ君の9 reaction、Orbit / Nova装備、録音中だけの告知、light/dark代表accent上3:1、Stories / Notationの実進捗CTA、Local共同観測の重複除去、要約一意性、測っていない正答率を作らない契約は維持する。phone / wideの6面light-dark Golden、320×568・文字200%・Reduce Motion、Semanticsを自動検証。Android / iOSのicon・launch・themed icon・dark launchも同じruntimeキャラクター正本から決定的に生成する | 最新Field NotebookのAndroid / iOS物理端末目視、初見学習者5〜10分pilot |

## 理科事件／図解実験（内部Stories / Notation）の完成境界

- Storiesは各conceptに1本の固定episodeをcatalog正本として持つ。題名、固定登場人物、会話、観察前の選択、誤答時の人物別反応、科学的な解決、短い落ちを必須にし、汎用promptの差し替えだけでは完成に数えない
- 読み上げへ渡せるのは、そのsceneで既に画面へ公開した会話だけ。正答・理由・後続sceneは遷移前にTTSへ渡さず、scene遷移、Back、background、disposeで停止する
- Storyの誤答は固定need codeとheart lossだけを通知し、選択肢ID、会話の再生履歴、回答本文は保存しない。総当たりで先へ進めない
- Notationの「なぞる」は、catalogに固定した正規化strokeを実際のpointerで順に通る操作を指す。説明文、token並べ替え、完了ボタンだけをfinger tracingの代用にしない
- 指軌跡はWidget State内だけに置き、保存・送信・need DTOへ含めない。画面外、順序違い、離れすぎた軌跡は完了にせず、Reduce Motionとscreen reader向けには同じ意味を順序操作で確認できる代替を用意する
- catalogは未知field、欠落stroke、範囲外座標、短すぎるstroke、重複IDをfail-closedし、server正本と同梱assetの一致を機械検証する
- 実装証拠は、35件の固有title/setting/punchline fixture、一覧・詳細・assetのtitle一致、116件のtagged notation invariant、全分岐/TTS停止/pointer/a11y/320×568・文字200% widget testで固定する

## 教え返し／個別再観察／観察予定（内部Speaking / Practice / Quest）の完成境界

- Speakingはcatalog schema v10のstage別promptと固定checkpointを正本にする。自由説明は採点せず、音声と文字を同格に扱う。最初の説明中は目標語句、期待結果、理由、正答、他stageのpromptをWidget/Semanticsの双方で先出ししない
- 声の経路はPCMをRAMだけに保持し、nativeへ実際にfeedして自然drainしたときだけ「聞き返した」とする。途中停止、権限拒否、native例外、background、route破棄を完了扱いにしない。固定問い返しの誤答では選び直しを許さず、canonical needと試行余力を一度だけ通知して、同じ方法の言い直しと再生／再読を必須にする。権限拒否・端末失敗時だけ訂正状態のまま文字へ退避する
- 修復実験Hub（内部Repair Hub）に出すのは同じscopeのcatalog対応済みactive needだけ。期限再観察は個別再観察（内部Personalized Practice）、中断runは中断再開（内部Resume）へ分離し、未知・競合needを推測して課題へ結び付けない。対応づけ実験（内部Match）はcatalog variantのcanonical needを使い、誤答本文やtarget IDを保存せず、同じneedに対応する修復実験の成功だけで解消する
- personal daily questは到達可能な8種類から4時学習日ordinalで1種類を決定論的に選び、表示前にprogress 0でmaterializeして同日definitionを途中変更しない。meaningful event 1件で進み1結晶、候補0ではdailyを作らない。school dailyは1件・無報酬、personal monthlyは同じ台帳の12件で8結晶と固定badgeを付与する

## 全体gate

- 自動: Flutter 1337/1337・analyze 0、server 399/399・typecheck・catalog check・依存脆弱性0、Memory / SQLite同一contract
- visual/native: production widgetのField Notebook Golden 6/6、runtimeキャラクター正本Golden 4/4、派生native/store PNG 49件の2回byte一致・寸法・alpha・adaptive 66dp safe-zone・参照を検証
- 自動UI: 6タブroute、320×568・文字200%・light/dark・Reduce Motion・Semantics、700dp以上の可読幅とgrid
- build: Android release APKはupload key `CN=Haruka Kaya`のv2署名・zipalignを検証済み（統合後のARM64 APKハッシュは検証記録を参照）。iOS Simulator debug buildも成功。APK内に現Field Notebook語彙があり、旧到達語「週次リーグ」「ペアクエスト」「TUTORIAL CLEAR」「30秒おためしミッション」が無いことも検査した。APKのローカル署名はPlay受理、iOS実機署名、Store公開の証拠には数えない
- Git成果物: 必要な新規production / test / asset / workflowを意図的に追跡し、clean checkout CIが通るまで未完
- Simulator: iOS build / launchと主要画面の目視。Simulatorは実マイク録音・再生、権限ダイアログ、TTSの実機証拠には数えない
- 未完の物理端末: Android / iOSのマイク許可／拒否、録音の実再生、TTS中断、最新6タブの最終目視
- 未完の複数端末: 共同観察（内部Friends）2台、共同観測（内部League）5台相当の実機LAN参加・再接続・退出
- 未完の人間評価: 初見学習者による5〜10分pilot（所要時間、中断点、再挑戦率）
