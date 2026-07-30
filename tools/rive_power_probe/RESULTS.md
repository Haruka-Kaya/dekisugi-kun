# 実測結果 — Rive の常時アニメーションのコスト

- 測定日: 2026-07-31
- 端末: Xiaomi rodin_global (2412DPC0AG) / Android 16 (SDK 36) / arm64-v8a / 8コア / MediaTek
- Flutter 3.41.9 / rive 0.14.10 / rive_native 0.1.10 / アセット `little_machine.riv`（Rive公式サンプル、17,522バイト）
- 指標: `/proc/<pid>/stat` の utime+stime の**6分間の差分**。安定待ち30秒のあと計測
- CPU% は**1コア換算**（8コア機なので端末全体では約1/8）

## 結果

| 条件 | 120Hz | 60Hz |
|---|---|---|
| `running`（Rive を再生し続ける） | **91.4%**（初回 93.8%） | **76.1%** |
| `flutter_anim`（Rive なし・素の Flutter 連続アニメ） | **71.2%** | **42.8%** |
| `frozen`（`TickerMode(enabled: false)`） | **0.8%** | — |
| `static`（Rive を生成しない） | **0.0%** | — |

`flutter_anim` が描いているのは**円12個と矩形1個だけ**。描画内容は限りなく軽い。

## 分かったこと

### 1. 「Rive が重い」は誤り。連続アニメーション自体が重い

対照条件を入れるまで、`running` の 93.8% を見て「Rive が重い」と解釈しかけた。**間違いだった。**

```
120Hz:  Rive の上乗せ = 91.4 - 71.2 = 20.2 ポイント（全体の約1/4）
```

主犯は Rive ではなく、**毎フレーム パイプラインを回すこと自体**。
描画量ではない（対照条件は円12個しか描いていないのに 71.2%）。

> [!warning] 対照条件が無ければ誤った結論を出していた
> `running` / `frozen` / `static` の3条件だけでは「Rive vs 何もしない」しか比べられず、
> 「連続アニメーション一般のコスト」と「Rive 固有のコスト」を分離できない。

### 2. 止めるのは本当に効く

**`TickerMode(enabled: false)` で 91.4% → 0.8%。** これが唯一よく効く手段。

→ キャラが画面外・非アクティブ・バックグラウンドのときに止める実装は**必須**。
Rive 公式サンプル `ticker_mode.dart` がそのまま使える。

### 3. fps を下げても Rive にはあまり効かない

| | 120Hz → 60Hz |
|---|---|
| `flutter_anim` | 71.2% → 42.8%（**−40%**） |
| `running`（Rive） | 91.4% → 76.1%（**−17%**） |

2点から線形近似すると:

| | フレーム依存 | フレームに依存しない固定分 |
|---|---|---|
| `flutter_anim` | 約 0.47 %/fps | 約 **14%** |
| `running`（Rive） | 約 0.26 %/fps | 約 **61%** |

**Rive はフレームレートに比例しない ~61% を持っている。**
時間ベースで進む処理を内部で回している可能性が高い。

→ **「キャラは30fpsで十分」という最適化は Rive には効きにくい。** 止めるしかない。

## 設計への落とし込み

- ✅ **非アクティブ時は `TickerMode` で止める**（実測で 0.8% まで落ちる）
- ✅ **キャラを常時アニメーションさせない。** 待機中は静止画＋たまに動く、が現実的
- ❌ Rive をやめて自前アニメにする → **意味がない**（素の Flutter でも 42.8%@60Hz）
- ⚠️ fps を落とす最適化は Flutter 側のアニメには効くが、Rive には効きにくい

## 未検証（推測で埋めないこと）

1. **`Factory.flutter` と `Factory.rive` の比較** — 本測定は `Factory.rive`（Rive Renderer）のみ。
   レンダラを変えると数値が変わる可能性がある。**次に測るならここ**
2. **アセット依存** — `little_machine.riv` は機能を見せるための公式デモで、実プロダクトのキャラより重い可能性
3. **端末1台・各条件1回** — 機種の GPU とサーマル特性で変わる。低スペック端末では未測定
4. **電池の実消費** — USB給電中かつ `dumpsys battery unplug` 中は level/temperature が凍結されるため取れていない

## 測定手法の落とし穴（他プロジェクトでも踏む）

- **`dumpsys gfxinfo` は Flutter アプリに使えない。** 全条件で `frames=0`〜数件。
  Impeller は HWUI を経由せず独自に描くので、Android 標準のフレーム統計に乗らない
- **`dumpsys battery unplug` 中は level と temperature が凍結される**（`UPDATES STOPPED`）。
  全条件で同値のまま動かない。この方法では電池の実測は取れない。**CPU を主指標にする**
- **`/proc/<pid>/stat` は読める**（この端末では制限されていない）。いちばん再現性が高い
- 測定後は必ず `dumpsys battery reset` と明るさ・リフレッシュレートを戻す

## 再現方法

```powershell
# 120Hz のまま4条件
pwsh -File measure.ps1 -Seconds 360

# 60Hz に固定してから測る（MIUI は独自設定も要る）
adb shell settings put system peak_refresh_rate 60
adb shell settings put system min_refresh_rate 60
adb shell settings put secure miui_refresh_rate 60
pwsh -File measure.ps1 -Seconds 360 -Modes @('flutter_anim','running')

# 戻す
adb shell settings put system peak_refresh_rate 120
adb shell settings delete system min_refresh_rate
adb shell settings put secure miui_refresh_rate 120
adb shell settings put system screen_brightness_mode 1
adb shell dumpsys battery reset
```

生データは `measurements/` に条件ごとの `gfx_*.txt` / `batt_*.txt` / `run*.log`。
