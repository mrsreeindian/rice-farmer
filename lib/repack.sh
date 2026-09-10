#!/usr/bin/env bash
# lib/repack.sh — Repack active system configuration, wallpaper, keybinds, and widgets into a shareable rice zip

# ── Detect or resolve repack format ──────────────────────────────────────────
repack_resolve_format() {
  local user_format="${RICER_REPACK_FORMAT:-}"
  if [ -n "$user_format" ]; then
    case "$user_format" in
      omarchy|caelestia|garuda|cachyos|generic)
        echo "$user_format"
        return 0
        ;;
      *)
        log_warn "Unknown format '${user_format}' — defaulting to generic."
        echo "generic"
        return 0
        ;;
    esac
  fi

  local detected
  detected=$(detect_pre_rice 2>/dev/null || echo "none")
  case "$detected" in
    omarchy)   echo "omarchy" ;;
    caelestia) echo "caelestia" ;;
    garuda)    echo "garuda" ;;
    cachyos)   echo "cachyos" ;;
    *)         echo "generic" ;;
  esac
}

# ── Active Wallpaper Detection ────────────────────────────────────────────────
repack_find_wallpaper() {
  local format="${1:-generic}"
  local wp=""

  # 1. Check swww active wallpaper
  if command -v swww &>/dev/null; then
    local swww_out
    swww_out=$(swww query 2>/dev/null || true)
    if [ -n "$swww_out" ]; then
      wp=$(echo "$swww_out" | grep -oE '(/[^,:]+\.(jpg|jpeg|png|webp|gif))' | head -1)
      [ -f "$wp" ] && echo "$wp" && return 0
    fi
  fi

  # 2. Check hyprpaper
  if [ -f "${HOME}/.config/hypr/hyprpaper.conf" ]; then
    local hp_match
    hp_match=$(grep -E '^(preload|wallpaper)[[:space:]]*=' "${HOME}/.config/hypr/hyprpaper.conf" 2>/dev/null | grep -oE '(/[^,]+\.(jpg|jpeg|png|webp))' | head -1)
    hp_match="${hp_match/#\~/$HOME}"
    [ -f "$hp_match" ] && echo "$hp_match" && return 0
  fi

  # 3. Check feh
  if [ -f "${HOME}/.fehbg" ]; then
    local feh_match
    feh_match=$(grep -oE "['\"][^'\"]+\.(jpg|jpeg|png|webp)['\"]" "${HOME}/.fehbg" 2>/dev/null | tr -d "'\"" | head -1)
    feh_match="${feh_match/#\~/$HOME}"
    [ -f "$feh_match" ] && echo "$feh_match" && return 0
  fi

  # 4. Check swaybg
  local swaybg_cmd
  swaybg_cmd=$(pgrep -a swaybg 2>/dev/null || true)
  if [ -n "$swaybg_cmd" ]; then
    local sbg_match
    sbg_match=$(echo "$swaybg_cmd" | grep -oE '(-i|--image)[[:space:]]+([^ ]+)' | awk '{print $2}')
    sbg_match="${sbg_match/#\~/$HOME}"
    [ -f "$sbg_match" ] && echo "$sbg_match" && return 0
  fi

  # 5. Format-specific wallpaper locations
  case "$format" in
    omarchy)
      if [ -d "${HOME}/.config/omarchy/backgrounds" ]; then
        local obg
        obg=$(find "${HOME}/.config/omarchy/backgrounds" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -1)
        [ -n "$obg" ] && [ -f "$obg" ] && echo "$obg" && return 0
      fi
      if [ -f "${HOME}/.config/omarchy/wallpaper" ]; then
        local owp
        owp=$(readlink -f "${HOME}/.config/omarchy/wallpaper" 2>/dev/null || echo "${HOME}/.config/omarchy/wallpaper")
        [ -f "$owp" ] && echo "$owp" && return 0
      fi
      ;;
    caelestia)
      if [ -f "${HOME}/.config/caelestia/wallpaper" ]; then
        local cwp
        cwp=$(readlink -f "${HOME}/.config/caelestia/wallpaper" 2>/dev/null || echo "${HOME}/.config/caelestia/wallpaper")
        [ -f "$cwp" ] && echo "$cwp" && return 0
      fi
      if [ -d "${HOME}/.local/share/caelestia/wallpapers" ]; then
        local cbg
        cbg=$(find "${HOME}/.local/share/caelestia/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -1)
        [ -n "$cbg" ] && [ -f "$cbg" ] && echo "$cbg" && return 0
      fi
      ;;
    garuda)
      if [ -d "/usr/share/wallpapers/garuda-wallpapers" ]; then
        local gbg
        gbg=$(find "/usr/share/wallpapers/garuda-wallpapers" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -1)
        [ -n "$gbg" ] && [ -f "$gbg" ] && echo "$gbg" && return 0
      fi
      ;;
  esac

  # 6. Fallback to user Pictures/Wallpapers or ~/.wallpapers
  local fallback
  fallback=$(find "${HOME}/Pictures/Wallpapers" "${HOME}/Pictures/Wallpaper" "${HOME}/Pictures" "${HOME}/.wallpapers" "${HOME}/wallpapers" "${HOME}/Wallpapers" -maxdepth 2 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -1)
  [ -n "$fallback" ] && [ -f "$fallback" ] && echo "$fallback" && return 0

  echo ""
}

# ── Duplicate file or directory tree dereferencing all symlinks ────────────────
repack_duplicate_item() {
  local src="$1" dst="$2"
  [ -e "$src" ] || return 1

  mkdir -p "$(dirname "$dst")"

  if [ -f "$src" ]; then
    # Dereference symlink and duplicate real content
    cp -L "$src" "$dst" 2>/dev/null || cp "$src" "$dst" 2>/dev/null || return 1
    return 0
  fi

  if [ -d "$src" ]; then
    mkdir -p "$dst"
    # Copy directory tree dereferencing all symlinks into real duplicate files
    cp -rL "$src"/. "$dst/" 2>/dev/null || cp -r "$src"/. "$dst/" 2>/dev/null || true

    # Strip out non-shareable junk: git metadata, sockets, logs, caches, sensitive credentials
    find "$dst" -depth \( \
      -name ".git" -o -name ".github" -o -name ".cache" -o -name "cache" -o -name "Cache" \
      -o -name "*.sock" -o -name "*.socket" -o -name "*.log" \
      -o -name "*.key" -o -name "*.pem" -o -name "*token*" -o -name "*secret*" -o -name "*credential*" \
      -o -type s -o -type p \
    \) -exec rm -rf {} + 2>/dev/null || true

    # Delete any dangling symlinks
    find "$dst" -xtype l -delete 2>/dev/null || true
    return 0
  fi
  return 1
}

# ── Verification pass: Dereference all remaining symlinks in staging dir ──────
repack_dereference_all() {
  local dir="$1"
  [ -d "$dir" ] || return 0

  while IFS= read -r -d '' sym; do
    if [ -e "$sym" ]; then
      local target
      target=$(readlink -f "$sym" 2>/dev/null || true)
      if [ -n "$target" ] && [ -e "$target" ]; then
        rm -f "$sym"
        if [ -d "$target" ]; then
          mkdir -p "$sym"
          cp -rL "$target"/. "$sym/" 2>/dev/null || true
        else
          cp -L "$target" "$sym" 2>/dev/null || true
        fi
      else
        rm -f "$sym"
      fi
    else
      rm -f "$sym"
    fi
  done < <(find "$dir" -type l -print0 2>/dev/null)
}

# ── Safe Config Entry Copy (directory or file) ────────────────────────────────
repack_copy_app_config() {
  local app="$1" stage_config_dir="$2"
  local src="${HOME}/.config/${app}"
  local dst="${stage_config_dir}/${app}"

  [ -e "$src" ] || return 1
  if repack_duplicate_item "$src" "$dst"; then
    log_dim "Included config: ~/.config/${app}"
    return 0
  fi
  return 1
}

# ── Safe Home Dotfile Copy (e.g. .bashrc, .zshrc, .vimrc, .tmux.conf) ─────────
repack_copy_home_dotfile() {
  local dotfile="$1" stage_home_dir="$2"
  local src="${HOME}/${dotfile}"
  local dst="${stage_home_dir}/${dotfile}"

  [ -e "$src" ] || return 1
  if repack_duplicate_item "$src" "$dst"; then
    log_dim "Included dotfile: ~/${dotfile}"
    return 0
  fi
  return 1
}

# ── Collect active & riced wallpapers into staging dir ─────────────────────────
repack_collect_wallpapers() {
  local stage_wp_dir="$1" format="$2" primary_wp="${3:-}"
  local count=0
  mkdir -p "$stage_wp_dir"

  # 1. Primary / active wallpaper
  if [ -n "$primary_wp" ] && [ -f "$primary_wp" ]; then
    local wp_name
    wp_name=$(basename "$primary_wp")
    cp -L "$primary_wp" "${stage_wp_dir}/${wp_name}" 2>/dev/null || cp "$primary_wp" "${stage_wp_dir}/${wp_name}" 2>/dev/null || true
    ((count++))
  fi

  # 2. Rice theme wallpapers
  case "$format" in
    omarchy)
      if [ -d "${HOME}/.config/omarchy/backgrounds" ]; then
        while IFS= read -r -d '' wfile; do
          local bname
          bname=$(basename "$wfile")
          [ -f "${stage_wp_dir}/${bname}" ] && continue
          cp -L "$wfile" "${stage_wp_dir}/${bname}" 2>/dev/null || true
          ((count++))
          [ "$count" -ge 25 ] && break
        done < <(find "${HOME}/.config/omarchy/backgrounds" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
      fi
      ;;
    caelestia)
      if [ -d "${HOME}/.local/share/caelestia/wallpapers" ]; then
        while IFS= read -r -d '' wfile; do
          local bname
          bname=$(basename "$wfile")
          [ -f "${stage_wp_dir}/${bname}" ] && continue
          cp -L "$wfile" "${stage_wp_dir}/${bname}" 2>/dev/null || true
          ((count++))
          [ "$count" -ge 25 ] && break
        done < <(find "${HOME}/.local/share/caelestia/wallpapers" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
      fi
      ;;
    garuda)
      if [ -d "/usr/share/wallpapers/garuda-wallpapers" ]; then
        while IFS= read -r -d '' wfile; do
          local bname
          bname=$(basename "$wfile")
          [ -f "${stage_wp_dir}/${bname}" ] && continue
          cp -L "$wfile" "${stage_wp_dir}/${bname}" 2>/dev/null || true
          ((count++))
          [ "$count" -ge 25 ] && break
        done < <(find "/usr/share/wallpapers/garuda-wallpapers" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
      fi
      ;;
    cachyos)
      if [ -d "/usr/share/wallpapers/cachyos-wallpapers" ]; then
        while IFS= read -r -d '' wfile; do
          local bname
          bname=$(basename "$wfile")
          [ -f "${stage_wp_dir}/${bname}" ] && continue
          cp -L "$wfile" "${stage_wp_dir}/${bname}" 2>/dev/null || true
          ((count++))
          [ "$count" -ge 25 ] && break
        done < <(find "/usr/share/wallpapers/cachyos-wallpapers" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
      fi
      ;;
  esac

  # 3. User Wallpaper directories
  if [ "$count" -lt 10 ]; then
    for wp_dir in "${HOME}/Wallpapers" "${HOME}/Pictures/Wallpapers" "${HOME}/Pictures/Wallpaper" "${HOME}/.wallpapers"; do
      [ -d "$wp_dir" ] || continue
      while IFS= read -r -d '' wfile; do
        local bname
        bname=$(basename "$wfile")
        [ -f "${stage_wp_dir}/${bname}" ] && continue
        cp -L "$wfile" "${stage_wp_dir}/${bname}" 2>/dev/null || true
        ((count++))
        [ "$count" -ge 25 ] && break 2
      done < <(find "$wp_dir" -maxdepth 2 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) -print0 2>/dev/null)
    done
  fi

  echo "$count"
}

# ── Generate Standalone install.sh for the repacked rice ──────────────────────
repack_generate_installer() {
  local stage_dir="$1" format="$2" wm="$3"
  local script="${stage_dir}/install.sh"

  cat << 'INSTALLER_EOF' > "$script"
#!/usr/bin/env bash
# Auto-generated installer for repacked rice
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.config-backup-$(date +%Y%m%d-%H%M%S)"

echo "=== Rice Farmer — Installing Repacked Rice ==="

# 1. Back up and install .config entries (directories and files)
if [ -d "${SCRIPT_DIR}/.config" ]; then
  mkdir -p "$BACKUP_DIR/.config"
  for app_path in "${SCRIPT_DIR}/.config"/* "${SCRIPT_DIR}/.config"/.*; do
    [ -e "$app_path" ] || continue
    app=$(basename "$app_path")
    [ "$app" = "." ] || [ "$app" = ".." ] && continue

    if [ -d "$app_path" ]; then
      if [ -e "$HOME/.config/$app" ]; then
        cp -rL "$HOME/.config/$app" "$BACKUP_DIR/.config/" 2>/dev/null || true
        echo "  Backed up ~/.config/$app -> $BACKUP_DIR/.config/"
      fi
      mkdir -p "$HOME/.config/$app"
      cp -rL "$app_path"/. "$HOME/.config/$app/"
      echo "  Installed ~/.config/$app"
    elif [ -f "$app_path" ]; then
      if [ -e "$HOME/.config/$app" ]; then
        cp -L "$HOME/.config/$app" "$BACKUP_DIR/.config/" 2>/dev/null || true
        echo "  Backed up ~/.config/$app -> $BACKUP_DIR/.config/"
      fi
      mkdir -p "$HOME/.config"
      cp -L "$app_path" "$HOME/.config/$app"
      echo "  Installed ~/.config/$app"
    fi
  done
fi

# 2. Back up and install home dotfiles (e.g. .bashrc, .zshrc, .vimrc, .tmux.conf)
if [ -d "${SCRIPT_DIR}/home" ]; then
  mkdir -p "$BACKUP_DIR/home"
  for dot_path in "${SCRIPT_DIR}/home"/* "${SCRIPT_DIR}/home"/.*; do
    [ -e "$dot_path" ] || continue
    dot=$(basename "$dot_path")
    [ "$dot" = "." ] || [ "$dot" = ".." ] && continue

    if [ -e "$HOME/$dot" ]; then
      cp -rL "$HOME/$dot" "$BACKUP_DIR/home/" 2>/dev/null || true
      echo "  Backed up ~/$dot -> $BACKUP_DIR/home/"
    fi
    if [ -d "$dot_path" ]; then
      mkdir -p "$HOME/$dot"
      cp -rL "$dot_path"/. "$HOME/$dot/"
      echo "  Installed ~/$dot"
    elif [ -f "$dot_path" ]; then
      cp -L "$dot_path" "$HOME/$dot"
      echo "  Installed ~/$dot"
    fi
  done
fi

# 3. Install wallpapers
if [ -d "${SCRIPT_DIR}/wallpapers" ]; then
  mkdir -p "$HOME/Pictures/Wallpapers"
  cp -rL "${SCRIPT_DIR}/wallpapers"/* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
  echo "  Wallpapers copied to ~/Pictures/Wallpapers/"
fi

# 4. Reload environment if supported
if command -v hyprctl &>/dev/null; then
  hyprctl reload 2>/dev/null || true
elif command -v swaymsg &>/dev/null; then
  swaymsg reload 2>/dev/null || true
fi

# 5. Set wallpaper if swww/feh is available
if [ -d "${SCRIPT_DIR}/wallpapers" ]; then
  first_wp=$(find "${SCRIPT_DIR}/wallpapers" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -1)
  if [ -n "$first_wp" ]; then
    target_wp="$HOME/Pictures/Wallpapers/$(basename "$first_wp")"
    if command -v swww &>/dev/null && swww query &>/dev/null; then
      swww img "$target_wp" 2>/dev/null || true
    elif command -v feh &>/dev/null; then
      feh --bg-fill "$target_wp" 2>/dev/null || true
    fi
  fi
fi

# 6. Reload systemd user services if present
if [ -d "${SCRIPT_DIR}/.config/systemd/user" ] && command -v systemctl &>/dev/null; then
  systemctl --user daemon-reload 2>/dev/null || true
  echo "  Reloaded systemd user daemon."
fi

INSTALLER_EOF

  # Format-specific post-install hooks in install.sh
  case "$format" in
    omarchy)
      cat << 'OMARCHY_HOOK' >> "$script"
if command -v omarchy-version &>/dev/null || [ -d "$HOME/.config/omarchy" ]; then
  echo "  Restored Omarchy ecosystem configurations."
fi
OMARCHY_HOOK
      ;;
    caelestia)
      cat << 'CAELESTIA_HOOK' >> "$script"
if command -v ags &>/dev/null; then
  ags -q 2>/dev/null || true
  nohup ags >/dev/null 2>&1 &
  echo "  Restarted Caelestia AGS widgets."
fi
CAELESTIA_HOOK
      ;;
    garuda)
      cat << 'GARUDA_HOOK' >> "$script"
echo "  Restored Garuda desktop configuration."
GARUDA_HOOK
      ;;
  esac

  echo 'echo "Rice applied successfully!"' >> "$script"
  chmod +x "$script"
}

# ── Create Zip File (zip binary or python3 fallback) ───────────────────────────
repack_create_zip() {
  local stage_dir="$1" output_zip="$2"

  mkdir -p "$(dirname "$output_zip")"
  rm -f "$output_zip"

  if command -v zip &>/dev/null; then
    (cd "$stage_dir" && zip -r -q "$output_zip" .)
    return 0
  elif command -v python3 &>/dev/null; then
    python3 -c "
import zipfile, os, sys
stage = sys.argv[1]
out = sys.argv[2]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(stage):
        for f in files:
            fp = os.path.join(root, f)
            rp = os.path.relpath(fp, stage)
            zf.write(fp, rp)
" "$stage_dir" "$output_zip"
    return 0
  elif command -v python &>/dev/null; then
    python -c "
import zipfile, os, sys
stage = sys.argv[1]
out = sys.argv[2]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
    for root, dirs, files in os.walk(stage):
        for f in files:
            fp = os.path.join(root, f)
            rp = os.path.relpath(fp, stage)
            zf.write(fp, rp)
" "$stage_dir" "$output_zip"
    return 0
  else
    die "Cannot create zip archive: neither 'zip' nor 'python3' is installed."
  fi
}

# ── Main Repack Orchestrator ──────────────────────────────────────────────────
run_repack() {
  local target_zip="${1:-}"
  local format
  format=$(repack_resolve_format)

  log_step "Repacking system configuration (Format: ${BOLD}${format}${RESET})..."

  local stage_dir
  stage_dir=$(mktemp -d /tmp/ricer-repack-XXXXXX)
  # shellcheck disable=SC2064
  trap "rm -rf '$stage_dir'" RETURN

  local stage_cfg="${stage_dir}/.config"
  local stage_home="${stage_dir}/home"
  local stage_wp="${stage_dir}/wallpapers"
  mkdir -p "$stage_cfg" "$stage_home" "$stage_wp"

  local -a included_apps=()
  local -a included_dots=()

  # ── 1. Target config definitions ────────────────────────────────────────────
  local -a format_cfg_targets=()
  case "$format" in
    omarchy)
      log_info "Collecting Omarchy desktop stack, keybinds & terminal configs..."
      format_cfg_targets=(
        omarchy hypr herdr waybar mako foot kitty alacritty ghostty wezterm rio
        nvim helix micro emacs
        tmux zellij fish starship.toml
        fastfetch cava btop lazygit spicetify imv mpv
        fcitx5 fontconfig gtk-3.0 gtk-4.0 mimeapps.list
        wireplumber environment.d git systemd
        user-dirs.dirs xdg-terminals.list
      )
      ;;
    caelestia)
      log_info "Collecting Caelestia desktop stack, keybinds & terminal configs..."
      format_cfg_targets=(
        caelestia ags hypr waybar rofi wofi dunst mako swaync
        kitty alacritty ghostty foot wezterm rio
        nvim helix micro emacs
        tmux zellij fish starship.toml
        fastfetch cava btop lazygit spicetify imv mpv
        fcitx5 fontconfig gtk-3.0 gtk-4.0 mimeapps.list
        wireplumber environment.d git systemd
        user-dirs.dirs xdg-terminals.list
      )
      ;;
    garuda)
      log_info "Collecting Garuda desktop stack, keybinds & terminal configs..."
      format_cfg_targets=(
        garuda hypr waybar fish swaync dunst rofi wofi
        alacritty kitty ghostty foot wezterm rio
        nvim helix micro emacs
        tmux zellij starship.toml
        fastfetch cava btop lazygit spicetify imv mpv
        fcitx5 fontconfig gtk-3.0 gtk-4.0 mimeapps.list
        wireplumber environment.d git systemd
        user-dirs.dirs xdg-terminals.list
      )
      ;;
    *)
      log_info "Collecting standard desktop configurations, keybinds & terminals..."
      format_cfg_targets=(
        hypr sway i3 bspwm sxhkd river awesome qtile labwc niri wayfire.ini xbindkeys
        kglobalshortcutsrc kwinrc xfce4
        waybar ags eww polybar rofi wofi walker fuzzel tofi dunst mako swaync tint2
        kitty alacritty foot ghostty wezterm rio terminator
        nvim helix micro emacs
        tmux zellij fish starship.toml
        fastfetch cava btop lazygit spicetify imv mpv
        fcitx5 fontconfig gtk-3.0 gtk-4.0 mimeapps.list
        wireplumber environment.d git systemd
        user-dirs.dirs xdg-terminals.list
      )
      ;;
  esac

  # Universal essentials: guarantee editors (Vim/NVim), terminals, shells, and OS hotkeys are checked across all formats
  local -a universal_essentials=(
    nvim helix micro emacs
    kitty alacritty foot ghostty wezterm rio terminator
    tmux zellij fish starship.toml
    sxhkd xbindkeys
    imv mpv wireplumber environment.d git
    user-dirs.dirs xdg-terminals.list
  )

  # Combine and deduplicate
  local -a all_cfg_targets=("${format_cfg_targets[@]}")
  for app in "${universal_essentials[@]}"; do
    local exists=0
    for e in "${all_cfg_targets[@]}"; do
      [ "$e" = "$app" ] && exists=1 && break
    done
    [ "$exists" -eq 0 ] && all_cfg_targets+=("$app")
  done

  # Process .config items
  for app in "${all_cfg_targets[@]}"; do
    if repack_copy_app_config "$app" "$stage_cfg"; then
      included_apps+=("$app")
    fi
  done

  # ── 2. Collect Home Dotfiles (Vim, Shell, Multiplexer, Readline) ─────────────
  log_info "Collecting home dotfiles and editor configs (Vim, Shells, Keybinds)..."
  local -a home_targets=(
    .bashrc .bash_profile .bash_aliases .bash_logout .blerc
    .zshrc .zshenv .zprofile
    .vimrc .vim
    .tmux.conf
    .inputrc
    .xbindkeysrc
    .Xresources .Xdefaults
    .wezterm.lua
    .profile
    .gtkrc-2.0
  )

  for dot in "${home_targets[@]}"; do
    if repack_copy_home_dotfile "$dot" "$stage_home"; then
      included_dots+=("$dot")
    fi
  done

  # ── 3. Active Wallpaper & Themes Collection ──────────────────────────────────
  log_info "Searching for desktop wallpaper and rice backgrounds..."
  local active_wp
  active_wp=$(repack_find_wallpaper "$format")
  local wallpaper_filename=""
  [ -n "$active_wp" ] && [ -f "$active_wp" ] && wallpaper_filename=$(basename "$active_wp")

  local wp_count
  wp_count=$(repack_collect_wallpapers "$stage_wp" "$format" "$active_wp")
  log_ok "Captured ${wp_count} wallpaper file(s) into package."

  # ── 4. Dereference all symlinks: Duplicate full files ─────────────────────────
  log_info "Verifying file duplication and dereferencing symlinks..."
  repack_dereference_all "$stage_dir"

  # Count total files inside package
  local total_files
  total_files=$(find "$stage_dir" -type f | wc -l)

  # ── 5. Manifest and Installer Generation ────────────────────────────────────
  local detected_wm="${RICER_WM:-unknown}"
  repack_generate_installer "$stage_dir" "$format" "$detected_wm"

  # Manifest JSON
  local apps_json dots_json
  apps_json=$(printf '%s\n' "${included_apps[@]}" | jq -R . | jq -s .)
  dots_json=$(printf '%s\n' "${included_dots[@]}" | jq -R . | jq -s .)

  jq -n \
    --arg name "${format}-rice-repack" \
    --arg format "$format" \
    --arg wm "$detected_wm" \
    --arg wp "$wallpaper_filename" \
    --argjson wp_count "$wp_count" \
    --argjson total_files "$total_files" \
    --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson apps "$apps_json" \
    --argjson dots "$dots_json" \
    '{
      name: $name,
      format: $format,
      wm: $wm,
      wallpaper: $wp,
      wallpaper_count: $wp_count,
      total_files: $total_files,
      captured_at: $time,
      generator: "Rice Farmer repack",
      included_configs: $apps,
      home_dotfiles: $dots
    }' > "${stage_dir}/rice.json"

  # README.md
  cat << README_EOF > "${stage_dir}/README.md"
# Repacked Rice (${format})

This rice package was automatically extracted and packaged by **Rice Farmer** (\`ricer repack\`).
All files, keybinds, terminal profiles, and wallpapers are duplicated with full contents (no broken symlinks).

## Overview
- **Format**: ${format}
- **Window Manager**: ${detected_wm}
- **Captured At**: $(date)
- **Active Wallpaper**: ${wallpaper_filename:-"(none)"}
- **Total Wallpapers**: ${wp_count}
- **Total Data Files**: ${total_files}
- **Included Configs**: ${included_apps[*]}
- **Home Dotfiles**: ${included_dots[*]}

## Installation
To install this rice on any Linux machine with Rice Farmer:
\`\`\`bash
ricer install <path-to-this-zip>
\`\`\`

Or run the self-contained installer script directly from the extracted archive:
\`\`\`bash
chmod +x install.sh && ./install.sh
\`\`\`
README_EOF

  # ── 6. Target ZIP path resolution (saved in Downloads folder) ────────────────
  local downloads_dir="${XDG_DOWNLOAD_DIR:-${HOME}/Downloads}"
  if [ -z "$target_zip" ]; then
    mkdir -p "$downloads_dir"
    target_zip="${downloads_dir}/rice-repack-${format}-$(date +%Y%m%d-%H%M%S).zip"
  else
    target_zip="${target_zip/#\~/$HOME}"
    if [[ "$target_zip" != */* ]]; then
      mkdir -p "$downloads_dir"
      target_zip="${downloads_dir}/${target_zip}"
    fi
  fi
  [[ "$target_zip" =~ \.zip$ ]] || target_zip="${target_zip}.zip"

  log_info "Compressing rice package into ${target_zip}..."
  repack_create_zip "$stage_dir" "$target_zip"

  local zip_size
  zip_size=$(du -h "$target_zip" 2>/dev/null | cut -f1 || echo "unknown")

  echo ""
  log_ok "${BOLD}Rice successfully repacked with complete data!${RESET}"
  echo "--------------------------------------------------------"
  printf "  ${CYAN}%-18s${RESET} : %s\n" "Format" "$format"
  printf "  ${CYAN}%-18s${RESET} : %s\n" "Window Manager" "$detected_wm"
  printf "  ${CYAN}%-18s${RESET} : %s\n" "Configs Saved" "${#included_apps[@]} in ~/.config"
  printf "  ${CYAN}%-18s${RESET} : %s\n" "Home Dotfiles" "${#included_dots[@]} in ~/"
  printf "  ${CYAN}%-18s${RESET} : %s\n" "Wallpapers" "${wp_count} captured (active: ${wallpaper_filename:-none})"
  printf "  ${CYAN}%-18s${RESET} : %s\n" "Total Real Files" "$total_files (duplicated, dereferenced)"
  printf "  ${CYAN}%-18s${RESET} : %s (%s)\n" "Output Archive" "$target_zip" "$zip_size"
  echo "--------------------------------------------------------"
  echo ""
  log_info "You can now share this zip file, upload it to GitHub, or install it on another system with:"
  echo -e "    ${BOLD}ricer install ${target_zip}${RESET}"
  echo ""
}
