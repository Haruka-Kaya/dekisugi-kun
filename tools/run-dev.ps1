# 開発用の起動スクリプト。
#
# Flutter端末へ外部AIのキーを渡さない。会話資格情報はSERVER_URLのサーバーから受け取る。
#
#   pwsh tools\run-dev.ps1                    # 端末の明暗設定に従う
#   pwsh tools\run-dev.ps1 -Brightness dark   # ダーク固定
#   pwsh tools\run-dev.ps1 -Device windows    # 実機が無いとき
#
# 公開環境の生成AI APIは現在強制停止中。内部会話テストは、ローカルのserverを
# 明示して起動し、server側の内部テストguardを別途開いたときだけ行う。

[CmdletBinding()]
param(
  [ValidateSet('', 'light', 'dark')][string]$Brightness = '',
  [string]$Device = '',
  # units / live-token / directorを提供するサーバー。内部AIテストはローカルURLを渡す
  [string]$ServerUrl = $env:DEKISUGI_SERVER_URL,
  [switch]$Release
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$appDir = Join-Path $PSScriptRoot '..\app' | Resolve-Path

$flutterArgs = @('run')
if ($Release) { $flutterArgs += '--release' }
if ($Device) { $flutterArgs += @('-d', $Device) }
if ($Brightness) { $flutterArgs += "--dart-define=FORCE_BRIGHTNESS=$Brightness" }
if ($ServerUrl) {
  $server = $ServerUrl.TrimEnd('/')
  $flutterArgs += "--dart-define=SERVER_URL=$server"
  Write-Host "サーバー: $server" -ForegroundColor Green
} else {
  Write-Host 'サーバー: アプリ既定値（公開環境のAI会話は停止中）' -ForegroundColor Yellow
}

Push-Location $appDir
try {
  & flutter @flutterArgs
} finally {
  Pop-Location
}
