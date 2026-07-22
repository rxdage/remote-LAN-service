#!/usr/bin/env bash
set -uo pipefail
ok(){ printf '\033[32m%s\033[0m\n' "$*"; }
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
rc=0
if systemctl is-active --quiet zerotier-one; then ok "  zerotier-one: active"; else warn "  zerotier-one: NOT active"; rc=1; fi
if [ -f /var/lib/zerotier-one/moon.json ]; then ok "  moon.json: present"; else warn "  moon.json: missing"; rc=1; fi
if zerotier-cli listmoons 2>/dev/null | grep -q '"id"'; then ok "  moon: listed"; else warn "  moon: not listed(可能刚重启,稍等再看)"; rc=1; fi
echo; warn "云安全组放行 UDP 9993。WireGuard 是主力,ZeroTier 是独立备用 overlay。"
exit $rc
