#!/usr/bin/env bash
# remote-LAN-service — Linux installer: wizard (or --plan) -> install-plan.json -> module executor.
# Three front-ends share this back-end: the wizard only produces a plan; the executor runs modules.
#
# Usage:
#   sudo bash install.sh                 # interactive wizard
#   sudo bash install.sh --plan p.json   # unattended, skip wizard
#   sudo bash install.sh --dry-run       # wizard + preflight only, no changes
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$HERE/modules"
PLAN=""
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --plan) PLAN="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

# ---- helpers ---------------------------------------------------------------
c_info(){ printf '\033[36m%s\033[0m\n' "$*"; }
c_ok(){   printf '\033[32m%s\033[0m\n' "$*"; }
c_warn(){ printf '\033[33m%s\033[0m\n' "$*"; }
c_err(){  printf '\033[31m%s\033[0m\n' "$*" >&2; }
die(){ c_err "$*"; exit 1; }

need_root(){ [ "$(id -u)" -eq 0 ] || die "需要 root。请用: sudo bash install.sh"; }
have(){ command -v "$1" >/dev/null 2>&1; }

# JSON via python3 (present on virtually every Linux server); jq not required.
have python3 || die "缺 python3(几乎所有发行版自带;请先装 python3)"
json_get(){ # json_get <file> <python-expr on `d`>   e.g. json_get plan 'd["role"]'
  python3 - "$1" <<PY
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
print($2)
PY
}

detect_public_ip(){
  # best-effort; wizard shows as default, user can override
  local ip=""
  ip="$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  [ -z "$ip" ] && ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
  echo "${ip:-}"
}

use_tui(){ have whiptail && [ -t 0 ] && [ -t 1 ]; }
menu(){ # menu "title" "text" tag1 item1 tag2 item2 ...  -> echoes chosen tag
  local title="$1" text="$2"; shift 2
  if use_tui; then whiptail --title "$title" --menu "$text" 20 74 8 "$@" 3>&1 1>&2 2>&3
  else
    echo "== $title ==" >&2; echo "$text" >&2
    local i=1; local -a tags=()
    while [ $# -gt 0 ]; do tags+=("$1"); echo "  $i) $1 - $2" >&2; shift 2; i=$((i+1)); done
    local sel; read -r -p "选择编号: " sel </dev/tty
    echo "${tags[$((sel-1))]}"
  fi
}
ask(){ # ask "prompt" "default" -> echoes value
  local prompt="$1" def="${2:-}"
  if use_tui; then whiptail --title "remote-LAN-service" --inputbox "$prompt" 10 74 "$def" 3>&1 1>&2 2>&3
  else local v; read -r -p "$prompt [$def]: " v </dev/tty; echo "${v:-$def}"; fi
}
confirm(){ # confirm "text" -> 0 yes / 1 no
  if use_tui; then whiptail --title "确认" --yesno "$1" 18 74
  else local v; read -r -p "$1  [y/N]: " v </dev/tty; [ "$v" = y ] || [ "$v" = Y ]; fi
}

# ---- wizard: build a plan ---------------------------------------------------
run_wizard(){
  local out="$HERE/../install-plan.json"
  local role tier; role="$(menu 'Role 角色' '这台机器的角色?' server '服务器(装 hbbs/WG/ZT)' client '客户端/终端机')"
  tier="$(menu 'Tier 档位' '选择档位(可从 A 起步,以后加模块升级)' A '极简: 只自建 RustDesk, 按 ID 连' B '多线: 加 WG/ZT/Headscale' C '双服: 第二台服务器备份')"

  # module selection per role+tier (M0 fully wires the A path)
  local -a mods=()
  if [ "$role" = server ]; then
    mods+=("rustdesk-server")
    if [ "$tier" != A ]; then
      confirm "加 WireGuard hub?(直连内网 + 抗断)" && mods+=("wireguard-hub") || true
      confirm "加 ZeroTier moon?(备用 overlay)"   && mods+=("zerotier-moon") || true
      confirm "加 Headscale?(自动入网, 可选)"      && mods+=("headscale") || true
    fi
    [ "$tier" = C ] && mods+=("second-region")
  else
    mods+=("client-rustdesk")
    [ "$tier" != A ] && { confirm "接入 WG/ZT overlay?" && mods+=("client-overlay") || true; }
    confirm "装 Line Panel(线路面板 GUI)?" && mods+=("line-panel") || true
  fi

  # collect params (M0: rustdesk-server + client-rustdesk the ones that need values)
  local pub=""; pub="$(detect_public_ip)"
  local plan_mods=""
  for m in "${mods[@]}"; do
    local params="{}"
    case "$m" in
      rustdesk-server) local ip; ip="$(ask '服务器公网 IP' "$pub")"; params="{\"public_ip\":\"$ip\"}" ;;
      wireguard-hub)   local ip; ip="$(ask 'WG hub 公网 IP' "$pub")"; params="{\"public_ip\":\"$ip\",\"subnet\":\"10.66.0.0/24\",\"port\":51820}" ;;
      client-rustdesk) local sip pid; sip="$(ask 'RustDesk 服务器 IP' '')"; pid="$(ask '要连的对端 RustDesk ID(可留空)' '')"; params="{\"server_ip\":\"$sip\",\"peer_id\":\"$pid\"}" ;;
    esac
    [ -n "$plan_mods" ] && plan_mods="$plan_mods,"
    plan_mods="$plan_mods{\"name\":\"$m\",\"params\":$params}"
  done

  cat > "$out" <<EOF
{
  "version": 1,
  "role": "$role",
  "tier": "$tier",
  "modules": [$plan_mods]
}
EOF
  c_ok "已生成安装计划: $out"
  PLAN="$out"
}

# ---- executor: run selected modules ----------------------------------------
run_plan(){
  local plan="$1"
  [ -f "$plan" ] || die "找不到计划文件: $plan"
  local role tier count
  role="$(json_get "$plan" 'd["role"]')"
  tier="$(json_get "$plan" 'd["tier"]')"
  count="$(json_get "$plan" 'len(d["modules"])')"
  c_info "计划: role=$role tier=$tier, 模块数=$count"

  # 1) preflight all first — fail early before touching anything
  for i in $(seq 0 $((count-1))); do
    local name; name="$(json_get "$plan" "d['modules'][$i]['name']")"
    local mod="$MODULES_DIR/$name"
    [ -d "$mod" ] || die "模块不存在: $name ($mod)"
    if [ -f "$mod/preflight.sh" ]; then
      c_info "[$name] preflight ..."
      RLS_PARAMS="$(json_get "$plan" "__import__('json').dumps(d['modules'][$i].get('params',{}),ensure_ascii=False)")" \
        bash "$mod/preflight.sh" || die "[$name] preflight 失败,已中止(未做任何改动)"
    fi
  done
  c_ok "全部 preflight 通过。"

  if [ "$DRY_RUN" = 1 ]; then c_warn "--dry-run: 只做了预检,不执行安装。"; return 0; fi
  confirm "以上模块将被安装到这台 $role。继续?" || die "用户取消。"

  # 2) up each, then verify
  for i in $(seq 0 $((count-1))); do
    local name; name="$(json_get "$plan" "d['modules'][$i]['name']")"
    local mod="$MODULES_DIR/$name"
    local params; params="$(json_get "$plan" "__import__('json').dumps(d['modules'][$i].get('params',{}),ensure_ascii=False)")"
    c_info "[$name] 安装 ..."
    RLS_PARAMS="$params" bash "$mod/up.sh"     || die "[$name] 安装失败。回滚: sudo bash $mod/down.sh"
    [ -f "$mod/verify.sh" ] && { RLS_PARAMS="$params" bash "$mod/verify.sh" || c_warn "[$name] verify 有告警(见上)"; }
    c_ok "[$name] 完成。"
  done
  c_ok "全部完成。"
}

# ---- main -------------------------------------------------------------------
need_root
[ -z "$PLAN" ] && run_wizard
run_plan "$PLAN"
