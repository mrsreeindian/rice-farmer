#!/usr/bin/env bash
# lib/install.sh — Step executor, package installer, backup/restore logic

RICER_BACKUP_DIR=""

# ── Init backup dir (called once before execute_steps) ────────────────────────
init_backup() {
  RICER_BACKUP_DIR="${HOME}/.config-backup-$(date +%Y%m%d-%H%M%S)"
  export RICER_BACKUP_DIR
}

# ── Pretty-print a plan for user confirmation ─────────────────────────────────
print_plan() {
  local steps_json="$1"
  local n
  n=$(echo "$steps_json" | jq 'length')
  echo ""
  echo -e "${BOLD}Install plan (${n} step(s)):${RESET}"
  echo "-----------------------------------------"
  for i in $(seq 0 $((n-1))); do
    local type desc args_str
    type=$(echo "$steps_json" | jq -r ".[$i].type")
    desc=$(echo "$steps_json" | jq -r ".[$i].description")
    args_str=$(echo "$steps_json" | jq -r ".[$i].args | join(\" \")")
    printf "  %2d. ${CYAN}[%s]${RESET} %s\n" "$((i+1))" "$type" "$desc"
    log_dim "args: $args_str"
  done
  echo "-----------------------------------------"
  echo ""
}

# ── Execute all steps ─────────────────────────────────────────────────────────
execute_steps() {
  local steps_json="$1" repo_dir="$2" dry_run="${3:-false}"
  local n
  n=$(echo "$steps_json" | jq 'length')

  if [ "$n" -eq 0 ]; then
    log_warn "No steps in plan — nothing to do."
    return 1
  fi

  [ "$dry_run" = "false" ] && init_backup

  for i in $(seq 0 $((n-1))); do
    local type desc
    type=$(echo "$steps_json" | jq -r ".[$i].type")
    desc=$(echo "$steps_json" | jq -r ".[$i].description")
    readarray -t args < <(echo "$steps_json" | jq -r ".[$i].args[]")

    log_step "[$((i+1))/$n] $desc"

    if [ "$dry_run" = "true" ]; then
      log_dim "DRY-RUN: $type ${args[*]}"
      continue
    fi

    case "$type" in
      install_pkg) _pkg_install "${args[@]}" ;;
      stow)        _do_stow "$repo_dir" "${args[@]}" ;;
      copy)        _backup_copy "$repo_dir" "${args[@]}" ;;
      symlink)     _backup_link "$repo_dir" "${args[@]}" ;;
      run_cmd)     _run_in_repo "$repo_dir" "${args[@]}" ;;
      *)           log_warn "Unknown step type '${type}' — skipping." ;;
    esac

    local rc=$?
    if [ $rc -ne 0 ]; then
      log_warn "Step $((i+1)) exited with code $rc — continuing..."
    fi
  done

  if [ "$dry_run" = "false" ] && [ -d "$RICER_BACKUP_DIR" ]; then
    log_ok "Old configs backed up to: ${RICER_BACKUP_DIR}"
  fi
}

# ── Package install (dispatches to the right PM) ──────────────────────────────
_pkg_install() {
  [ $# -eq 0 ] && return 0
  log_dim "Installing packages: $*"
  case "$RICER_PM_CMD" in
    pacman)       sudo pacman -S --noconfirm --needed "$@" ;;
    apt|apt-get)  sudo apt-get install -y "$@" ;;
    dnf|yum)      sudo dnf install -y "$@" ;;
    zypper)       sudo zypper install -y "$@" ;;
    apk)          sudo apk add "$@" ;;
    xbps-install) sudo xbps-install -y "$@" ;;
    emerge)       sudo emerge "$@" ;;
    brew)         brew install "$@" ;;
    *)
      log_warn "Unknown package manager '${RICER_PM_CMD}' — skipping package install."
      return 1
      ;;
  esac
}

# ── GNU Stow ──────────────────────────────────────────────────────────────────
_do_stow() {
  local repo_dir="$1"; shift
  local target="${HOME}"
  if ! command -v stow &>/dev/null; then
    log_info "stow not found — installing..."
    _pkg_install stow || die "Cannot install stow."
  fi
  log_dim "stow -d '${repo_dir}' -t '${target}' ${*}"
  stow --no-folding -d "$repo_dir" -t "$target" "$@" 2>&1 \
    || stow -d "$repo_dir" -t "$target" "$@"   # retry without --no-folding
}

# ── Copy with backup ──────────────────────────────────────────────────────────
_backup_copy() {
  local repo_dir="$1" src="$2" dst="$3"
  dst="${dst/\~/$HOME}"
  src_full="${repo_dir}/${src}"

  if [ -e "$dst" ] && [ "${RICER_NO_BACKUP:-false}" = "false" ]; then
    mkdir -p "$RICER_BACKUP_DIR"
    cp -r "$dst" "$RICER_BACKUP_DIR/" 2>/dev/null || true
    log_dim "Backed up: $dst → $RICER_BACKUP_DIR"
  fi

  # If src is "." copy all top-level dotfiles to home
  if [ "$src" = "." ]; then
    find "$repo_dir" -maxdepth 1 -name '.*' \
      ! -name '.git' ! -name '.gitignore' -print0 \
    | while IFS= read -r -d '' f; do
        cp -r "$f" "$HOME/"
      done
  else
    mkdir -p "$(dirname "$dst")"
    cp -r "$src_full" "$dst"
  fi
}

# ── Symlink with backup ───────────────────────────────────────────────────────
_backup_link() {
  local repo_dir="$1" src="$2" dst="$3"
  dst="${dst/\~/$HOME}"
  src_full="${repo_dir}/${src}"
  [ ! -e "$src_full" ] && src_full="$src"   # allow absolute src

  if [ -e "$dst" ] && [ ! -L "$dst" ] && [ "${RICER_NO_BACKUP:-false}" = "false" ]; then
    mkdir -p "$RICER_BACKUP_DIR"
    mv "$dst" "$RICER_BACKUP_DIR/"
    log_dim "Backed up: $dst → $RICER_BACKUP_DIR"
  elif [ -L "$dst" ]; then
    rm "$dst"   # remove existing symlink
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sf "$src_full" "$dst"
  log_dim "Symlinked: $src_full → $dst"
}

# ── Run command inside repo dir ───────────────────────────────────────────────
_run_in_repo() {
  local repo_dir="$1"; shift
  log_dim "Running: $* (in $repo_dir)"
  (cd "$repo_dir" && bash -c "$*")
}

# ── Restore last backup ───────────────────────────────────────────────────────
restore_latest_backup() {
  local latest
  latest=$(find "$HOME" -maxdepth 1 -type d -name '.config-backup-*' \
           | sort | tail -1)
  if [ -z "$latest" ]; then
    die "No backups found in $HOME."
  fi
  log_info "Restoring from: $latest"
  cp -r "$latest"/. "$HOME/"
  log_ok "Restore complete."
}
