# Gemini Live との通信テスト。実機は不要、ネットワークと APIキーだけ使う。
#
#   pwsh tools\test-live.ps1
#
# 設定をいじったら必ずこれを通してから実機に持っていくこと。
# Live API は設定の組み合わせを**接続後に**拒否するので、ビルドでは分からない。

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$appDir = Join-Path $PSScriptRoot '..\app' | Resolve-Path

function Get-GeminiKey {
  if ($env:GEMINI_API_KEY) { return $env:GEMINI_API_KEY }
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
if (-not $key) { Write-Error 'GEMINI_API_KEY が見つかりません'; exit 1 }

# 子プロセスにだけ渡す。コンソールには出さない
$env:GEMINI_API_KEY = $key
Push-Location $appDir
try {
  & flutter test test/live_config_network_test.dart -r expanded
} finally {
  Pop-Location
  Remove-Item Env:\GEMINI_API_KEY -ErrorAction SilentlyContinue
}
