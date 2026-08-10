デキすぎ君 LAN coordinator
=============================

このフォルダーだけを、学校または家庭が管理するPCへ置きます。
repoのcheckout、Node.js、npm、OpenSSLは実行先PCに不要です。

配布archiveと同じ場所の .sha256 はarchive全体の検証用です。展開後の
SHA256SUMS.txtは実行ファイルの検証用です。配布元に表示された値と一致しない場合は
起動しないでください。

起動:
- macOS: start-coordinator.command
- Windows: start-coordinator.cmd
- Linux: start-coordinator.sh

起動するとLAN HTTPS接続先、証明書SHA-256、管理キーを表示します。
管理キーは部屋を作る管理者だけが使い、参加者へ渡さないでください。
参加者へ渡すのは、アプリが発行したDKS1.から始まる参加コードだけです。

停止:
- 表示中のterminalでCtrl+Cを押します。

保存:
- 初回起動時に、そのOSの利用者データ領域へ証明書、秘密鍵、管理キー、
  room状態を生成します。build成果物にはこれらの秘密は入っていません。
- 保存先を明示する場合だけ、実行ファイルへ --data <絶対パス> を渡します。

注意:
- coordinator PCと参加端末を、同じ信頼できるWi-Fiへ接続します。
- routerのguest/client isolationが有効だと端末同士は接続できません。
- 現在の成果物は署名・notarize前のpilot用です。学校配布済みとは扱いません。
- 複数実機によるFriends 2台 / League 5台の最終QAは別途必要です。
