# クロス端末ソーシャル — LAN coordinator v1

最終確認: 2026-08-10

## 結論

週次リーグとフレンズクエストのクロス端末版は、Vercel / Upstashを使わず、
学校または家庭が管理するPC上のLAN coordinatorへ接続する。

- 状態はcoordinator PCの原子的JSONだけへ保存する。
- 通信は自己署名TLS + 証明書SHA-256 pinを必須にする。
- 参加コードは`endpoint + certificate pin + invite + kind`だけで、管理キーを含まない。
- 参加者はroomごとの不透明ID/credentialであり、端末IDやaccountを使わない。
- 氏名、学校名、回答、選択肢、音声、反応時間はAPI schema自体に存在しない。
- 5人未満のleagueは順位・他人のXP・実人数を返さない。
- friends questは実在2人の参加と共同完了だけを返し、個別得点を返さない。
- 認証済みfriends共同完了はroomごとに固定1結晶を個人台帳へ一度だけ付与する。
- room削除前に参加者ごとの最小terminal receiptを確定し、長期offline端末も再起動後に回収する。
- 既存のproduction guardとUpstash経路は変更しない。

coordinator自体は組織管理PCでも動かせるが、現行production UIは成人online同意経路だけを
対象にし、学校local-onlyと成人personal local-onlyからは接続しない。これは学校導入全体の
承認ではない。外部AI、MDM、学校ポリシー、授業運用のNO-GOは引き続き
[学校導入のリリース判定](school-readiness.md)に従う。

## 実利用可否の監査

| 論点 | 現在の証拠 | 判定 |
|---|---|---|
| アプリから部屋作成 | coordinator起動後、private HTTPS URL / fingerprint / 管理キーを入力してFriends 2人またはLeague 5〜8人のroomを作り、DKS1参加コードをコピーできる | **可能**。ただし3項目の管理者入力は残る |
| アプリから参加 | DKS1コード貼り付け、送信範囲の明示同意、参加、refresh、退出を同じ画面で行う | **可能**。QR生成・scanは未実装 |
| 実在人数 | serverは独立credentialだけをparticipantとし、Leagueは5未満を秘匿、Friendsは独立2 credentialの共同完了だけを返す | **自動テスト済み**。複数物理端末は未確認 |
| 再接続 | coordinatorのJSON/TLS identityと、アプリのroom別membership・退出保留を再起動後に復元する。期限後はroom削除前に作ったreceiptを104週保持し、端末保存成功後だけmembershipを削除する | **Memory / SQLite / 実Coordinator再起動を自動テスト済み**。Wi-Fi変更・OS killを含む実機確認は未実施 |
| 管理PCの前提 | source起動にはrepo + Node.js + npmが要る。SEA artifactの実行先にはrepo / Node.js / npm / OpenSSLが要らない | **packaging実装済み**。artifact公開と署名は未実施 |
| 対象年齢・学校境界 | cross-device入口は成人personal onlineだけ。18歳未満、学校、成人local-onlyは`lanSocialAllowed=false` | **本来の中高生対象には未到達**。契約・同意レビューなしに解除しない |

したがって「成人onlineの管理されたLANで技術的に動く」と「中高生がproductionで使える」は別である。
後者はこの実装だけでは完成していない。

## 保存先の監査

| 案 | 判定 | 理由 |
|---|---|---|
| 既存Upstash Team | 不採用 | 16歳未満データの契約確認が未完了。production guardを解除しない |
| Vercel process memory | 不成立 | instanceをまたいで共有できず、cold startで消える |
| Vercel filesystem | 不成立 | 永続・共有保存ではなく、週次状態の正本にできない |
| mobile P2Pだけ | 今回不採用 | iOS/Android間のdiscovery、background、host交代、再接続を同時に満たさない |
| 管理PC LAN coordinator | 採用 | 外部処理者なし、常時host、端末間共有、ローカル削除が成立する |

coordinatorは`server/api/`配下に置かないため、Vercel Functionとしてdeployされない。
forwarded header、browser Origin、public remote address、public Hostを拒否し、reverse proxy経由で
公開しようとするとfail-closedになる。

## 通信と参加

```text
管理PC
  ├─ 初回のみRSA 3072自己署名証明書を生成
  ├─ HTTPS LAN APIを開始
  └─ ローカルJSONを原子的renameで保存

作成者端末
  ├─ 管理キーを明示入力してroom作成
  └─ endpoint + cert SHA-256 + invite + kind の参加コードをコピー

参加端末
  ├─ private/loopback IPのHTTPSだけ許可
  ├─ 参加コード内fingerprintとserver certificate DERのSHA-256を完全一致確認
  ├─ roomごとの乱数join keyで参加
  └─ salted event idempotency key + learning dayだけ送信
```

管理キーはroom作成専用で、参加コード、membership、league履歴へ保存しない。
自己署名証明書を一般に信頼せず、接続コードでpinした1枚だけを受け入れる。
証明書が期限外、pin不一致、証明書と秘密鍵の不一致なら接続・起動を止める。
保存directory・TLS identity・coordinator stateは、macOS / Linuxではowner一致と
directory `0700` / file `0600`を検証する。WindowsではPOSIX modeを代用せず、ACL継承を切り、
現在ユーザーSIDのFullControl ACEだけへ限定する。ACLの適用・再検証、owner、通常file / directory
種別のいずれかを確認できなければ起動を止める。

## 起動と配布

### 管理PC向け単一実行ファイル

`.github/workflows/lan-social-coordinator.yml`は、macOS arm64 / Windows x64 / Linux x64ごとに
[Node Single Executable Application](https://nodejs.org/api/single-executable-applications.html)
を作り、同じOS上でHTTPS healthと秘密非混入smokeを通してartifactへ保存する。
[GitHub公式runner](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)の
各OS・architecture上でbuildするため、cross compileした別OS binaryを完成証拠にしない。
Node SEAはmacOS x64を現在サポートしないため、Intel Mac向けSEAを生成・配布可能とは扱わない。
Intel Macでは下記のsource起動を使う。
macOS / Linuxは実行権限を保持する`tar.gz`、Windowsは`zip`とし、archive全体のSHA-256を
sidecarへ出す。実行時刻をarchive metadataへ混ぜず、連続buildでbinaryとarchive双方の
SHA-256一致を検査する。smokeは実際にarchiveを展開し、launcherとbinaryの実行権限も検査する。

artifact内の各launcherを起動する。

- macOS: `start-coordinator.command`
- Windows: `start-coordinator.cmd`
- Linux: `start-coordinator.sh`

実行先PCにはrepo checkout、Node.js、npm、OpenSSLをインストールしない。初回起動時だけ、
binary自身がNode WebCryptoでRSA 3072自己署名証明書、管理キー、空のroom状態を生成する。
これらはbuild時に作らず、binary、manifest、launcherへ含めない。smoke testは`PATH`を空にした
binaryを起動し、runtimeで生成した秘密鍵全文と管理キーがartifactのどのファイルにも存在しないことを
検査する。

SEA版の既定保存先は次の利用者データ領域である。`--data`指定時だけ別の絶対pathを使う。

- macOS: `~/Library/Application Support/Dekisugi/`
- Windows: `%LOCALAPPDATA%/Dekisugi/`
- Linux: `$XDG_STATE_HOME/dekisugi/`、未設定時は`~/.local/state/dekisugi/`

macOS artifactはSEA注入後にad-hoc署名してlocal smokeを成立させるが、Developer ID署名・notarize済み
ではない。Windowsもcode signing前である。現段階のartifactはpilot用であり、学校配布済み、
production配布可能とは扱わない。

### sourceから起動

開発時はNode.js 22以上と`npm ci`が必要だが、OpenSSL CLIは不要になった。

```bash
cd server
npm ci
npm run social:lan -- --host 0.0.0.0 --allow-lan
```

source起動の既定保存先は`server/.local-data/lan-social-v1.json`。TLS証明書と秘密鍵も同じ
`.local-data/`へ置き、Git対象外にする。loopbackだけで確認する場合は引数なしで起動できる。

### artifactを再生成・検証

buildはNode.js 26.5以上のSEA-enabled binaryを使う。現在のMacに入っているHomebrew Node 26.7.0は
`Single executable application is disabled`となるため、公式Nodeを
`DEKISUGI_SEA_NODE=/absolute/path/to/node`で明示できる。CIは`actions/setup-node`の26.7.0へ固定する。

```bash
cd server
npm ci
npm run test:social:lan
npm run social:binary
npm run social:binary:reproducible
npm run social:binary:smoke
```

生成物は`server/dist/dekisugi-lan-coordinator-<platform>-<arch>/`。manifestとSHA-256を同梱し、
`dist/`自体はGit管理しない。

terminalへ次を別々に表示する。

- LAN HTTPS URL
- 証明書SHA-256
- 管理キー

参加者へ渡す文字列には上2つとroom inviteだけを使い、管理キーは入れない。
現行v1のアプリ内導線はこの文字列のコピー／貼り付けであり、QRの生成・カメラ読み取りは実装していない。
外部でQR化する場合も符号化対象は同じ参加コード文字列だけとし、管理キーを混ぜない。

## API v1

すべて`Content-Type: application/json`、`Cache-Control: no-store`。未知欄を無視せず400にする。

| Method | Path | 認証 | 受け取る学習データ |
|---|---|---|---|
| GET | `/v1/lan-social/health` | なし | なし |
| POST | `/v1/lan-social/rooms` | coordinator key | kind / capacity / createKey / opt-in version |
| POST | `/v1/lan-social/join` | invite | room乱数joinKey / opt-in version |
| GET | `/v1/lan-social/snapshot` | opaque credential | なし |
| GET | `/v1/lan-social/settlement` | opaque credential | なし |
| POST | `/v1/lan-social/contribution` | opaque credential | salted idempotency key / learning day |
| POST | `/v1/lan-social/leave` | opaque credential | なし |

`createKey`、`joinKey`、contribution keyは再送を同一操作にするための不透明乱数。
保存時はHMACへ変換し、生値を残さない。membership credentialはroom単位で、別roomの参加者を
同一人物として結び付けられない。

coordinatorのwire protocolはv1のまま、保存stateだけをv2へ移行する。v1 stateは既存roomを
そのまま保ち、空の`settlements`を加えて原子的に書き戻す。roomは期限後7日で削除する直前に
各credential向けreceiptを生成し、receiptは期限から104週・最大4096件の有界台帳で保持する。保存物はHMAC receipt keyと
最小結果だけで、credential、participant ID、join hash、learning day、contributionを残さない。
同じreceipt keyの重複や未知欄を含むstateは起動時にfail-closedにする。

## 実参加者と少人数プライバシー

### Friends quest

- capacityは必ず2。
- 各participantの最初のmeaningful eventだけを数える。
- 返すのは`partner joined / my contributed / jointly completed`だけ。
- contribution応答の`xpAdded`は常に0。League用の固定XPをFriendsへ流用しない。
- jointly completedを確認した端末は`roomId`単位の専用冪等APIで固定1結晶を付与する。
  学習event、XP、streak、Pathは生成・変更せず、再join/refresh/再起動でも二重付与しない。
- XP、順位、相手のevent数、participant IDを返さない。
- 退出時はparticipantとそのcontributionを同時に削除する。
- clientは退出の204または「すでに無効」の401を確認した場合だけmembershipを削除する。
  timeout / 503では資格情報を保持して「退出保留・再試行」と表示し、server側のparticipantを
  期限まで孤立させない。保留印は端末へ保存し、その時点から学習寄与を止める。
  アプリ再起動後も同じcredentialでは退出だけを再試行する。

### Weekly league

- capacityは5〜8。2〜4人leagueは作れない。
- 5人未満では`under5`だけを返し、順位、他人のXP、実人数を返さない。
- 5人以上で初めて、名前も安定した公開IDもない匿名standingを実参加人数ぶんだけ返す。
- 1 meaningful eventをserver側で固定10 XPにする。端末申告の任意XPは受け取らない。
- 同一event再送は0 XP。1 participantあたり1日10 eventで打ち止め。
- 全員0の間はrankを`null`にし、学習していない架空順位を作らない。

現行の学校local-only契約は「学校serverへ接続しない・入力も学習記録も送らない」ため、
leagueだけでなくfriendsも学校モードから到達不可にする。成人personalでもlocal-only経路は
同じく到達不可である。`lanSocialAllowed`はdefault falseとし、成人onlineの送信同意ツリーから
明示的にtrueを渡した場合だけclientを構成する。将来学校へ提供する場合は、学校契約、同意文面、
privacy copyの別レビューが必要であり、この実装だけを根拠に有効化しない。

## 10段league ladder

実参加者のstandingと、本人だけの長期tierを分離する。tier/historyは端末内だけへ保存し、
coordinatorへ送らない。

```text
Bronze → Silver → Gold → Sapphire → Ruby → Emerald
       → Amethyst → Pearl → Obsidian → Diamond
```

- 週終了後、実参加者5〜8人のsnapshotだけを一度確定する。
- 単独1位かつXPありなら1段昇格。
- 単独最下位なら1段降格。
- 同率、全員0、5人未満、同じroomの再確定は据え置き/無処理。
- Bronzeより下、Diamondより上は作らない。
- 履歴はroom ID、週、本人XP、本人rank、実参加人数、前後tier、movementだけ。
- offline中にroom本体が削除されても、5人以上なら本人のXP/rank/tied/実参加人数だけのreceiptから
  同じ履歴を確定する。5人未満receiptは`under5`だけで、XP・rank・実人数を保存しない。
- clientは報酬/tier履歴を先に保存し、その成功後だけmembershipを削除する。途中失敗や再起動では
  同じreceiptを再取得し、room ID冪等性によって二重結晶・二重昇降格を防ぐ。

## abuse / rate / idempotency

- inviteは紛らわしい文字を除いた12文字。IPごとのjoin試行は15分8回。
- 全経路はIP 120回/分、room作成は20回/日、contributionはcredential 20回/時。
- rate limiterが壊れた・容量を判断できない場合は503で処理前に止める。
- room capacityを超えてparticipantを作らない。
- create/join/contributionを原子的に直列化し、応答消失後の再送を同じ結果にする。
- server時刻の午前4時区切りlearning day以外は寄与を拒否する。
- request bodyは2 KiBまで。unknown field、query、proxy、browser Originを拒否する。
- 改造clientが「実際に学習した」と偽ることを完全には証明できないため、fixed XPと日次上限で
  被害を有界化する。成績・習得証明には使わない。

## iOS / Android契約

### iOS

- `NSLocalNetworkUsageDescription`を設定済み。
- Bonjour discoveryは使わないため`NSBonjourServices`は追加しない。
- `NSAllowsArbitraryLoads`やHTTP例外は追加しない。HTTPS + app pinだけを使う。
- Local Network許可を拒否しても学習Pathは止めず、socialだけを利用不可にする。

### Android

- 既存の`INTERNET` permissionを使う。
- main manifestは`usesCleartextTraffic=false`を明示する。広いNetwork Security Configは追加しない。
- 自己署名証明書をOS全体へ信頼追加せず、このclientのfingerprint一致だけで受ける。

## Home UIへの接続契約

Home側は次のAPIだけを使い、既存の同一端末runと混ぜない。

1. 貼り付けた参加コード文字列を`LanSocialConnectionCode.parse`する。
2. データ項目と期限を表示し、明示opt-in後だけ`LanSocialClient.join`する。
3. `lanSocialAllowed == true`のときだけ、学習eventのcommit成功後、
   `meaningfulProgress == true`のrecordを`contributeMeaningfulEvent`へ渡す。
4. Friendsは共同状態、leagueは5人未満の待機状態または匿名standingを表示する。
5. `refresh`で期限後の10段tier/historyを一度だけ確定する。
   friends共同完了なら、同じ認証済みsnapshotを根拠に固定1結晶をroom単位で一度だけ付与する。
   snapshotが401/410ならterminal receiptを回収し、端末保存後に再参加画面へ戻す。
6. `schoolLocal`と成人personalのlocal-only経路では、friends/league双方の作成・参加・送信・表示を
   出さず、`LanSocialClient`も構成しない。
7. LAN/TLS/API失敗でPath、復習、streak、学校提出を止めない。
8. 成人onlineの「競う」タブでは、旧4段の端末内XP tier / historyを第二のleagueとして表示せず、
   実参加者5〜8人の匿名standingとBronze→Diamond 10段tierだけを主役にする。local-onlyでは旧tierを
   「通信しない端末内の代替」と明示し、schoolは無順位の授業表示を維持する。

現行v1の参加UIは接続コード文字列のコピー／貼り付けである。アプリ内QR生成・カメラscanは
将来の任意UIであり、現在の完成証拠には数えない。

実装正本:

- `server/lib/lan-social.ts`
- `server/lib/lan-social-http.ts`
- `server/lib/lan-social-tls.ts`
- `server/scripts/build-lan-social-binary.mjs`
- `.github/workflows/lan-social-coordinator.yml`
- `app/lib/models/lan_social.dart`
- `app/lib/services/lan_social_client.dart`
- `app/lib/screens/lan_social_screen.dart`

自動検証:

- `server/test/lan_social_http.test.ts`: 独立2 credentialのFriends共同完了、独立5 credentialの匿名League、実HTTPS terminal receipt再送
- `server/test/lan_social_tls.test.ts`: OpenSSLなしのRSA 3072生成、pin維持、鍵差替えfail-closed
- `npm run social:binary:reproducible`: 同じplatform / architecture / Node入力の連続buildと、別の一時source directoryからのbuildでSEA本体・配布archive双方のSHA-256一致
- `npm run social:binary:smoke`: SEAを`PATH`空で起動、HTTPS health、runtime秘密のartifact非混入
- `app/test/lan_social_client_test.dart`: 証明書pin、Friends 0 XP、退出503→再起動→204、10段tier、Memory/SQLite再起動receipt、保存/削除失敗exact-once
- `app/test/lan_social_reward_test.dart`: Friends共同完了1結晶のMemory / SQLite再起動冪等
- `app/test/lan_social_screen_test.dart`: 5人未満秘匿、実在5枠、退出保留と再試行、terminal receipt確定表示
- `app/test/league_screen_lan_social_test.dart`: 成人onlineで旧4段Leagueを混在させない
- `app/test/science_game_home_screen_test.dart`: meaningful event寄与と、social失敗時の学習commit分離

複数実機LANでの最終確認は未実施。Friends 2台、League 5台相当の参加・再接続・退出を
Store公開とは別の実機QA gateとして残す。
