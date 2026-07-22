#!/usr/bin/env bash
# wireguard-hub verify: service active, iface up, port listening.
set -uo pipefail
ok(){ printf '\033[32m%s\033[0m\n' "$*"; }
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
read_param(){ printf '%s' "${RLS_PARAMS:-{}}" | python3 -c "import json,sys;print(json.load(sys.stdin).get('$1','$2'))" 2>/dev/null; }
port="$(read_param port 51820)"; port="${port:-51820}"

rc=0
if systemctl is-active --quiet wg-quick@wg0; then ok "  wg-quick@wg0: active"; else warn "  wg-quick@wg0: NOT active"; rc=1; fi
if ip link show wg0 >/dev/null 2>&1; then ok "  iface wg0: up"; else warn "  iface wg0: missing"; rc=1; fi
if ss -ulnH "( sport = :$port )" 2>/dev/null | grep -q .; then ok "  udp $port: listening"; else warn "  udp $port: not listening"; rc=1; fi
echo
warn "云安全组放行: UDP $port(以及各客户端加为 peer 后才能互连)。"
warn "注意: WireGuard 是 UDP,用 TCP 探测这个端口会显示 DOWN 属正常,别误判。"
exit $rc
