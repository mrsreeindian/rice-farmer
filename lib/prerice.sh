#!/usr/bin/env bash
# lib/prerice.sh — Pre-rice conflict management, avoidance, and dependency coordinator

# Load all profiles
_PROFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/profiles" 2>/dev/null && pwd)"
if [ -d "$_PROFILES_DIR" ]; then
  for p in "$_PROFILES_DIR"/*.sh; do
    [ -f "$p" ] && source "$p"
  done
fi

detect_pre_rice() {
  if [ -n "${RICER_PRE_RICE:-}" ] && [ "$RICER_PRE_RICE" != "none" ]; then
    echo "$RICER_PRE_RICE"
    return 0
  fi

  if profile_omarchy_detect 2>/dev/null; then
    echo "omarchy"
  elif profile_cachyos_detect 2>/dev/null; then
    echo "cachyos"
  elif profile_garuda_detect 2>/dev/null; then
    echo "garuda"
  elif profile_omakub_detect 2>/dev/null; then
    echo "omakub"
  elif profile_caelestia_detect 2>/dev/null; then
    echo "caelestia"
  elif profile_generic_detect 2>/dev/null; then
    echo "generic"
  else
    echo "none"
  fi
}

prerice_get_name() {
  local pr="${1:-$(detect_pre_rice)}"
  case "$pr" in
    omarchy)   profile_omarchy_name ;;
    cachyos)   profile_cachyos_name ;;
    garuda)    profile_garuda_name ;;
    omakub)    profile_omakub_name ;;
    caelestia) profile_caelestia_name ;;
    generic)   profile_generic_name ;;
    *)         echo "Clean / Standard Linux" ;;
  esac
}

prerice_check_conflicts() {
  local pr="$1" repo_dir="$2"
  local raw=()
  case "$pr" in
    omarchy)   readarray -t raw < <(profile_omarchy_conflicts "$repo_dir" 2>/dev/null || true) ;;
    cachyos)   readarray -t raw < <(profile_cachyos_conflicts "$repo_dir" 2>/dev/null || true) ;;
    garuda)    readarray -t raw < <(profile_garuda_conflicts "$repo_dir" 2>/dev/null || true) ;;
    omakub)    readarray -t raw < <(profile_omakub_conflicts "$repo_dir" 2>/dev/null || true) ;;
    caelestia) readarray -t raw < <(profile_caelestia_conflicts "$repo_dir" 2>/dev/null || true) ;;
    generic)   readarray -t raw < <(profile_generic_conflicts "$repo_dir" 2>/dev/null || true) ;;
    *)         readarray -t raw < <(profile_generic_conflicts "$repo_dir" 2>/dev/null || true) ;;
  esac

  for line in "${raw[@]}"; do
    [ -n "$line" ] && echo "$line"
  done
}

prerice_get_resolutions() {
  local pr="$1" repo_dir="$2"
  case "$pr" in
    omarchy)   profile_omarchy_resolution_steps "$repo_dir" ;;
    cachyos)   profile_cachyos_resolution_steps "$repo_dir" ;;
    garuda)    profile_garuda_resolution_steps "$repo_dir" ;;
    omakub)    profile_omakub_resolution_steps "$repo_dir" ;;
    caelestia) profile_caelestia_resolution_steps "$repo_dir" ;;
    generic)   profile_generic_resolution_steps "$repo_dir" ;;
    *)         profile_generic_resolution_steps "$repo_dir" ;;
  esac
}

prerice_get_dependencies() {
  local pr="$1" repo_dir="$2"
  local raw=()
  case "$pr" in
    omarchy)   readarray -t raw < <(profile_omarchy_dependencies "$repo_dir" 2>/dev/null || true) ;;
    cachyos)   readarray -t raw < <(profile_cachyos_dependencies "$repo_dir" 2>/dev/null || true) ;;
    garuda)    readarray -t raw < <(profile_garuda_dependencies "$repo_dir" 2>/dev/null || true) ;;
    omakub)    readarray -t raw < <(profile_omakub_dependencies "$repo_dir" 2>/dev/null || true) ;;
    caelestia) readarray -t raw < <(profile_caelestia_dependencies "$repo_dir" 2>/dev/null || true) ;;
    *)         readarray -t raw < <(profile_generic_dependencies "$repo_dir" 2>/dev/null || true) ;;
  esac

  for p in "${raw[@]}"; do
    [ -n "$p" ] && echo "$p"
  done
}

print_conflict_warning() {
  local pr="$1"; shift
  local conflicts=("$@")
  [ ${#conflicts[@]} -eq 0 ] && return 0

  local pr_name
  pr_name=$(prerice_get_name "$pr")

  local w=60
  local line; line=$(printf '=%.0s' $(seq 1 $w))
  echo ""
  echo -e "${YELLOW}+${line}+${RESET}"
  printf "${YELLOW}|${RESET}  ${BOLD}${YELLOW}[!] Pre-Rice & Desktop Conflict Warning${RESET}%*s${YELLOW}|${RESET}\n" $((w-39)) ""
  echo -e "${YELLOW}+${line}+${RESET}"
  printf "${YELLOW}|${RESET}  ${BOLD}%-16s${RESET} : %-$((w-21))s${YELLOW}|${RESET}\n" "Detected Base" "${pr_name:0:$((w-21))}"
  printf "${YELLOW}|${RESET}  ${BOLD}%-16s${RESET} : %-$((w-21))s${YELLOW}|${RESET}\n" "Conflicts" "${#conflicts[@]} potential conflict(s) detected"
  echo -e "${YELLOW}+${line}+${RESET}"

  for c in "${conflicts[@]}"; do
    printf "${YELLOW}|${RESET}  - %-$((w-5))s${YELLOW}|${RESET}\n" "${c:0:$((w-5))}"
  done

  echo -e "${YELLOW}+${line}+${RESET}"
  printf "${YELLOW}|${RESET}  ${GREEN}[*] Automatic Conflict Resolution Plan:${RESET}%*s${YELLOW}|${RESET}\n" $((w-41)) ""
  printf "${YELLOW}|${RESET}    1. Back up all conflicting files to ~/.config-backup-*  ${YELLOW}|${RESET}\n"
  printf "${YELLOW}|${RESET}    2. Stop conflicting background daemons automatically    ${YELLOW}|${RESET}\n"
  printf "${YELLOW}|${RESET}    3. Auto-install any new dependencies required by rice   ${YELLOW}|${RESET}\n"
  echo -e "${YELLOW}+${line}+${RESET}"
  echo ""
}
