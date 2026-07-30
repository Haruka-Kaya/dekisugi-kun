# Rive の常時アニメーションの消費を3条件で測る。
#
#   running … Rive を再生し続ける
#   frozen  … Rive を描画するがティッカーを止める（TickerMode: false）
#   static  … Rive を生成しない。同じ面積の矩形だけ
#
#   running - frozen = 再生（アニメーション進行）のコスト
#   frozen  - static = Rive を載せているだけのコスト
#
# 使い方:  powershell -ExecutionPolicy Bypass -File measure.ps1 [-Seconds 360]

param(
  [int]$Seconds = 360,
  [int]$Settle  = 30,
  # flutter_anim は対照条件。Rive を使わない素の Flutter 連続アニメーション。
  # これが無いと「Rive が重い」のか「120Hz で回り続けること自体が重い」のかを分けられない。
  [string[]]$Modes = @("running", "flutter_anim", "frozen", "static")
)

$ErrorActionPreference = "Stop"
# adb は stderr に出すので、ネイティブコマンドの終了コードで例外を投げさせない
$PSNativeCommandUseErrorActionPreference = $false
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$PKG = "jp.dekisugi.rive_power_probe"
$root = $PSScriptRoot
$out  = Join-Path $root "measurements"
New-Item -ItemType Directory -Force $out | Out-Null

function Get-BatteryField([string]$name) {
  # "level:" は "Capacity level:" にもマッチするので行頭にアンカーする
  $txt = (& $adb shell dumpsys battery | Out-String)
  if ($txt -match "(?m)^\s*$name\s*:\s*(-?\d+)") { return [int]$Matches[1] }
  return $null
}

function Get-CpuTicks {
  # /proc/<pid>/stat の 14番目(utime) と 15番目(stime) の合計。単位は clock tick
  $p = (& $adb shell pidof $PKG).Trim()
  if (-not $p) { return $null }
  # コマンド名に空白や括弧が入りうるので ')' の位置から数える
  $raw = (& $adb shell "cat /proc/$p/stat").Trim()
  $after = $raw.Substring($raw.LastIndexOf(')') + 2) -split '\s+'
  # after[0] = state(3番目) なので utime は after[11], stime は after[12]
  [pscustomobject]@{
    pid   = $p
    utime = [int64]$after[11]
    stime = [int64]$after[12]
    total = [int64]$after[11] + [int64]$after[12]
  }
}

$valid = @("running","frozen","static","flutter_anim")
foreach ($m in $Modes) {
  if ($valid -notcontains $m) {
    throw "不正なモード '$m'。有効なのは: $($valid -join ', ')  （-File で渡すときは -Modes a b のように空白区切り）"
  }
}
Write-Host ("測定するモード: " + ($Modes -join " -> "))

$summary = @()

foreach ($mode in $Modes) {
  Write-Host "`n========== $mode ==========" -ForegroundColor Cyan

  Push-Location $root
  & flutter build apk --release --dart-define=PROBE_MODE=$mode 2>&1 | Select-Object -Last 1
  Pop-Location
  & $adb install -r "$root\build\app\outputs\flutter-apk\app-release.apk" | Select-Object -Last 1

  # 充電中は batterystats が積算されないので擬似的に「外した」状態にする
  & $adb shell dumpsys battery unplug | Out-Null
  & $adb shell dumpsys batterystats --reset | Out-Null
  & $adb shell am force-stop $PKG
  Start-Sleep -Seconds 2
  & $adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 | Out-Null

  Write-Host "  安定待ち ${Settle}s ..."
  Start-Sleep -Seconds $Settle
  & $adb shell dumpsys gfxinfo $PKG reset | Out-Null

  $t0 = Get-CpuTicks
  $b0 = Get-BatteryField "level"
  $temp0 = Get-BatteryField "temperature"

  Write-Host "  本計測 ${Seconds}s（端末に触らないこと） pid=$($t0.pid) ..."
  $tops = @()
  $elapsed = 0
  while ($elapsed -lt $Seconds) {
    Start-Sleep -Seconds 30
    $elapsed += 30
    $line = & $adb shell "top -n 1 -b -q" 2>$null | Select-String $PKG
    if ($line) { $c = ($line.ToString().Trim() -split '\s+'); if ($c.Count -gt 8) { $tops += [double]$c[8] } }
    Write-Host "    ${elapsed}s / ${Seconds}s" -NoNewline
    Write-Host "`r" -NoNewline
  }
  Write-Host ""

  $t1 = Get-CpuTicks
  $b1 = Get-BatteryField "level"
  $temp1 = Get-BatteryField "temperature"

  & $adb shell dumpsys gfxinfo $PKG | Out-File "$out\gfx_$mode.txt" -Encoding utf8
  & $adb shell dumpsys batterystats $PKG | Out-File "$out\batt_$mode.txt" -Encoding utf8

  $ticks = $t1.total - $t0.total
  # clock tick は通常 100Hz。CPU秒 = ticks/100、CPU使用率 = CPU秒/経過秒
  $cpuSec = $ticks / 100.0
  $cpuPct = [math]::Round($cpuSec / $Seconds * 100, 1)

  $gfx = Get-Content "$out\gfx_$mode.txt"
  $gfxTxt = ($gfx | Out-String)
  $totalFrames = if ($gfxTxt -match "Total frames rendered:\s*(\d+)") { $Matches[1] } else { "n/a" }
  $jankyLine   = if ($gfxTxt -match "(?m)^\s*Janky frames:\s*(.+)$") { $Matches[1].Trim() } else { "n/a" }

  $summary += [pscustomobject]@{
    mode        = $mode
    cpuTicks    = $ticks
    cpuSeconds  = [math]::Round($cpuSec, 1)
    cpuPercent  = $cpuPct
    topMean     = if ($tops.Count) { [math]::Round(($tops | Measure-Object -Average).Average, 1) } else { $null }
    topMax      = if ($tops.Count) { ($tops | Measure-Object -Maximum).Maximum } else { $null }
    frames      = $totalFrames
    janky       = $jankyLine
    battLevel   = "$b0 -> $b1"
    tempC       = if ($temp0 -ne $null -and $temp1 -ne $null) { "$([math]::Round($temp0/10,1)) -> $([math]::Round($temp1/10,1))" } else { "n/a" }
  }
  Write-Host ("  CPU {0}% ({1} ticks / {2} CPU秒)  frames={3}  janky={4}" -f $cpuPct, $ticks, [math]::Round($cpuSec,1), $totalFrames, $summary[-1].janky) -ForegroundColor Green
}

# 端末を必ず元に戻す
& $adb shell am force-stop $PKG
& $adb shell dumpsys battery reset | Out-Null
& $adb shell settings put system screen_brightness_mode 1

Write-Host "`n===================== 結果 =====================" -ForegroundColor Yellow
$summary | Format-Table -AutoSize
$summary | ConvertTo-Json -Depth 3 | Out-File "$out\summary.json" -Encoding utf8

function Pct($m) { ($summary | Where-Object mode -eq $m).cpuPercent }
$r = Pct "running"; $fa = Pct "flutter_anim"; $f = Pct "frozen"; $st = Pct "static"
Write-Host ""
if ($null -ne $fa -and $null -ne $st) { Write-Host ("Flutter の連続アニメ基盤 (flutter_anim - static) : {0} %CPU" -f [math]::Round($fa - $st,1)) }
if ($null -ne $r  -and $null -ne $fa) { Write-Host ("Rive の上乗せ           (running - flutter_anim) : {0} %CPU" -f [math]::Round($r - $fa,1)) }
if ($null -ne $r  -and $null -ne $f)  { Write-Host ("再生のコスト            (running - frozen)       : {0} %CPU" -f [math]::Round($r - $f,1)) }
if ($null -ne $f  -and $null -ne $st) { Write-Host ("載せるコスト            (frozen  - static)       : {0} %CPU" -f [math]::Round($f - $st,1)) }
Write-Host "`n生データ: $out"
Write-Host "※ USB給電中は batterystats の mAh は OS の推定値。CPU を主指標として読むこと。"
