# 開発用の起動スクリプト。
#
# APIキーをソースにも履歴にも残さないために、ここで環境から読んで --dart-define に渡す。
# **キーは表示しない。** 見つかったかどうかだけ出す。
#
#   pwsh tools\run-dev.ps1                    # 端末の明暗設定に従う
#   pwsh tools\run-dev.ps1 -Brightness dark   # ダーク固定
#   pwsh tools\run-dev.ps1 -Device windows    # 実機が無いとき
#
# 段階5 で、端末に生キーを置かない形（サーバが ephemeral token を発行）に差し替える。
# --dart-define は APK に平文で残るので、**配布ビルドでは使えない**。

[CmdletBinding()]
param(
  [ValidateSet('', 'light', 'dark')][string]$Brightness = '',
  [string]$Device = '',
  [switch]$Release
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$appDir = Join-Path $PSScriptRoot '..\app' | Resolve-Path

function Get-GeminiKey {
  if ($env:GEMINI_API_KEY) { return $env:GEMINI_API_KEY }

  # 賀屋さんの了解のうえで jiyu-kenkyu-ai のキーを流用する
  $candidates = @(
    (Join-Path $PSScriptRoot '..\.env.local'),
    'C:\Users\kayah\jiyu-kenkyu-ai\.env.local'
  )
  foreach ($p in $candidates) {
    if (Test-Path $p) {
      $m = [regex]::Match((Get-Content $p -Raw), 'GEMINI_API_KEY\s*=\s*(\S+)')
      if ($m.Success) { return $m.Groups[1].Value.Trim('"', "'") }
    }
  }
  return $null
}

$key = Get-GeminiKey
if (-not $key) {
  Write-Error @'
GEMINI_API_KEY が見つかりません。次のどれかで渡してください:
  $env:GEMINI_API_KEY = '...'
  dekisugi-kun\.env.local に GEMINI_API_KEY=... を書く
'@
  exit 1
}
Write-Host "APIキー: 見つかりました (長さ $($key.Length))" -ForegroundColor Green

$flutterArgs = @('run')
if ($Release) { $flutterArgs += '--release' }
if ($Device) { $flutterArgs += @('-d', $Device) }
$flutterArgs += "--dart-define=GEMINI_API_KEY=$key"
if ($Brightness) { $flutterArgs += "--dart-define=FORCE_BRIGHTNESS=$Brightness" }

Push-Location $appDir
try {
  # 引数はそのまま渡す。ここで Write-Host するとキーがコンソールに出る
  & flutter @flutterArgs
} finally {
  Pop-Location
}
