# エミュレータからスクリーンショットを撮る。
#
# **毎回、前面がデキすぎ君であることを確認してから撮る。**
# 開発機のエミュレータには個人のアプリが入っていることがあり、
# 前面を確かめずに撮ると無関係な画面を保存してしまう。
#
#   pwsh tools\capture-shots.ps1 -OutDir docs\shots

[CmdletBinding()]
param(
  [string]$OutDir = 'docs/shots',
  [string]$Package = 'jp.dekisugi.dekisugi'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$env:PATH += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"

New-Item -ItemType Directory -Force $OutDir | Out-Null

function Assert-Foreground {
  $top = (adb shell dumpsys activity activities | Select-String 'topResumedActivity').ToString()
  if ($top -notmatch [regex]::Escape($Package)) {
    throw "前面が $Package ではない: $top"
  }
}

function Shot([string]$name) {
  Assert-Foreground
  $path = Join-Path $OutDir "$name.png"
  adb exec-out screencap -p > $path
  $kb = [math]::Round((Get-Item $path).Length / 1KB)
  Write-Host ("  {0,-28} {1,6} KB" -f $name, $kb)
}

function Tap([int]$x, [int]$y, [int]$waitMs = 700) {
  adb shell input tap $x $y | Out-Null
  Start-Sleep -Milliseconds $waitMs
}

Export-ModuleMember -Function * 2>$null
