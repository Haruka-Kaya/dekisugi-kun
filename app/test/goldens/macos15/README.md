# macOS 15 の画像比較基準

Flutter 3.47.5 / GitHub Actions macos-15-arm64 の描画基準です。
macOS 26で作成する親ディレクトリの基準と、同じ比較許容値で検証します。
CIでは `DEKISUGI_GOLDEN_PLATFORM=macos15` を指定します。

取得元: [CI 36844537385](https://github.com/Haruka-Kaya/dekisugi-kun/actions/runs/36844537385)、commit `ec93f6e`。
差分画像を目視し、寸法・レイアウトが同一で、文字等のラスタ差が7〜240画素であることを確認して採用しました。

UIまたはSDKを変更した場合は、失敗時に保存される `macos-visual-differences` をレビューし、対応する基準を更新してください。比較許容値を広げて通過させないでください。
