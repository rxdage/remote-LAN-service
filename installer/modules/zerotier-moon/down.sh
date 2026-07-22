#!/usr/bin/env bash
# zerotier-moon down: remove the moon signature so this box stops acting as a relay root.
# Keeps ZeroTier installed + this node's identity. RLS_PURGE=1 also removes the ZeroTier package.
set -uo pipefail
info(){ printf '\033[36m%s\033[0m\n' "$*"; }
rm -f /var/lib/zerotier-one/moons.d/000000*.moon /var/lib/zerotier-one/moon.json 2>/dev/null || true
systemctl restart zerotier-one 2>/dev/null || true
info "已撤除 moon(本机不再作为 relay root)。ZeroTier 本体与身份保留。"
if [ "${RLS_PURGE:-0}" = 1 ]; then
  systemctl disable --now zerotier-one 2>/dev/null || true
  apt-get remove -y zerotier-one >/dev/null 2>&1 || true
  info "已卸载 zerotier-one。"
fi
