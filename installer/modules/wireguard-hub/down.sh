#!/usr/bin/env bash
# wireguard-hub down: stop the tunnel. Keeps /etc/wireguard (keys+peers) by default.
# Full purge (deletes hub key — clients' Peer.PublicKey would change): RLS_PURGE=1 bash down.sh
set -uo pipefail
info(){ printf '\033[36m%s\033[0m\n' "$*"; }
systemctl disable --now wg-quick@wg0 2>/dev/null || true
info "已停用 wg-quick@wg0。/etc/wireguard(密钥+peer 列表)保留。"
if [ "${RLS_PURGE:-0}" = 1 ]; then
  rm -f /etc/wireguard/wg0.conf /etc/wireguard/server_private.key /etc/sysctl.d/99-wg-forward.conf
  info "已清除 wg0.conf + hub 私钥 + 转发配置。"
fi
