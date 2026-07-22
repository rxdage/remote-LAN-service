#!/usr/bin/env bash
# rustdesk-server verify: services up, ports listening, print key + next-steps.
set -uo pipefail
ok(){   printf '\033[32m%s\033[0m\n' "$*"; }
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
DATA=/var/lib/rustdesk-server
public_ip="$(printf '%s' "${RLS_PARAMS:-{}}" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("public_ip",""))' 2>/dev/null)"

rc=0
for s in rustdesk-hbbs rustdesk-hbbr; do
  if systemctl is-active --quiet "$s"; then ok "  $s: active"; else warn "  $s: NOT active(看 journalctl -u $s)"; rc=1; fi
done

for p in 21115 21116 21117; do
  if ss -tulnH "( sport = :$p )" 2>/dev/null | grep -q .; then ok "  port $p: listening"; else warn "  port $p: not listening"; rc=1; fi
done

# key (may take a few seconds on first boot)
key=""
for _ in 1 2 3 4 5; do [ -f "$DATA/id_ed25519.pub" ] && { key="$(cat "$DATA/id_ed25519.pub")"; break; }; sleep 1; done

echo
ok "== 服务器就绪 =="
echo "  客户端 RustDesk 设置里填:"
echo "    ID/Relay 服务器 : ${public_ip:-<你的公网IP>}"
echo "    Key            : ${key:-<稍等片刻后 cat $DATA/id_ed25519.pub>}"
echo "  然后两端各自看自己的 ID,按 ID 互连即可(A 档)。"
echo
warn "别忘了云安全组放行: TCP 21115-21119 + UDP 21116(以及 SSH 22)。安装器不会替你改云安全组。"
exit $rc
