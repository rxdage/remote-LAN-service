#!/usr/bin/env bash
# rustdesk-server preflight: fail early, touch nothing.
set -euo pipefail
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
err(){ printf '\033[31m%s\033[0m\n' "$*" >&2; }

# arch
arch="$(uname -m)"
case "$arch" in
  x86_64|amd64) : ;;
  aarch64|arm64) : ;;
  *) err "不支持的架构: $arch(支持 amd64 / arm64)"; exit 1 ;;
esac

# tools
for t in curl systemctl; do command -v "$t" >/dev/null || { err "缺 $t"; exit 1; }; done
command -v unzip >/dev/null || warn "未装 unzip —— up 阶段若用 zip 版二进制会需要它(会尝试自动装)"

# ports free (hbbs 21115/21116/21118, hbbr 21117/21119)
busy=""
for p in 21115 21116 21117 21118 21119; do
  if ss -tulnH "( sport = :$p )" 2>/dev/null | grep -q .; then busy="$busy $p"; fi
done
if [ -n "$busy" ]; then
  err "以下端口已被占用:$busy —— 请先释放,或若是旧的 rustdesk-server 请先 down。"
  exit 1
fi

echo "preflight ok (arch=$arch, 端口 21115-21119 空闲)"
