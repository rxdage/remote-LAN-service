#!/usr/bin/env bash
set -euo pipefail
warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
err(){ printf '\033[31m%s\033[0m\n' "$*" >&2; }
command -v systemctl >/dev/null || { err "缺 systemctl"; exit 1; }
command -v apt-get >/dev/null || { err "zerotier-moon 模块目前只支持 apt 系(Ubuntu/Debian)。其它发行版请手动装 zerotier-one 后跑 deploy 逻辑。"; exit 1; }
python3 -c 'import json' 2>/dev/null || { err "缺 python3(签 moon 要用)"; exit 1; }
[ -f /var/lib/zerotier-one/moon.json ] && warn "已存在 moon.json —— up 阶段将保留现有 moon,只确保服务在跑。"
echo "preflight ok"
