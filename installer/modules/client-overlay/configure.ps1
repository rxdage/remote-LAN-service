# client-overlay (Windows): join the WireGuard hub. Tier B client.
# Params: hub_pubkey, hub_endpoint (ip:port), my_ip (e.g. 10.66.0.5), subnet (e.g. 10.66.0.0/24)
# Private key is generated HERE and never leaves this machine; only the public key is shown
# for you to add on the hub. Installs the tunnel as a SERVICE (not GUI import — that drops on quit).
[CmdletBinding()] param([Parameter(Mandatory)]$Params)
$ErrorActionPreference = 'Stop'
function Info($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m){ Write-Host $m -ForegroundColor Green }
function Warn($m){ Write-Host $m -ForegroundColor Yellow }

$hubPub = [string]$Params.hub_pubkey
$hubEp  = [string]$Params.hub_endpoint
$myIp   = [string]$Params.my_ip
$subnet = [string]$Params.subnet; if (-not $subnet) { $subnet = '10.66.0.0/24' }
if (-not $hubPub -or -not $hubEp -or -not $myIp) { throw '缺 hub_pubkey / hub_endpoint / my_ip' }
$cidr = ($subnet -split '/')[1]; if (-not $cidr) { $cidr = '24' }

$wgDir = 'C:\Program Files\WireGuard'
$wgExe = Join-Path $wgDir 'wireguard.exe'; $wgCli = Join-Path $wgDir 'wg.exe'
if (-not (Test-Path $wgExe)) {
  Warn "未检测到 WireGuard($wgExe)。请先装 WireGuard for Windows(https://www.wireguard.com/install/),再重跑本模块。"
  throw 'WireGuard 未安装'
}

$cfgDir = Join-Path $env:ProgramData 'remote-lan-service\wg'
if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Force $cfgDir | Out-Null }
$privFile = Join-Path $cfgDir 'client.key'; $pubFile = Join-Path $cfgDir 'client.pub'

# generate keypair once; never regenerate (would invalidate the peer you added on the hub)
if (Test-Path $privFile) {
  Info '设备密钥已存在,不重生成。'
  $priv = (Get-Content $privFile -Raw).Trim(); $pub = (Get-Content $pubFile -Raw).Trim()
} else {
  $priv = (& $wgCli genkey).Trim()
  # write private key first, derive public via FILE REDIRECT — the PS native pipe corrupts
  # wg's stdin encoding ("Trailing characters" error); also keeps the key off the command line.
  [IO.File]::WriteAllText($privFile, $priv, (New-Object Text.UTF8Encoding($false)))
  $pub = (cmd /c "`"$wgCli`" pubkey < `"$privFile`"").Trim()
  if ($pub -notmatch '^[A-Za-z0-9+/]{43}=$') { throw "wg pubkey 输出异常: '$pub'" }
  [IO.File]::WriteAllText($pubFile, $pub, (New-Object Text.UTF8Encoding($false)))
  icacls $privFile /inheritance:r /grant 'SYSTEM:F' /grant 'Administrators:F' | Out-Null
  Ok "已本地生成密钥对(私钥不出本机)。"
}

$conf = @"
[Interface]
PrivateKey = $priv
Address = $myIp/$cidr

[Peer]
PublicKey = $hubPub
Endpoint = $hubEp
AllowedIPs = $subnet
PersistentKeepalive = 25
"@
$confPath = Join-Path $cfgDir 'rls-wg.conf'
[IO.File]::WriteAllText($confPath, $conf, (New-Object Text.UTF8Encoding($false)))   # no BOM (WireGuard rejects BOM)
icacls $confPath /inheritance:r /grant 'SYSTEM:F' /grant 'Administrators:F' | Out-Null

$svcName = 'WireGuardTunnel$rls-wg'
if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) {
  Info "$svcName 已存在,重装以应用新配置 ..."; & $wgExe /uninstalltunnelservice 'rls-wg' | Out-Null; Start-Sleep 1
}
& $wgExe /installtunnelservice $confPath
Ok "隧道服务已安装(开机自启,退出 GUI 不会掉)。"
Write-Host ''
Warn "== 最后一步:在服务器(hub)上把本机加为 peer =="
Write-Host "  本机公钥(拿去 hub 上执行):" -ForegroundColor White
Write-Host "    $pub" -ForegroundColor Green
Write-Host "  在 hub 上跑:  sudo wg set wg0 peer $pub allowed-ips $myIp/32" -ForegroundColor White
Write-Host "  (并把同样的 [Peer] 追加进 hub 的 /etc/wireguard/wg0.conf 持久化)" -ForegroundColor White
Write-Host "  加完后, 用 RustDesk 填对端的内网 IP(如 $myIp 段里的其它机器)即可直连。" -ForegroundColor White
