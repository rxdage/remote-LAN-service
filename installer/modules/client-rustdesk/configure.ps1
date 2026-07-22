# client-rustdesk (Windows): point RustDesk at the self-hosted server. Tier A core.
# Params: server_ip, key, peer_id(optional). Key-level merge — never clobbers trusted_devices.
[CmdletBinding()] param([Parameter(Mandatory)]$Params)
$ErrorActionPreference = 'Stop'
function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }

$serverIp = [string]$Params.server_ip
$key      = [string]$Params.key
if (-not $serverIp) { throw '缺 server_ip' }

$rdExe = 'C:\Program Files\RustDesk\rustdesk.exe'
if (-not (Test-Path $rdExe)) {
  Warn "未检测到 RustDesk($rdExe)。"
  Warn "请先装 RustDesk 客户端(https://rustdesk.com/ 或你服务器上放的安装包),再重跑本模块。"
  throw 'RustDesk 未安装'
}

# want-keys for tier A (connect by ID via self-hosted hbbs/hbbr)
$want = [ordered]@{
  'custom-rendezvous-server' = $serverIp
  'relay-server'             = $serverIp
}
if ($key) { $want['key'] = $key }

function Set-Options([string]$Path, $Options) {
  $enc = New-Object Text.UTF8Encoding($false)
  if (-not (Test-Path $Path)) {
    $dir = Split-Path -Parent $Path; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $sb = "[options]`n"; foreach ($k in $Options.Keys) { $sb += "$k = '$($Options[$k])'`n" }
    [IO.File]::WriteAllText($Path, $sb, $enc); return
  }
  $lines = [System.Collections.Generic.List[string]]::new()
  ([IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8) -split "`r?`n") | ForEach-Object { $lines.Add($_) }
  $optIdx = -1
  for ($i=0;$i -lt $lines.Count;$i++){ if ($lines[$i].Trim() -eq '[options]'){ $optIdx=$i; break } }
  if ($optIdx -lt 0){ $lines.Add('[options]'); $optIdx=$lines.Count-1 }
  $end = $lines.Count
  for ($i=$optIdx+1;$i -lt $lines.Count;$i++){ if ($lines[$i].Trim() -match '^\[.+\]$'){ $end=$i; break } }
  foreach ($k in $Options.Keys){
    $line = "$k = '$($Options[$k])'"; $found=$false
    for ($i=$optIdx+1;$i -lt $end;$i++){ if ($lines[$i] -match ("^\s*"+[regex]::Escape($k)+"\s*=")){ $lines[$i]=$line; $found=$true; break } }
    if (-not $found){ $lines.Insert($end,$line); $end++ }
  }
  [IO.File]::WriteAllText($Path, ($lines -join "`n"), $enc)
}

$svc = Get-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') { Stop-Service 'RustDesk' -Force; Info '暂停 RustDesk 服务以改配置' }

$paths = @(
  (Join-Path $env:APPDATA 'RustDesk\config\RustDesk2.toml')                                   # 用户级
)
# 服务级(无人值守时用);目录不存在就不写(装了服务模式才有)
$svcToml = 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\RustDesk2.toml'
if (Test-Path (Split-Path -Parent $svcToml)) { $paths += $svcToml }

foreach ($p in $paths) { Set-Options -Path $p -Options $want; Info "已写: $p" }
if ($svc) { Start-Service 'RustDesk' }
Info "RustDesk 已指向自建服务器 $serverIp。打开 RustDesk 看本机 ID,按对端 ID 连即可。"
