# Quickstart B — 多线(加 WireGuard,直连内网 + 抗断)

在 [A 档](quickstart-A.md) 基础上加 WireGuard hub(可选再加 ZeroTier moon 当独立备用)。之后 RustDesk 可以填对方**内网 IP 直连**,不经任何 RustDesk 服务器;这条内网还能跑 RDP/SMB/SSH。为什么见 [why-wireguard](why-wireguard.md)。

> 前置:先按 A 档把 RustDesk 服务器跑起来(B 是叠加,不是替换)。

## 1. 服务器(Linux):加 WireGuard hub
```bash
sudo bash installer/install.sh      # 角色=服务器 → 档位=B → 勾 WireGuard hub
```
装完它会打印两样,记下来:
- **HUB 公钥**(客户端配置要用);
- **HUB Endpoint**（`公网IP:51820`）。

可选:同一向导里勾 **ZeroTier moon**,得到一个 moon ID(独立备用 overlay)。

## 2. 云安全组
放行 **UDP 51820**（WG）。勾了 ZeroTier 再放行 **UDP 9993**。
> 注意:WG 是 UDP,用 TCP 去探这个端口会显示 DOWN,属正常,别误判。

## 3. 客户端(每台 Windows)：接入 WG
先装 [WireGuard for Windows](https://www.wireguard.com/install/)。然后:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File installer\install.ps1
```
向导选 **档位 B → 接入 WireGuard**,填:上一步的 **HUB 公钥 / HUB Endpoint**、给本机分配一个**内网 IP**(如 `10.66.0.5`,每台不同)。

装完它会打印**本机公钥** + 一行命令。

## 4. 在服务器把客户端加为 peer(手动交换,私钥不出客户端)
把客户端打印的公钥拿到服务器上跑(示例把它设为 `10.66.0.5`):
```bash
sudo wg set wg0 peer <客户端公钥> allowed-ips 10.66.0.5/32
# 并把同样的 [Peer] 追加进 /etc/wireguard/wg0.conf 以持久化(重启不丢)
```
每台客户端重复 3-4,各给一个不同的 `10.66.0.x`。

## 5. 用
现在两台客户端都在 `10.66.0.0/24` 这张内网里。RustDesk 里**填对方的内网 IP**(如 `10.66.0.5`)直连 —— 走 WG 隧道,不碰 RustDesk 服务器。A 档的"按 ID 连"仍然可用,作为 UDP 被封时的兜底。

## 验证 / 排障
- 客户端 `ping 10.66.0.1`(hub)通 = 隧道起来了;`ping` 对方 `10.66.0.x` 通 = 两端 peer 都加对了。
- 连不上先查:云安全组 UDP 51820?两端 peer 都加了吗?客户端隧道服务在跑吗(`Get-Service 'WireGuardTunnel$*'`)?

## 想扛服务器整机挂掉?→ C 双服
[quickstart-C](quickstart-C.md)（第二台异地服务器,规划中）。
