#!/usr/bin/env bash
# lib/install.sh — Step executor, package installer, backup/restore logic

RICER_BACKUP_DIR=""

# ── Privilege helper ─────────────────────────────────────────────────────────
_priv() {
  if [ "$EUID" -eq 0 ] || ! command -v sudo &>/dev/null; then
    "$@"
  else
    sudo "$@"
  fi
}

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
    readarray -t args < <(echo "$steps_json" | jq -r ".[$i].args[]? // empty")

    log_step "[$((i+1))/$n] $desc"

    if [ "$dry_run" = "true" ]; then
      log_dim "DRY-RUN: $type ${args[*]}"
      continue
    fi

    local rc=0
    case "$type" in
      install_pkg)        _pkg_install "${args[@]}" || rc=$? ;;
      stow)               _do_stow "$repo_dir" "${args[@]}" || rc=$? ;;
      copy)               _backup_copy "$repo_dir" "${args[@]}" || rc=$? ;;
      symlink)            _backup_link "$repo_dir" "${args[@]}" || rc=$? ;;
      grub_theme)         _install_grub_theme "$repo_dir" "${args[@]}" || rc=$? ;;
      limine_theme)       _install_limine_theme "$repo_dir" "${args[@]}" || rc=$? ;;
      systemd_boot_theme) _install_systemd_boot_theme "$repo_dir" "${args[@]}" || rc=$? ;;
      systemd_service)    _manage_systemd_service "${args[@]}" || rc=$? ;;
      resolve_conflict)   _resolve_conflict "${args[@]}" || rc=$? ;;
      run_cmd)            _run_in_repo "$repo_dir" "${args[@]}" || rc=$? ;;
      *)                  log_warn "Unknown step type '${type}' — skipping." ;;
    esac

    if [ $rc -ne 0 ]; then
      log_warn "Step $((i+1)) exited with code $rc — continuing..."
    fi
  done

  # Automatic post-install systemd daemon-reload if user services were installed
  if [ "$dry_run" = "false" ] && [ "${RICER_HAS_SYSTEMD:-false}" = "true" ]; then
    if [ -d "${HOME}/.config/systemd/user" ]; then
      systemctl --user daemon-reload 2>/dev/null || true
    fi
  fi

  if [ "$dry_run" = "false" ] && [ -d "$RICER_BACKUP_DIR" ]; then
    log_ok "Old configs backed up to: ${RICER_BACKUP_DIR}"
  fi
}

# ── Package install (dispatches to the right PM) ──────────────────────────────
_pkg_install() {
  [ $# -eq 0 ] && return 0
  log_dim "Installing packages: $*"
  case "$RICER_PM_CMD" in
    pacman)       _priv pacman -S --noconfirm --needed "$@" ;;
    apt|apt-get)  _priv apt-get install -y "$@" ;;
    dnf)          _priv dnf install -y "$@" ;;
    yum)          _priv yum install -y "$@" ;;
    zypper)       _priv zypper --non-interactive install "$@" ;;
    emerge)       _priv emerge --ask=n --verbose --noreplace "$@" ;;
    apk)          _priv apk add "$@" ;;
    xbps-install) _priv xbps-install -y "$@" ;;
    brew)         brew install "$@" ;;
    *)
      log_warn "Unknown package manager '${RICER_PM_CMD}' — skipping package install."
      return 1
      ;;
  esac
}

# ── Remove orphan/unused packages ─────────────────────────────────────────────
clean_orphan_packages() {
  local dry_run="${1:-false}"
  log_info "Checking for orphan / unused packages..."

  if [ "$dry_run" = "true" ]; then
    log_dim "DRY-RUN: remove orphan packages for package manager (${RICER_PM_CMD:-none})"
    return 0
  fi

  case "$RICER_PM_CMD" in
    pacman)
      local orphans
      orphans=$(pacman -Qtdq 2>/dev/null || true)
      if [ -n "$orphans" ]; then
        log_info "Removing orphan packages (pacman): $orphans"
        local -a orphan_arr=()
        read -r -a orphan_arr <<< "$orphans"
        if [ ${#orphan_arr[@]} -gt 0 ]; then
          _priv pacman -Rns --noconfirm "${orphan_arr[@]}"
        fi
        log_ok "Orphan packages removed successfully."
      else
        log_ok "No orphan packages found."
      fi
      ;;
    apt|apt-get)
      log_info "Removing unused packages (apt autoremove)..."
      _priv apt-get autoremove -y
      log_ok "Unused packages cleaned up."
      ;;
    dnf)
      log_info "Removing unused packages (dnf autoremove)..."
      _priv dnf autoremove -y
      log_ok "Unused packages cleaned up."
      ;;
    yum)
      log_info "Removing unused packages (yum autoremove)..."
      _priv yum autoremove -y
      log_ok "Unused packages cleaned up."
      ;;
    zypper)
      log_info "Removing orphaned packages (zypper rm -u)..."
      _priv zypper --non-interactive rm -u 2>/dev/null || true
      log_ok "Orphan packages cleaned up."
      ;;
    emerge)
      log_info "Cleaning unneeded dependencies (emerge --depclean)..."
      _priv emerge --ask=n --depclean
      log_ok "Gentoo dependencies cleaned up."
      ;;
    xbps-install)
      log_info "Removing orphan packages (xbps-remove -o)..."
      _priv xbps-remove -o -y 2>/dev/null || true
      log_ok "Void orphan packages removed."
      ;;
    apk)
      log_info "Cleaning packages (apk cache)..."
      _priv apk cache clean 2>/dev/null || true
      log_ok "Apk cache cleaned."
      ;;
    brew)
      log_info "Removing unused Homebrew formulae (brew autoremove)..."
      brew autoremove
      log_ok "Homebrew formulae cleaned."
      ;;
    *)
      log_warn "Orphan package removal not supported for package manager '${RICER_PM_CMD}'."
      ;;
  esac
}

# ── Conflict resolution ───────────────────────────────────────────────────────
_resolve_conflict() {
  local action="$1"; shift
  case "$action" in
    kill_proc)
      local proc="$1"
      if pgrep -x "$proc" &>/dev/null; then
        log_dim "Stopping conflicting process: $proc"
        killall -q "$proc" 2>/dev/null || pkill -x "$proc" 2>/dev/null || true
      fi
      ;;
    quarantine_file)
      local target="$1"
      target="${target/#\~/$HOME}"
      if [ -e "$target" ]; then
        log_dim "Quarantining conflicting file: $target"
        if [ "${RICER_NO_BACKUP:-false}" = "false" ] && [ -n "${RICER_BACKUP_DIR:-}" ]; then
          local rel_target="${target#$HOME/}"
          local qdir="${RICER_BACKUP_DIR}/quarantine/$(dirname "$rel_target")"
          mkdir -p "$qdir"
          cp -a "$target" "$qdir/" 2>/dev/null || true
        fi
        mv "$target" "${target}.ricer-quarantined" 2>/dev/null || true
      fi
      ;;
    backup_quarantine)
      local target="$1"
      target="${target/#\~/$HOME}"
      if [ -e "$target" ] && [ "${RICER_NO_BACKUP:-false}" = "false" ] && [ -n "${RICER_BACKUP_DIR:-}" ]; then
        log_dim "Backing up pre-rice configuration: $target"
        local rel_target="${target#$HOME/}"
        local qdir="${RICER_BACKUP_DIR}/quarantine/$(dirname "$rel_target")"
        mkdir -p "$qdir"
        cp -a "$target" "$qdir/" 2>/dev/null || true
      fi
      ;;
    disable_service)
      local svc="$1"
      if command -v systemctl &>/dev/null; then
        systemctl --user stop "$svc" 2>/dev/null || true
        systemctl --user disable "$svc" 2>/dev/null || true
      fi
      ;;
    *)
      log_dim "Conflict resolution: $action $*"
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

# ── Sensitive path checker (SEC-02) ───────────────────────────────────────────
_is_sensitive_path() {
  local target="$1"
  local canon
  canon=$(realpath -m "$target" 2>/dev/null || echo "$target")
  case "$canon" in
    "$HOME/.ssh"*|"$HOME/.gnupg"*|"$HOME/.aws"*|"$HOME/.local/share/keyrings"*|*/.ssh/*|*/.ssh|*/.gnupg/*|*/.gnupg|*/.aws/*|*/.aws|"/etc/shadow"*|"/etc/sudoers"*|"/etc/pam.d"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ── Copy with backup ──────────────────────────────────────────────────────────
_backup_copy() {
  local repo_dir="$1" src="$2" dst="$3"
  dst="${dst/#\~/$HOME}"
  dst="${dst%/}"
  [ -z "$dst" ] && return 1

  if _is_sensitive_path "$dst"; then
    log_warn "Security: Blocked attempt to write to protected sensitive path ($dst)"
    return 1
  fi

  local src_full="${repo_dir}/${src}"

  # If src is "." copy all top-level dotfiles to home safely
  if [ "$src" = "." ]; then
    find "$repo_dir" -maxdepth 1 -name '.*' \
      ! -name '.git' ! -name '.gitignore' -print0 \
    | while IFS= read -r -d '' f; do
        local bname
        bname=$(basename "$f")
        if [ -e "$HOME/$bname" ] && [ "${RICER_NO_BACKUP:-false}" = "false" ] && [ -n "${RICER_BACKUP_DIR:-}" ]; then
          mkdir -p "$RICER_BACKUP_DIR"
          cp -r "$HOME/$bname" "$RICER_BACKUP_DIR/$bname" 2>/dev/null || true
          log_dim "Backed up: $HOME/$bname -> $RICER_BACKUP_DIR/$bname"
        fi
        cp -r "$f" "$HOME/"
      done
    return 0
  fi

  # Backup existing destination if needed, preserving path hierarchy
  if [ -e "$dst" ] && [ "${RICER_NO_BACKUP:-false}" = "false" ] && [ -n "${RICER_BACKUP_DIR:-}" ]; then
    local rel_dst="${dst#$HOME/}"
    if [ "$rel_dst" != "$dst" ]; then
      mkdir -p "$RICER_BACKUP_DIR/$(dirname "$rel_dst")"
      cp -r "$dst" "$RICER_BACKUP_DIR/$rel_dst" 2>/dev/null || true
      log_dim "Backed up: $dst -> $RICER_BACKUP_DIR/$rel_dst"
    else
      mkdir -p "$RICER_BACKUP_DIR"
      cp -r "$dst" "$RICER_BACKUP_DIR/" 2>/dev/null || true
      log_dim "Backed up: $dst -> $RICER_BACKUP_DIR"
    fi
  fi

  mkdir -p "$(dirname "$dst")"
  if [ "$dst" = "$HOME/.config" ] || [ "$dst" = "$HOME" ] || [ "$dst" = "/" ]; then
    # Never rm -rf ~/.config, $HOME, or /
    mkdir -p "$dst"
    cp -r "$src_full"/. "$dst/"
  elif [ -d "$src_full" ]; then
    # If target directory already exists, ensure clean update (safety guard against empty or root/home dst)
    if [ "$dst" != "/" ] && [ "$dst" != "$HOME" ] && [ "$dst" != "$HOME/.config" ]; then
      rm -rf "$dst" 2>/dev/null || true
    fi
    cp -r "$src_full" "$dst"
  else
    cp -r "$src_full" "$dst"
  fi
}

# ── Symlink with backup ───────────────────────────────────────────────────────
_backup_link() {
  local repo_dir="$1" src="$2" dst="$3"
  dst="${dst/#\~/$HOME}"
  dst="${dst%/}"
  [ -z "$dst" ] && return 1

  if _is_sensitive_path "$dst"; then
    log_warn "Security: Blocked attempt to symlink to protected sensitive path ($dst)"
    return 1
  fi

  local src_full="${repo_dir}/${src}"
  [ ! -e "$src_full" ] && src_full="$src"   # allow absolute src

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "${RICER_NO_BACKUP:-false}" = "false" ] && [ -n "${RICER_BACKUP_DIR:-}" ]; then
      local rel_dst="${dst#$HOME/}"
      if [ "$rel_dst" != "$dst" ]; then
        mkdir -p "$RICER_BACKUP_DIR/$(dirname "$rel_dst")"
        cp -rP "$dst" "$RICER_BACKUP_DIR/$rel_dst" 2>/dev/null || true
        log_dim "Backed up: $dst -> $RICER_BACKUP_DIR/$rel_dst"
      else
        mkdir -p "$RICER_BACKUP_DIR"
        cp -rP "$dst" "$RICER_BACKUP_DIR/" 2>/dev/null || true
        log_dim "Backed up: $dst -> $RICER_BACKUP_DIR"
      fi
    fi
    if [ "$dst" != "/" ] && [ "$dst" != "$HOME" ] && [ "$dst" != "$HOME/.config" ]; then
      rm -rf "$dst"   # remove existing link or file/directory
    fi
  fi

  mkdir -p "$(dirname "$dst")"
  ln -sf "$src_full" "$dst"
  log_dim "Symlinked: $src_full -> $dst"
}

# ── Run command inside repo dir ───────────────────────────────────────────────
_run_in_repo() {
  local repo_dir="$1"; shift
  log_dim "Running: $* (in $repo_dir)"
  if [ $# -eq 1 ]; then
    local cmd="$1"
    if [ -f "$repo_dir/$cmd" ] && [ ! -x "$repo_dir/$cmd" ]; then
      chmod +x "$repo_dir/$cmd" 2>/dev/null || true
    fi
    (cd "$repo_dir" && bash -c "$cmd")
  else
    (cd "$repo_dir" && "$@")
  fi
}

# ── Install GRUB Theme ────────────────────────────────────────────────────────
_install_grub_theme() {
  local repo_dir="$1" src="${2:-}" theme_name="${3:-}"
  local src_full="${repo_dir}/${src}"

  if [ "${RICER_HAS_GRUB:-false}" != "true" ]; then
    log_warn "GRUB bootloader not detected on this system — skipping GRUB theme installation."
    return 0
  fi

  if [ -z "$src" ]; then
    src_full="$repo_dir"
  fi

  if [ -z "$theme_name" ]; then
    theme_name=$(basename "$src_full")
    [ "$theme_name" = "." ] && theme_name="custom-rice"
  fi

  log_info "Configuring GRUB theme: ${theme_name}..."

  # Locate themes directory
  local themes_dir="/boot/grub/themes"
  if [ -d "/boot/grub2" ] && [ ! -d "/boot/grub" ]; then
    themes_dir="/boot/grub2/themes"
  fi

  local target_dir="${themes_dir}/${theme_name}"

  # Back up /etc/default/grub if present
  if [ -f "/etc/default/grub" ] && [ "${RICER_NO_BACKUP:-false}" = "false" ] && [ -n "${RICER_BACKUP_DIR:-}" ]; then
    mkdir -p "$RICER_BACKUP_DIR"
    cp "/etc/default/grub" "$RICER_BACKUP_DIR/grub.default.bak" 2>/dev/null || true
    log_dim "Backed up /etc/default/grub -> $RICER_BACKUP_DIR"
  fi

  log_dim "Installing theme files to ${target_dir}..."
  _priv mkdir -p "$themes_dir"
  _priv rm -rf "$target_dir"
  _priv cp -r "$src_full" "$target_dir"

  # Find theme.txt
  local theme_txt
  if [ -f "${target_dir}/theme.txt" ]; then
    theme_txt="${target_dir}/theme.txt"
  else
    theme_txt=$(_priv find "$target_dir" -maxdepth 2 -name "theme.txt" 2>/dev/null | head -1)
  fi

  if [ -n "$theme_txt" ] && [ -f "/etc/default/grub" ]; then
    log_dim "Updating GRUB_THEME in /etc/default/grub..."
    if grep -q "^[[:space:]]*GRUB_THEME=" /etc/default/grub 2>/dev/null; then
      _priv sed -i "s|^[[:space:]]*GRUB_THEME=.*|GRUB_THEME=\"${theme_txt}\"|" /etc/default/grub
    elif grep -q "^[[:space:]]*#[[:space:]]*GRUB_THEME=" /etc/default/grub 2>/dev/null; then
      _priv sed -i "s|^[[:space:]]*#[[:space:]]*GRUB_THEME=.*|GRUB_THEME=\"${theme_txt}\"|" /etc/default/grub
    else
      echo "GRUB_THEME=\"${theme_txt}\"" | _priv tee -a /etc/default/grub >/dev/null
    fi

    # Update GRUB configuration
    log_dim "Regenerating GRUB config..."
    if command -v update-grub &>/dev/null; then
      _priv update-grub
    elif command -v grub-mkconfig &>/dev/null; then
      local grub_cfg="/boot/grub/grub.cfg"
      [ -f "/boot/grub2/grub.cfg" ] && grub_cfg="/boot/grub2/grub.cfg"
      _priv grub-mkconfig -o "$grub_cfg"
    elif command -v grub2-mkconfig &>/dev/null; then
      local grub_cfg="/boot/grub2/grub.cfg"
      [ -f "/boot/grub/grub.cfg" ] && grub_cfg="/boot/grub/grub.cfg"
      _priv grub2-mkconfig -o "$grub_cfg"
    else
      log_warn "GRUB config generator not found. Run grub-mkconfig manually."
    fi
    log_ok "GRUB theme applied: ${theme_name}"
  else
    log_warn "theme.txt or /etc/default/grub not found; theme files copied to ${target_dir}."
  fi
}

# ── Install Limine Bootloader Theme / Config ──────────────────────────────────
_install_limine_theme() {
  local repo_dir="$1" src="${2:-}" theme_name="${3:-}"
  local src_full="${repo_dir}/${src}"

  if [ "${RICER_HAS_LIMINE:-false}" != "true" ]; then
    log_warn "Limine bootloader not detected on this system — skipping Limine theme installation."
    return 0
  fi

  if [ -z "$src" ] || [ "$src" = "." ]; then
    src_full="$repo_dir"
  fi

  if [ -z "$theme_name" ]; then
    theme_name=$(basename "$src_full")
    [ "$theme_name" = "." ] && theme_name="limine-rice"
  fi

  log_info "Configuring Limine theme / configuration: ${theme_name}..."

  # Find Limine boot directory
  local limine_dir=""
  for d in "/boot/limine" "/boot/efi/limine" "/efi/limine" "/boot"; do
    if [ -d "$d" ] && { [ -f "$d/limine.conf" ] || [ -f "$d/limine.cfg" ] || [ "$d" != "/boot" ]; }; then
      limine_dir="$d"
      break
    fi
  done
  [ -z "$limine_dir" ] && limine_dir="/boot/limine"

  # Find config file in target
  local target_conf=""
  if [ -f "${limine_dir}/limine.conf" ]; then
    target_conf="${limine_dir}/limine.conf"
  elif [ -f "${limine_dir}/limine.cfg" ]; then
    target_conf="${limine_dir}/limine.cfg"
  else
    target_conf="${limine_dir}/limine.conf"
  fi

  # Back up existing limine config if present
  if [ -f "$target_conf" ] && [ "${RICER_NO_BACKUP:-false}" = "false" ] && [ -n "${RICER_BACKUP_DIR:-}" ]; then
    mkdir -p "$RICER_BACKUP_DIR"
    cp "$target_conf" "$RICER_BACKUP_DIR/$(basename "$target_conf").bak" 2>/dev/null || true
    log_dim "Backed up $target_conf -> $RICER_BACKUP_DIR"
  fi

  _priv mkdir -p "$limine_dir"

  # Locate source config in repo
  local repo_conf=""
  if [ -f "${src_full}/limine.conf" ]; then
    repo_conf="${src_full}/limine.conf"
  elif [ -f "${src_full}/limine.cfg" ]; then
    repo_conf="${src_full}/limine.cfg"
  fi

  # Copy assets (wallpapers, fonts, bitmaps, themes)
  local themes_dir="${limine_dir}/themes/${theme_name}"
  _priv mkdir -p "$themes_dir"
  _priv cp -r "$src_full"/* "$themes_dir/" 2>/dev/null || true

  # If repo contains full limine config or theme snippet
  if [ -n "$repo_conf" ]; then
    log_dim "Applying Limine styling from ${repo_conf}..."
    if grep -Eq '^(wallpaper|term_font|interface_branding|term_palette|term_background)' "$repo_conf" 2>/dev/null; then
      if [ -f "$target_conf" ]; then
        local wp
        wp=$(grep -E '^[[:space:]]*wallpaper:' "$repo_conf" 2>/dev/null | head -1 || true)
        if [ -n "$wp" ]; then
          if grep -q '^[[:space:]]*wallpaper:' "$target_conf" 2>/dev/null; then
            _priv sed -i "s|^[[:space:]]*wallpaper:.*|${wp}|" "$target_conf"
          else
            echo "$wp" | _priv tee -a "$target_conf" >/dev/null
          fi
        fi
        local font
        font=$(grep -E '^[[:space:]]*term_font:' "$repo_conf" 2>/dev/null | head -1 || true)
        if [ -n "$font" ]; then
          if grep -q '^[[:space:]]*term_font:' "$target_conf" 2>/dev/null; then
            _priv sed -i "s|^[[:space:]]*term_font:.*|${font}|" "$target_conf"
          else
            echo "$font" | _priv tee -a "$target_conf" >/dev/null
          fi
        fi
      else
        _priv cp "$repo_conf" "$target_conf"
      fi
    else
      [ ! -f "$target_conf" ] && _priv cp "$repo_conf" "$target_conf"
    fi
  fi

  # Check if wallpaper image exists in src_full
  local wp_img
  wp_img=$(find "$src_full" -maxdepth 2 -type f \( -name "wallpaper.*" -o -name "background.*" -o -name "*.png" -o -name "*.jpg" \) 2>/dev/null | head -1 || true)
  if [ -n "$wp_img" ] && [ -f "$target_conf" ]; then
    local wp_target="${limine_dir}/$(basename "$wp_img")"
    _priv cp "$wp_img" "$wp_target"
    log_dim "Installed Limine wallpaper: $(basename "$wp_img")"
    if ! grep -q '^[[:space:]]*wallpaper:' "$target_conf" 2>/dev/null; then
      echo "wallpaper: boot://$(basename "$wp_img")" | _priv tee -a "$target_conf" >/dev/null
    fi
  fi

  log_ok "Limine bootloader configuration updated: ${theme_name}"
}

# ── Install systemd-boot Theme / Splash ───────────────────────────────────────
_install_systemd_boot_theme() {
  local repo_dir="$1" src="${2:-}" theme_name="${3:-}"
  local src_full="${repo_dir}/${src}"

  if [ "${RICER_HAS_SYSTEMD_BOOT:-false}" != "true" ]; then
    log_warn "systemd-boot not detected on this system — skipping systemd-boot splash/theme installation."
    return 0
  fi

  if [ -z "$src" ] || [ "$src" = "." ]; then
    src_full="$repo_dir"
  fi

  log_info "Configuring systemd-boot splash/theme..."

  # Find loader directory
  local loader_dir=""
  for d in "/boot/loader" "/efi/loader"; do
    if [ -d "$d" ]; then
      loader_dir="$d"
      break
    fi
  done
  [ -z "$loader_dir" ] && loader_dir="/boot/loader"

  local loader_conf="${loader_dir}/loader.conf"

  # Backup loader.conf if present
  if [ -f "$loader_conf" ] && [ "${RICER_NO_BACKUP:-false}" = "false" ] && [ -n "${RICER_BACKUP_DIR:-}" ]; then
    mkdir -p "$RICER_BACKUP_DIR"
    cp "$loader_conf" "$RICER_BACKUP_DIR/loader.conf.bak" 2>/dev/null || true
    log_dim "Backed up $loader_conf -> $RICER_BACKUP_DIR"
  fi

  _priv mkdir -p "$loader_dir"

  # Check for splash image in src
  local splash_img
  splash_img=$(find "$src_full" -maxdepth 2 -type f \( -name "splash.bmp" -o -name "*.bmp" -o -name "splash.png" \) 2>/dev/null | head -1 || true)
  if [ -n "$splash_img" ]; then
    local target_splash="${loader_dir}/splash.bmp"
    _priv cp "$splash_img" "$target_splash"
    log_dim "Installed systemd-boot splash: ${target_splash}"
    if [ -f "$loader_conf" ]; then
      if grep -q "^[[:space:]]*splash" "$loader_conf" 2>/dev/null; then
        _priv sed -i "s|^[[:space:]]*splash.*|splash /loader/splash.bmp|" "$loader_conf"
      else
        echo "splash /loader/splash.bmp" | _priv tee -a "$loader_conf" >/dev/null
      fi
    fi
  fi

  # If repo has custom loader.conf options
  if [ -f "${src_full}/loader.conf" ] && [ -f "$loader_conf" ]; then
    local timeout
    timeout=$(grep -E '^[[:space:]]*timeout' "${src_full}/loader.conf" 2>/dev/null | head -1 || true)
    if [ -n "$timeout" ]; then
      if grep -q "^[[:space:]]*timeout" "$loader_conf" 2>/dev/null; then
        _priv sed -i "s|^[[:space:]]*timeout.*|${timeout}|" "$loader_conf"
      else
        echo "$timeout" | _priv tee -a "$loader_conf" >/dev/null
      fi
    fi
  fi

  log_ok "systemd-boot configuration updated."
}

# ── Manage Systemd Services ───────────────────────────────────────────────────
_manage_systemd_service() {
  local service_name="$1" action="${2:-enable}"

  if [ "${RICER_HAS_SYSTEMD:-false}" != "true" ]; then
    log_warn "systemd is not active on this system — skipping service management for ${service_name}."
    return 0
  fi

  systemctl --user daemon-reload 2>/dev/null || true

  case "$action" in
    enable)
      log_info "Enabling systemd user unit: ${service_name}..."
      systemctl --user enable "${service_name}" 2>/dev/null || log_warn "Failed to enable user unit ${service_name}."
      ;;
    start)
      log_info "Starting systemd user unit: ${service_name}..."
      systemctl --user start "${service_name}" 2>/dev/null || log_warn "Failed to start user unit ${service_name}."
      ;;
    enable-now|enable_now)
      log_info "Enabling and starting systemd user unit: ${service_name}..."
      systemctl --user enable --now "${service_name}" 2>/dev/null || log_warn "Failed to enable/start user unit ${service_name}."
      ;;
    reload)
      systemctl --user daemon-reload 2>/dev/null || true
      ;;
    *)
      log_warn "Unknown systemd action: ${action}"
      ;;
  esac
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

  # Restore files preserving directory hierarchy
  find "$latest" -mindepth 1 -maxdepth 1 ! -name "quarantine" ! -name "grub.default.bak" ! -name "limine.conf.bak" ! -name "limine.cfg.bak" ! -name "loader.conf.bak" -print0 \
  | while IFS= read -r -d '' item; do
      cp -rP "$item" "$HOME/"
    done

  # Restore quarantined items if present
  if [ -d "$latest/quarantine" ]; then
    log_info "Restoring quarantined files..."
    cp -rP "$latest/quarantine"/. "$HOME/" 2>/dev/null || true
    find "$HOME" -name "*.ricer-quarantined" -exec rm -f {} + 2>/dev/null || true
  fi

  # Restore GRUB config if backed up
  if [ -f "$latest/grub.default.bak" ]; then
    log_info "Restoring /etc/default/grub..."
    _priv cp "$latest/grub.default.bak" /etc/default/grub
    if command -v update-grub &>/dev/null; then
      _priv update-grub
    elif command -v grub-mkconfig &>/dev/null; then
      local grub_cfg="/boot/grub/grub.cfg"
      [ -f "/boot/grub2/grub.cfg" ] && grub_cfg="/boot/grub2/grub.cfg"
      _priv grub-mkconfig -o "$grub_cfg"
    elif command -v grub2-mkconfig &>/dev/null; then
      local grub_cfg="/boot/grub2/grub.cfg"
      [ -f "/boot/grub/grub.cfg" ] && grub_cfg="/boot/grub/grub.cfg"
      _priv grub2-mkconfig -o "$grub_cfg"
    fi
    log_ok "GRUB configuration restored."
  fi

  # Restore Limine config if backed up
  for lconf in "$latest/limine.conf.bak" "$latest/limine.cfg.bak"; do
    if [ -f "$lconf" ]; then
      local base_target
      base_target=$(basename "$lconf" .bak)
      log_info "Restoring Limine config ($base_target)..."
      for d in "/boot/limine" "/boot/efi/limine" "/efi/limine" "/boot"; do
        if [ -f "$d/$base_target" ] || [ -d "$d" ]; then
          _priv cp "$lconf" "$d/$base_target"
          break
        fi
      done
      log_ok "Limine configuration restored."
    fi
  done

  # Restore systemd-boot loader.conf if backed up
  if [ -f "$latest/loader.conf.bak" ]; then
    log_info "Restoring systemd-boot loader.conf..."
    for d in "/boot/loader" "/efi/loader"; do
      if [ -d "$d" ]; then
        _priv cp "$latest/loader.conf.bak" "$d/loader.conf"
        break
      fi
    done
    log_ok "systemd-boot configuration restored."
  fi

  log_ok "Restore complete."
}
