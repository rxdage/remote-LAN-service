#!/usr/bin/env bash
# wireguard-hub up: hub-and-spoke WG on this VPS. Idempotent (won't overwrite wg0.conf).
# Params: public_ip, subnet(default 10.66.0.0/24), port(default 51820)
set -euo pipefail
info(){ printf '\033[36m%s\033[0m\n' "$*"; }
ok(){   printf '\033[32m%s\033[0m\n' "$*"; }
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){  printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

read_param(){ printf '%s' "${RLS_PARAMS:-{}}" | python3 -c "import json,sys;print(json.load(sys.stdin).get('$1','$2'))"; }
public_ip="$(read_param public_ip '')"
subnet="$(read_param subnet '10.66.0.0/24')"
port="$(read_param port 51820)"
[ -n "$public_ip" ] || die "缺 public_ip"

# hub address = .1 of the subnet's network, keep the CIDR mask
cidr="${subnet##*/}"; net="${subnet%/*}"; hub_ip="${net%.*}.1"
hub_addr="${hub_ip}/${cidr}"

info "安装 WireGuard ..."
if command -v apt-get >/dev/null; then
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard-tools >/dev/null
elif command -v yum >/dev/null; then yum install -y wireguard-tools >/dev/null || die "yum 装 wireguard-tools 失败"
fi
command -v wg >/dev/null || die "wireguard-tools 未装成功"

info "开启 IP 转发(持久化)..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-wg-forward.conf

umask 077
install -d /etc/wireguard
cd /etc/wireguard
if [ -f wg0.conf ]; then
  warn "wg0.conf 已存在,保留不覆盖(如要重建: 先 systemctl stop wg-quick@wg0 && rm wg0.conf server_private.key,再重跑)。"
else
  [ -f server_private.key ] || { wg genkey > server_private.key; chmod 600 server_private.key; }
  PRIV="$(cat server_private.key)"
  cat > wg0.conf <<EOF
[Interface]
Address = ${hub_addr}
ListenPort = ${port}
PrivateKey = ${PRIV}
# spoke-to-spoke forwarding even if default FORWARD policy is DROP (e.g. Docker present)
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT
EOF
  chmod 600 wg0.conf
  ok "已写 /etc/wireguard/wg0.conf (hub=${hub_addr}, port=${port})"
fi

systemctl enable --now "wg-quick@wg0" >/dev/null 2>&1 || systemctl restart "wg-quick@wg0"
sleep 1
ok "WireGuard hub 已启动。"
echo
info "== 加客户端(手动交换公钥,私钥不出客户端)=="
echo "  在客户端生成密钥后,把它的公钥拿来,在本机执行(给它分配一个 IP,如 ${net%.*}.5):"
echo "    sudo wg set wg0 peer <客户端公钥> allowed-ips ${net%.*}.5/32"
echo "    # 并把同样的 [Peer] 追加进 /etc/wireguard/wg0.conf 以持久化"
echo "  HUB 公钥(填进客户端配置的 Peer.PublicKey):"
wg pubkey < /etc/wireguard/server_private.key
echo "  HUB Endpoint(客户端配置的 Peer.Endpoint):${public_ip}:${port}"
