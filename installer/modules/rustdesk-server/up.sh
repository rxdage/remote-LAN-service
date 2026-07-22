#!/usr/bin/env bash
# rustdesk-server up: install hbbs+hbbr as systemd services (binary, no docker). Idempotent.
# Params (RLS_PARAMS json): public_ip
set -euo pipefail
info(){ printf '\033[36m%s\033[0m\n' "$*"; }
ok(){   printf '\033[32m%s\033[0m\n' "$*"; }
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
die(){  printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
public_ip="$(printf '%s' "${RLS_PARAMS:-{}}" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("public_ip",""))')"
[ -n "$public_ip" ] || die "缺 public_ip"

PREFIX=/opt/rustdesk-server
DATA=/var/lib/rustdesk-server
arch="$(uname -m)"; case "$arch" in x86_64|amd64) A=amd64;; aarch64|arm64) A=arm64;; *) die "arch $arch";; esac
REL="${RLS_RUSTDESK_VERSION:-1.1.12}"   # override via env if needed
ZIP="rustdesk-server-linux-${A}.zip"
URL="https://github.com/rustdesk/rustdesk-server/releases/download/${REL}/${ZIP}"

install -d "$PREFIX" "$DATA"

# -- obtain binaries: prefer pre-staged vendor/ (China network may block GitHub) --
if [ -x "$PREFIX/hbbs" ] && [ -x "$PREFIX/hbbr" ]; then
  info "hbbs/hbbr 已在 $PREFIX,跳过下载"
else
  tmp="$(mktemp -d)"; z="$tmp/$ZIP"
  if [ -f "$HERE/../../vendor/$ZIP" ]; then
    info "使用预置二进制: vendor/$ZIP"; cp "$HERE/../../vendor/$ZIP" "$z"
  else
    info "从 GitHub 下载 rustdesk-server $REL ($A) ..."
    command -v unzip >/dev/null || { apt-get update -y && apt-get install -y unzip || yum install -y unzip || true; }
    curl -fL --retry 3 --connect-timeout 15 -o "$z" "$URL" || die \
"下载失败(国内服务器常拉不动 GitHub)。两个办法:
  1) 在能上外网的机器下 $URL,放到 installer/vendor/$ZIP 再重跑;
  2) 或 export RLS_RUSTDESK_VERSION=<版本> 换个版本重试。"
  fi
  ( cd "$tmp" && unzip -oq "$z" )
  # zip 内可能有子目录,find 出来
  hbbs="$(find "$tmp" -type f -name hbbs | head -1)"; hbbr="$(find "$tmp" -type f -name hbbr | head -1)"
  [ -n "$hbbs" ] && [ -n "$hbbr" ] || die "解压后未找到 hbbs/hbbr"
  install -m 755 "$hbbs" "$PREFIX/hbbs"; install -m 755 "$hbbr" "$PREFIX/hbbr"
  ug="$(find "$tmp" -type f -name 'rustdesk-utils' | head -1)"; [ -n "$ug" ] && install -m 755 "$ug" "$PREFIX/rustdesk-utils" || true
  rm -rf "$tmp"
fi

# -- systemd units (data/key live in $DATA) --
cat > /etc/systemd/system/rustdesk-hbbs.service <<EOF
[Unit]
Description=RustDesk hbbs (ID/rendezvous server)
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
WorkingDirectory=$DATA
ExecStart=$PREFIX/hbbs -r ${public_ip}:21117
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/rustdesk-hbbr.service <<EOF
[Unit]
Description=RustDesk hbbr (relay server)
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
WorkingDirectory=$DATA
ExecStart=$PREFIX/hbbr
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now rustdesk-hbbr.service
systemctl enable --now rustdesk-hbbs.service
sleep 2

ok "hbbs + hbbr 已启动。"
info "服务器公钥(客户端 'Key' 字段要用)——若首启稍慢,verify 会再打印一次:"
[ -f "$DATA/id_ed25519.pub" ] && cat "$DATA/id_ed25519.pub" && echo || warn "(公钥还没生成,verify 阶段再看)"
