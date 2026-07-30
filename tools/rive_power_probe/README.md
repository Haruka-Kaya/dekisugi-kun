# rive_power_probe

`flutter-app-ui-2026.md` 第9部の**未回答6「Rive の常時アニメーションが電池に与える影響の実数値」**を
実機で測るためのプローブ。

一次ソースが存在しない領域（Rive 単体の消費を切り出した数値を誰も公開していない）なので、自分で測る。

## 何を測るか

3条件を**1条件＝1プロセス**で走らせ、外から adb で計測する。
状態の持ち越しを避けるため、条件はビルド時に `--dart-define` で固定する。

| 条件 | 中身 | 差分が意味するもの |
|---|---|---|
| `running` | Rive を再生し続ける（`TickerMode: true`） | — |
| `frozen` | Rive を描画するがティッカーを止める（`TickerMode: false`） | `running − frozen` = **再生（アニメーション進行）のコスト** |
| `static` | Rive を一切生成しない。同じ面積の矩形だけ | `frozen − static` = **Rive を載せているだけのコスト** |

3条件とも**描画面積を 320×320 に揃えてある**。面積が変われば GPU 負荷の比較にならない。

## 端末の準備

> [!warning] Xiaomi / MIUI は既定で USB 経由のインストールを拒否する
> `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user` が出たら、端末側で
> **設定 → 追加設定 → 開発者向けオプション → 「USB経由でインストール」を ON**。
> adb からは解除できない（それが目的の制限のため）。Mi アカウントへのログインを求められることがある。

測定の前に条件を揃える。**これを飛ばすと Rive の差分より変動要因の方が大きくなる。**

- **バッテリー 50% 以上**、端末が室温近くまで冷えていること
  （低残量ではサーマルスロットリングと省電力モードが支配的になる）
- **他のアプリが動いていない**こと（通話・音楽・同期は最悪条件）
- 明るさを固定し、自動明るさを OFF
- スリープを長くする

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

& $adb shell settings put system screen_brightness_mode 0   # 自動明るさ OFF
& $adb shell settings put system screen_brightness 128      # 明るさ固定
& $adb shell settings put system screen_off_timeout 1800000 # スリープ 30分
& $adb shell dumpsys battery | Select-String "level|temperature|powered"
```

## 測定

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$PKG = "jp.dekisugi.rive_power_probe"
New-Item -ItemType Directory -Force measurements | Out-Null

foreach ($mode in @("running","frozen","static")) {
  flutter build apk --release --dart-define=PROBE_MODE=$mode
  & $adb install -r build\app\outputs\flutter-apk\app-release.apk

  # 充電中は batterystats が積算されないので、擬似的に「外した」状態にする
  & $adb shell dumpsys battery unplug
  & $adb shell dumpsys batterystats --reset

  & $adb shell am force-stop $PKG
  & $adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
  Start-Sleep -Seconds 30          # 起動直後の揺れが収まるまで待つ
  & $adb shell dumpsys gfxinfo $PKG reset

  Start-Sleep -Seconds 600         # 本計測 10分

  & $adb shell dumpsys gfxinfo $PKG    | Out-File "measurements\gfx_$mode.txt"
  & $adb shell dumpsys batterystats $PKG | Out-File "measurements\batt_$mode.txt"
  & $adb shell "cat /proc/`$(pidof $PKG)/stat" | Out-File "measurements\cpu_$mode.txt"
}
```

> [!warning] 終わったら必ず戻す
> `dumpsys battery unplug` は端末を「充電されていない」と思い込ませたままにする。
> 再起動するまで解除されないので、測定後に必ず実行すること。
> ```powershell
> & $adb shell dumpsys battery reset
> & $adb shell settings put system screen_brightness_mode 1
> ```

## 読み方

- **CPU**: `/proc/<pid>/stat` の 14番目(utime) と 15番目(stime) の合計。単位は clock tick（通常 100Hz）。
  条件間の差をそのまま比較できる。**いちばん再現性が高い指標**
- **フレーム**: `dumpsys gfxinfo` の `Janky frames` の割合と 50th/90th/95th/99th パーセンタイル
- **電池**: `dumpsys batterystats` の当該 uid の推定消費 mAh。
  **10分程度ではノイズが大きい**ので、CPU を主指標にして電池は補助として読む

## 既に分かっていること

- **APK は release で 61.4 MB**（`rive_native` が全 ABI のネイティブライブラリを積むため）。
  `--split-per-abi` でどこまで落ちるかは未測定
- `rive` 0.14.10 / `rive_native` 0.1.10。初回ビルド時にネイティブ成果物をダウンロードする
- 使用アセットは Rive 公式サンプルの `little_machine.riv`（17,522 バイト）
- 測定に使う Flutter は 3.41.9（doc の日本語組版の実測値と同じ版）

## 限界

- **測定に使う端末は1台**。機種が変われば数値は変わる。特に GPU とサーマル特性の影響が大きい
- Xiaomi rodin_global / Android 16 / SDK 36 は**新しめの端末**で、
  中高生が実際に持っている旧型端末の代表にはならない
- `dumpsys batterystats` の mAh は OS の推定値であって実測ではない
- 画面が点いている限り、**消費の大半はディスプレイ**。Rive の差分はその上に乗る小さな差になる
