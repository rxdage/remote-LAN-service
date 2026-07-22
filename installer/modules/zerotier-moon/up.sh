#!/usr/bin/env bash
# zerotier-moon up: install ZeroTier + create/sign a moon on this VPS. Idempotent.
# Params: public_ip
set -euo pipefail
info(){ printf '\033[36m%s\033[0m\n' "$*"; }
ok(){   printf '\033[32m%s\033[0m\n' "$*"; }
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){  printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

public_ip="$(printf '%s' "${RLS_PARAMS:-{}}" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("public_ip",""))')"
[ -n "$public_ip" ] || die "缺 public_ip"

if ! command -v zerotier-cli >/dev/null; then
  info "安装 ZeroTier(官方 APT 源,不用 curl|bash)..."
  apt-get install -y curl gnupg ca-certificates >/dev/null
  CODENAME="$(. /etc/os-release; echo "$VERSION_CODENAME")"
  curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x1657198823E52A61" -o /tmp/zt.asc
  gpg --batch --yes --dearmor < /tmp/zt.asc > /tmp/zt.gpg
  install -m 0644 /tmp/zt.gpg /usr/share/keyrings/zerotierone-archive-keyring.gpg
  rm -f /tmp/zt.asc /tmp/zt.gpg
  echo "deb [signed-by=/usr/share/keyrings/zerotierone-archive-keyring.gpg] https://download.zerotier.com/debian/${CODENAME} ${CODENAME} main" > /etc/apt/sources.list.d/zerotier.list
  apt-get update -o Dir::Etc::sourcelist="sources.list.d/zerotier.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" >/dev/null
  apt-get install -y zerotier-one >/dev/null
  systemctl enable --now zerotier-one
else info "ZeroTier 已装,跳过。"; fi

cd /var/lib/zerotier-one
if [ -f moon.json ]; then
  warn "moon.json 已存在,保留不重建。"
else
  info "生成并签发 moon(把公网 IP 写进 stableEndpoints)..."
  zerotier-idtool initmoon identity.public > /tmp/moon.json
  python3 - "$public_ip" <<'PY'
import json,sys
p="/tmp/moon.json"; d=json.load(open(p))
d["roots"][0]["stableEndpoints"]=[f"{sys.argv[1]}/9993"]
json.dump(d,open(p,"w"),indent=1); print("moon id =",d["id"])
PY
  ( cd /tmp && zerotier-idtool genmoon /tmp/moon.json >/dev/null )
  install -d /var/lib/zerotier-one/moons.d
  cp /tmp/000000*.moon /var/lib/zerotier-one/moons.d/
  cp /tmp/moon.json /var/lib/zerotier-one/moon.json && chmod 600 /var/lib/zerotier-one/moon.json
  rm -f /tmp/moon.json /tmp/000000*.moon
  systemctl restart zerotier-one
  sleep 4
fi

ok "ZeroTier moon 就绪。"
echo
info "== 客户端接入 =="
echo "  Moon ID(下面 listmoons 里的 id,10 位 hex):"
zerotier-cli listmoons 2>/dev/null | python3 -c 'import json,sys;print("   ",json.load(sys.stdin)[0]["id"])' 2>/dev/null || zerotier-cli listmoons
echo "  云安全组放行 UDP 9993,然后每台设备:  zerotier-cli orbit <moonID> <moonID>"
echo "  另需在你的 ZeroTier 网络里授权各设备(ZeroTier Central 或自建 controller)。"
