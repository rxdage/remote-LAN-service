# remote-LAN-service — Windows installer (client side; server side is Linux install.sh).
# Console wizard now; a GUI setup.exe (WPF, ps2exe) is milestone M2 and shares this back-end.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer\install.ps1
#   ... -Plan install-plan.json      # unattended
[CmdletBinding()]
param([string]$Plan, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$modules = Join-Path $here 'modules'

function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Ask($p,$d=''){ $v = Read-Host ("{0}{1}" -f $p, $(if($d){" [$d]"}else{''})); if([string]::IsNullOrWhiteSpace($v)){$d}else{$v} }
function Confirm($p){ (Read-Host "$p (y/N)") -in @('y','Y') }

# ---- wizard ----------------------------------------------------------------
if (-not $Plan) {
  Info "== remote-LAN-service 客户端安装 =="
  $tier = Ask '档位 A/B/C(A=只按ID连RustDesk; B=多线; C=双服)' 'A'
  $mods = @()

  $sip = Ask 'RustDesk 服务器公网 IP' ''
  $key = Ask "服务器 Key(Linux 上 cat /var/lib/rustdesk-server/id_ed25519.pub)" ''
  $pid = Ask '常连的对端 RustDesk ID(可留空)' ''
  $mods += @{ name='client-rustdesk'; params=@{ server_ip=$sip; key=$key; peer_id=$pid } }

  if ($tier -ne 'A' -and (Confirm '接入 WG/ZT overlay(B档,需服务器已开)?')) { $mods += @{ name='client-overlay'; params=@{} } }
  if (Confirm '装 Line Panel 线路面板?') { $mods += @{ name='line-panel'; params=@{} } }

  $planObj = @{ version=1; role='client'; tier=$tier; modules=$mods }
  $Plan = Join-Path $here '..\install-plan.json'
  $planObj | ConvertTo-Json -Depth 6 | Out-File $Plan -Encoding utf8
  Ok "已生成安装计划: $Plan"
}

# ---- executor --------------------------------------------------------------
$p = Get-Content $Plan -Raw | ConvertFrom-Json
Info "计划: role=$($p.role) tier=$($p.tier), 模块数=$($p.modules.Count)"

# preflight all
foreach ($m in $p.modules) {
  $pf = Join-Path $modules "$($m.name)\preflight.ps1"
  if (Test-Path $pf) { Info "[$($m.name)] preflight ..."; & $pf -Params $m.params }
}
if ($DryRun) { Warn '--DryRun: 只预检,不安装。'; return }
if (-not (Confirm "将安装以上模块到这台客户端。继续?")) { Warn '已取消。'; return }

# up + verify
foreach ($m in $p.modules) {
  $up = Join-Path $modules "$($m.name)\configure.ps1"
  if (-not (Test-Path $up)) { Warn "[$($m.name)] 暂未实现(scaffold),跳过。"; continue }
  Info "[$($m.name)] 安装 ..."
  & $up -Params $m.params
  $vf = Join-Path $modules "$($m.name)\verify.ps1"
  if (Test-Path $vf) { & $vf -Params $m.params }
  Ok "[$($m.name)] 完成。"
}
Ok "全部完成。"
