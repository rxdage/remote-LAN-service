#!/usr/bin/env bash
# wireguard-hub preflight: fail early, touch nothing.
set -euo pipefail
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
err(){ printf '\033[31m%s\033[0m\n' "$*" >&2; }

port="$(printf '%s' "${RLS_PARAMS:-{}}" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("port",51820))' 2>/dev/null)"
port="${port:-51820}"

command -v systemctl >/dev/null || { err "缺 systemctl"; exit 1; }
command -v apt-get >/dev/null || warn "非 apt 系发行版:up 阶段会尝试 apt,失败请手动装 wireguard-tools 后重跑。"

# existing wg0 config — we won't overwrite it
if [ -f /etc/wireguard/wg0.conf ]; then
  warn "/etc/wireguard/wg0.conf 已存在 —— up 阶段将【保留不覆盖】,只确保服务在跑并打印现有 hub 公钥。"
fi

# UDP port free-ish
if ss -ulnH "( sport = :$port )" 2>/dev/null | grep -q .; then
  warn "UDP $port 已在监听(可能就是已装的 WireGuard)——若非本模块请换 port 参数。"
fi
echo "preflight ok (udp port=$port)"
