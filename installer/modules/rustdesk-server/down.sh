#!/usr/bin/env bash
# rustdesk-server down: stop + disable services. Keeps $DATA (the key!) by default.
# Full purge (deletes key — clients would need re-keying): RLS_PURGE=1 bash down.sh
set -uo pipefail
info(){ printf '\033[36m%s\033[0m\n' "$*"; }
for s in rustdesk-hbbs rustdesk-hbbr; do
  systemctl disable --now "$s" 2>/dev/null || true
  rm -f "/etc/systemd/system/$s.service"
done
systemctl daemon-reload 2>/dev/null || true
info "已停用 hbbs/hbbr。二进制留在 /opt/rustdesk-server,密钥/数据留在 /var/lib/rustdesk-server。"
if [ "${RLS_PURGE:-0}" = 1 ]; then
  rm -rf /opt/rustdesk-server /var/lib/rustdesk-server
  info "已彻底清除(含密钥)。"
fi
