<#
.SYNOPSIS
  サーバに貯まったアンケート回答を取り出す。

.DESCRIPTION
  生徒は**リンクを開いて答えるだけ**で、コードを渡す手間はない。
  回答はサーバの Redis に貯まるので、集計するときにここで引く。

  取り出しには管理トークンが要る。中高生の自由記述なので、
  誰でも読める場所には置かない。

.EXAMPLE
  # 件数だけ見る
  .\fetch-survey.ps1 -CountOnly

  # 取り出して集計まで
  .\fetch-survey.ps1
  python misconception-survey\analyze.py misconception-survey\responses.json
#>
param(
  [ValidateSet('misconception', 'type')]
  [string]$Kind = 'misconception',

  [string]$BaseUrl = 'https://rika-chousa.vercel.app',

  # 既定は secrets\survey-admin-token.txt
  [string]$TokenFile = (Join-Path $PSScriptRoot '..\secrets\survey-admin-token.txt'),

  [string]$Out,

  [switch]$CountOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $TokenFile)) {
  throw "管理トークンが見つかりません: $TokenFile"
}
$token = (Get-Content $TokenFile -Raw).Trim()

$headers = @{ Authorization = "Bearer $token" }

if ($CountOnly) {
  $r = Invoke-RestMethod -Uri "$BaseUrl/api/survey?kind=$Kind&countOnly=1" -Headers $headers
  "{0}: {1} 件" -f $r.kind, $r.count
  return
}

$r = Invoke-RestMethod -Uri "$BaseUrl/api/survey?kind=$Kind" -Headers $headers

if (-not $Out) {
  $dir = if ($Kind -eq 'misconception') { 'misconception-survey' } else { 'type-survey' }
  $Out = Join-Path $PSScriptRoot "$dir\responses.json"
}

# 1件1JSON の配列にして書き出す。analyze.py はこの形を読める
$rows = @($r.responses | ForEach-Object { $_ | ConvertFrom-Json })
$rows | ConvertTo-Json -Depth 12 | Set-Content $Out -Encoding utf8

"{0} 件を {1} に書き出しました" -f $rows.Count, $Out
if ($rows.Count -eq 0) {
  Write-Warning '0件です。まだ誰も答えていないか、保存先が繋がっていません。'
}
