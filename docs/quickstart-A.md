# Quickstart A — 极简自建 RustDesk(按 ID 连)

一台 Linux 云服务器 + 你的 Windows 机器。约 10 分钟。连接方式:自建 RustDesk 服务器居中撮合,按 ID 互连(打洞直连,打不通走服务器中继)。

## 你需要
- 一台 Linux 云服务器(有公网 IP,Ubuntu/Debian/CentOS 皆可,amd64 或 arm64);
- 能在云控制台改**安全组/防火墙**的权限;
- 每台要远程的 Windows 机器上装好 [RustDesk 客户端](https://rustdesk.com/)。

## 1. 服务器(Linux)
```bash
# 把本仓拷到服务器(git clone 或 scp),然后:
sudo bash installer/install.sh
```
向导里选:**角色=服务器 → 档位=A → 公网 IP**(会自动探测,确认即可)。
装完它会打印:
```
ID/Relay 服务器 : <你的公网IP>
Key            : <一串 base64>
```
把这两个记下来(Key 也可随时 `cat /var/lib/rustdesk-server/id_ed25519.pub`)。

## 2. 云安全组放行(控制台,安装器不替你改)
给这台服务器放行:**TCP 21115-21119** + **UDP 21116**(以及 SSH 22)。

## 3. 客户端(每台 Windows)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\install.ps1
```
向导里填:**服务器 IP、上一步的 Key**。它会把 RustDesk 指向你的服务器。
打开 RustDesk 看本机 **ID**,把两台的 ID 互相一填就能连。

## 4. 验证
- 两台 RustDesk 主界面底部应显示已连到你的服务器(绿色);
- 用一台的 RustDesk 输入另一台的 ID → 连上即成功。

## 排障
- **连不上/一直转圈**:多半是云安全组没放行 21116。先 `Test-NetConnection <服务器IP> -Port 21116`。
- **服务没起**:服务器上 `systemctl status rustdesk-hbbs rustdesk-hbbr`、`journalctl -u rustdesk-hbbs`。
- **下载 rustdesk-server 失败**(国内服务器拉不动 GitHub):在能上外网的机器下
  `rustdesk-server-linux-amd64.zip` 放到 `installer/vendor/` 再重跑。

## 想更强?→ 升级 B
A 够日常用,但依赖服务器撮合、只有一条路、只能跑 RustDesk。要**直连内网 / 抗断 / 顺便跑 RDP·SMB** →
[quickstart-B](quickstart-B.md)(加 WireGuard/ZeroTier,不用推倒重来)。为什么见 [why-wireguard](why-wireguard.md)。
