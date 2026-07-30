# 文字の読みやすさ調査（行間・字間）

`flutter-app-ui-2026.md` 第9部の**未回答4「日本語UIでの行間・字間の推奨値」**を埋めるための測定器。

一次ソースが存在しない領域なので、中高生に実際に読ませて決める。
デジタル庁デザインシステムは Web の下限（読み物は行高150%以上）までしか規定しておらず、
**字間については規定が無い**（DADS の letter-spacing 表は3票検証で否決済み）。

## 何を測っているか

| 次元 | 水準 | 根拠 |
|---|---|---|
| **行間** `line-height` | 1.45 / 1.60 / 1.75 / 1.90 | 1.45 ≒ Noto Sans JP の自然行高 **1.448em**（＝Material 3 の既定 1.43 と実質同じ＝**和文に行間を足していない状態**）。1.50 は DADS の読み物の最低値 |
| **字間** `letter-spacing` | 0 / 0.02em / 0.04em | 一次ソースが存在しないので、実務でありうる範囲を素直に置いた。Flutter 換算は fontSize 16 で **0 / 0.32px / 0.64px** |

## 測定設計

- **2肢強制選択（2AFC）の総当たり。** 評定尺度（5段階など）より感度が高い
- 行間6ペア＋字間3ペア＋**注意チェック1ペア**＝計10問、約3分
- 質問文は「どちらが読みやすいか」ではなく **「10分間ずっと読み続けるならどちらか」**。
  第一印象の見た目の好みではなく、持続的な読みに寄せるため
- **ペア内は同じ本文**（typography だけが変数）、**ペアをまたぐと本文が変わる**（3種を巡回）。
  同一本文を通すと後半は「読んで」ではなく「覚えて」判断されるため
- 提示順と A/B の割り当ては毎回ランダム。反転したかどうかも記録する
- 注意チェックは **行間 1.00 vs 1.75** の極端対比。1.00 を選んだ回答は無作為クリックとして除外
- 応答時間を全問記録。中央値が1.2秒未満の回答も除外候補

### フォントを埋め込んでいる理由

端末標準フォントは **Android = Noto Sans CJK / iOS = Hiragino** で**自然行高が違う**。
そのままだと「行間の比較」という測定自体が成立しないので、
Noto Sans JP を本調査で使う 299 文字だけにサブセットして埋め込んである（woff2 40.5 KiB）。

再生成する場合は `tools/type-survey/` の生成手順（下記）を使う。

## 使い方

### 配る

`index.html` は**外部通信が一切ない単一ファイル**（67.7 KiB）。
どこに置いても動く。ファイルをそのまま渡してもよい。

```
（例）GitHub Pages / 適当な静的ホスティング / LINE でファイルを送る
```

回答は**送信されない**。最後に出る結果コードを生徒からもらう。

### 集める

生徒に「コピーする」を押させ、そのコードを回収する。
`codes.txt` に1行1件で貼る。

### 集計する

```bash
python analyze.py codes.txt
# JSON を直接渡すこともできる
python analyze.py results/*.json
```

出力: 水準ごとの勝率、総当たりの内訳（二項検定の正規近似つき）、属性の分布、
除外された回答とその理由。

## 結果を Flutter に持ち込むときの注意

> [!warning] `leadingDistribution` を必ず `even` にする
> CSS の `line-height` は**上下均等（half-leading）**に配る。
> Flutter の既定は **`proportional`** で、Noto Sans JP では ascent:descent = 1160:288 ≒ **80:20** で配られ、
> **和文が行箱の下に沈む**。同じ数値を入れても見た目が一致しない。
>
> ```dart
> const TextStyle(
>   fontFamily: 'NotoSansJP',
>   fontSize: 16,
>   height: 1.75,                                       // ← 調査で決まった値
>   leadingDistribution: TextLeadingDistribution.even,  // ← これが無いと再現しない
> )
> ```
> Material 3 の `TextTheme` は全スタイルに `even` を入れているので、`Theme` 経由なら既定で入っている。

- `line-height: 1.75` → Flutter `height: 1.75`（どちらも fontSize の倍数なので直接対応する）
- `letter-spacing: 0.02em` → Flutter `letterSpacing: 0.32`（**論理ピクセル。em ではない**）
- Flutter の `letterSpacing` は **`textScaler` でスケールされない**。
  文字を大きくすると相対的に字間が詰まって見えるので、スケール時に補正するか許容するかを決めること

## この測定の限界（結論に書くときは必ず併記する）

1. **測っているのは選好であって読解成績ではない。** 「10分読む前提」で聞いてはいるが、
   実際に10分読ませて理解度を測ってはいない
2. **字間を広げると行数が増える。** 「字間」ではなく「行数」を見て選んだ可能性を排除できていない
   （実装上も字間は必ず折り返しに影響するので、その意味では実態に即しているとも言える）
3. **端末・画面幅・OSのフォントサイズ設定を統制していない。** 各自の端末で回答するため。
   `analyze.py` が画面幅とスケール推定の分布を出すので、偏りを必ず確認する
4. **サンプルが少ないと総当たりの各セルが数件になる。** 出力の有意判定は正規近似で
   多重比較の補正もしていない。参考値として扱う
5. 明るさ・姿勢・疲労は自己申告のみ

## 生成手順（フォントを作り直す場合）

刺激文や UI 文言を変えたら、使う文字が増えるのでフォントを作り直す。

```bash
# 1. Noto Sans JP（可変）を取得
curl -L -o NotoSansJP-VF.ttf \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/notosansjp/NotoSansJP%5Bwght%5D.ttf"

# 2. wght=400 に固定 → 使用文字だけにサブセット → woff2
python -m fontTools.varLib.instancer NotoSansJP-VF.ttf wght=400 -o NSJP-400.ttf
python -m fontTools.subset NSJP-400.ttf --text-file=subset_chars.txt \
  --output-file=NSJP-survey.woff2 --flavor=woff2 \
  --layout-features=kern,palt,vert,liga --no-hinting --desubroutinize
```

`--flavor=woff2` には `brotli` が要る（`pip install brotli`）。
`index.html` の `@font-face` の base64 を差し替える。

## 検証済みであること

ヘッドレス Chromium で全10問を通し、次を確認済み。

- 10ペアすべてでスタイルが実際に分岐している（`identicalPairs: 0`）
- ペア内の本文が常に同一（`allSameText: true`）
- 次元の内訳が `lh`×6 / `ls`×3 / `catch`×1 で、提示順がシャッフルされている
- 注意チェックが 16px（1.00）vs 28px（1.75）で描画されている
- 字間が 0.32px / 0.64px として描画されている（Flutter 論理ピクセル等価）
- 結果コードが復号でき、10件の回答と環境情報を含む（約1,900文字）
