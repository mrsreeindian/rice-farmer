#!/usr/bin/env bash
# lib/utils.sh — Colors, logging, spinner helpers

# ── ANSI colors ────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; GREEN=$'\033[0;32m'
  CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  BLUE=$'\033[0;34m'; MAGENTA=$'\033[0;35m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; DIM=''; RESET=''
  BLUE=''; MAGENTA=''
fi

# ── Logging — all write to stderr to keep stdout clean for JSON captures ───────
log_info()  { echo -e "${CYAN}[*]${RESET} $*" >&2; }
log_ok()    { echo -e "${GREEN}[+]${RESET} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[!]${RESET} $*" >&2; }
log_error() { echo -e "${RED}[x]${RESET} $*" >&2; }
log_step()  { echo -e "${BOLD}${BLUE}[>]${RESET} $*" >&2; }
log_dim()   { echo -e "${DIM}    $*${RESET}" >&2; }

die() { log_error "$*"; exit 1; }

# ── Spinner ────────────────────────────────────────────────────────────────────
_SPINNER_PID=""
spinner_start() {
  local msg="${1:-Working...}"
  local frames=('-' '\' '|' '/')
  (
    i=0
    while true; do
      printf "\r${CYAN}%s${RESET} %s  " "${frames[$((i % ${#frames[@]}))]}" "$msg" >&2
      sleep 0.1
      ((i++))
    done
  ) &
  _SPINNER_PID=$!
  disown "$_SPINNER_PID" 2>/dev/null || true
}

spinner_stop() {
  if [ -n "$_SPINNER_PID" ]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
    printf "\r\033[K" >&2
  fi
}

# ── System info table ──────────────────────────────────────────────────────────
print_system_table() {
  local w=56
  local line; line=$(printf '=%.0s' $(seq 1 $w))
  echo -e "${CYAN}+${line}+${RESET}"
  printf "${CYAN}|${RESET}  ${BOLD}${MAGENTA}Rice Farmer — System Detection${RESET}%*s${CYAN}|${RESET}\n" $((w-32)) ""
  echo -e "${CYAN}+${line}+${RESET}"
  _row() { printf "${CYAN}|${RESET}  ${BOLD}%-10s${RESET} : %-$((w-15))s${CYAN}|${RESET}\n" "$1" "${2:0:$((w-15))}"; }
  _row "Distro"  "${RICER_DISTRO_PRETTY}"
  if [ "${RICER_IS_BAREBONES:-false}" = "true" ]; then
    _row "GUI/WM"  "none (barebones)"
  else
    _row "WM"      "${RICER_WM}"
  fi
  if [ "${RICER_PRE_RICE:-none}" != "none" ]; then
    _row "Pre-Rice" "${RICER_PRE_RICE}"
  fi
  _row "Pkgs"    "${RICER_PKG_MANAGERS}"
  _row "Boot"    "${RICER_BOOTLOADER}"
  _row "Init"    "${RICER_INIT_SYSTEM}"
  echo -e "${CYAN}+${line}+${RESET}"
}

# ── Prompt helpers ─────────────────────────────────────────────────────────────
confirm() {
  local prompt="${1:-Proceed?}" default="${2:-n}" yn_hint
  [ "$default" = "y" ] && yn_hint="[Y/n]" || yn_hint="[y/N]"
  echo -en "${BOLD}${prompt} ${yn_hint}${RESET} " >&2
  read -r ans
  case "${ans:-$default}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}
