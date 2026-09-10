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
  fallback=$(find "${HOME}/Pictures/Wallpapers" "${HOME}/Pictures/Wallpaper" "${HOME}/Pictures" "${HOME}/.wallpapers" "${HOME}/wallpapers" -maxdepth 2 -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -1)
  [ -n "$fallback" ] && [ -f "$fallback" ] && echo "$fallback" && return 0

  echo ""
}

# ── Safe Config Directory Copy (stripping credentials and cache) ──────────────
repack_copy_app_config() {
  local app="$1" stage_config_dir="$2"
  local src_dir="${HOME}/.config/${app}"
  local dst_dir="${stage_config_dir}/${app}"

  [ -d "$src_dir" ] || return 1

  mkdir -p "$dst_dir"
  # Copy files while excluding git repos, socket files, cache, and known secrets
  tar --exclude=".git" \
      --exclude=".github" \
      --exclude="*.sock" \
      --exclude="*.socket" \
      --exclude="*.log" \
      --exclude="*.cache" \
      --exclude="Cache*" \
      --exclude="cache*" \
      --exclude="*.key" \
      --exclude="*.pem" \
      --exclude="*token*" \
      --exclude="*secret*" \
      --exclude="*credential*" \
      -C "${HOME}/.config" -cf - "$app" 2>/dev/null \
    | tar -C "$stage_config_dir" -xf - 2>/dev/null || cp -rL "$src_dir" "$dst_dir" 2>/dev/null || true

  log_dim "Included config: ~/.config/${app}"
  return 0
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

# 1. Back up and install .config entries
if [ -d "${SCRIPT_DIR}/.config" ]; then
  mkdir -p "$BACKUP_DIR"
  for app_path in "${SCRIPT_DIR}/.config"/*; do
    [ -e "$app_path" ] || continue
    app=$(basename "$app_path")
    if [ -e "$HOME/.config/$app" ]; then
      cp -rP "$HOME/.config/$app" "$BACKUP_DIR/" 2>/dev/null || true
      echo "  Backed up ~/.config/$app -> $BACKUP_DIR/"
    fi
    mkdir -p "$HOME/.config/$app"
    cp -rP "$app_path"/. "$HOME/.config/$app/"
    echo "  Installed ~/.config/$app"
  done
fi

# 2. Install wallpapers
if [ -d "${SCRIPT_DIR}/wallpapers" ]; then
  mkdir -p "$HOME/Pictures/Wallpapers"
  cp -rP "${SCRIPT_DIR}/wallpapers"/* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
  echo "  Wallpapers copied to ~/Pictures/Wallpapers/"
fi

# 3. Reload environment if supported
if command -v hyprctl &>/dev/null; then
  hyprctl reload 2>/dev/null || true
elif command -v swaymsg &>/dev/null; then
  swaymsg reload 2>/dev/null || true
fi

# 4. Set wallpaper if swww/feh is available
if [ -d "${SCRIPT_DIR}/wallpapers" ]; then
  first_wp=$(find "${SCRIPT_DIR}/wallpapers" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | head -1)
  if [ -n "$first_wp" ]; then
    target_wp="$HOME/Pictures/Wallpapers/$(basename "$first_wp")"
    if command -v swww &>/dev/null && swww query &>/dev/null; then
      swww img "$target_wp" 2>/dev/null || true
    elif command -v feh &>/dev/null; then
      feh --bg-fill "$target_wp" 2>/dev/null || true
    fi
  fi
fi

# 5. Reload systemd user services if present
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
  local stage_wp="${stage_dir}/wallpapers"
  mkdir -p "$stage_cfg" "$stage_wp"

  local -a included_apps=()

  # ── 1. Format-specific collection ───────────────────────────────────────────
  case "$format" in
    omarchy)
      log_info "Collecting Omarchy desktop stack..."
      local omarchy_apps=(omarchy hypr waybar mako foot kitty fastfetch cava btop alacritty ghostty systemd)
      for app in "${omarchy_apps[@]}"; do
        if repack_copy_app_config "$app" "$stage_cfg"; then
          included_apps+=("$app")
        fi
      done
      ;;
    caelestia)
      log_info "Collecting Caelestia desktop stack..."
      local caelestia_apps=(caelestia ags hypr waybar rofi wofi dunst swaync kitty alacritty fastfetch systemd)
      for app in "${caelestia_apps[@]}"; do
        if repack_copy_app_config "$app" "$stage_cfg"; then
          included_apps+=("$app")
        fi
      done
      ;;
    garuda)
      log_info "Collecting Garuda desktop stack..."
      local garuda_apps=(garuda hypr waybar fish swaync dunst alacritty kitty fastfetch systemd)
      for app in "${garuda_apps[@]}"; do
        if repack_copy_app_config "$app" "$stage_cfg"; then
          included_apps+=("$app")
        fi
      done
      # Also check starship
      if [ -f "${HOME}/.config/starship.toml" ]; then
        cp "${HOME}/.config/starship.toml" "$stage_cfg/"
        included_apps+=("starship.toml")
      fi
      ;;
    *)
      log_info "Collecting standard desktop configurations..."
      local generic_apps=(hypr sway i3 bspwm sxhkd river awesome qtile \
                          waybar polybar eww ags \
                          mako dunst swaync \
                          rofi wofi \
                          kitty alacritty foot ghostty wezterm \
                          fastfetch cava btop fish systemd)
      for app in "${generic_apps[@]}"; do
        if repack_copy_app_config "$app" "$stage_cfg"; then
          included_apps+=("$app")
        fi
      done
      if [ -f "${HOME}/.config/starship.toml" ]; then
        cp "${HOME}/.config/starship.toml" "$stage_cfg/"
        included_apps+=("starship.toml")
      fi
      ;;
  esac

  # ── 2. Active Wallpaper Collection ──────────────────────────────────────────
  log_info "Searching for active desktop wallpaper..."
  local wallpaper_path
  wallpaper_path=$(repack_find_wallpaper "$format")
  local wallpaper_filename=""

  if [ -n "$wallpaper_path" ] && [ -f "$wallpaper_path" ]; then
    wallpaper_filename=$(basename "$wallpaper_path")
    cp "$wallpaper_path" "${stage_wp}/${wallpaper_filename}"
    log_ok "Captured wallpaper: ${wallpaper_path}"
  else
    log_warn "No active wallpaper found — skipping wallpaper capture."
  fi

  # ── 3. Manifest and Installer Generation ────────────────────────────────────
  local detected_wm="${RICER_WM:-unknown}"
  repack_generate_installer "$stage_dir" "$format" "$detected_wm"

  # Manifest JSON
  local apps_json
  apps_json=$(printf '%s\n' "${included_apps[@]}" | jq -R . | jq -s .)
  jq -n \
    --arg name "${format}-rice-repack" \
    --arg format "$format" \
    --arg wm "$detected_wm" \
    --arg wp "$wallpaper_filename" \
    --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson apps "$apps_json" \
    '{
      name: $name,
      format: $format,
      wm: $wm,
      wallpaper: $wp,
      captured_at: $time,
      generator: "Rice Farmer repack",
      included_configs: $apps
    }' > "${stage_dir}/rice.json"

  # README.md
  cat << README_EOF > "${stage_dir}/README.md"
# Repacked Rice (${format})

This rice package was automatically extracted and packaged by **Rice Farmer** (\`ricer repack\`).

## Overview
- **Format**: ${format}
- **Window Manager**: ${detected_wm}
- **Captured At**: $(date)
- **Wallpaper**: ${wallpaper_filename:-"(none)"}
- **Included Configs**: ${included_apps[*]}

## Installation
To install this rice on any Linux machine with Rice Farmer:
\`\`\`bash
ricer install <path-or-github-url>
\`\`\`

Or run the self-contained installer script directly:
\`\`\`bash
chmod +x install.sh && ./install.sh
\`\`\`
README_EOF

  # ── 4. Target ZIP path resolution ───────────────────────────────────────────
  if [ -z "$target_zip" ]; then
    target_zip="${HOME}/rice-repack-${format}-$(date +%Y%m%d-%H%M%S).zip"
  fi
  target_zip="${target_zip/#\~/$HOME}"
  # Ensure .zip extension
  [[ "$target_zip" =~ \.zip$ ]] || target_zip="${target_zip}.zip"

  log_info "Compressing rice package into ${target_zip}..."
  repack_create_zip "$stage_dir" "$target_zip"

  local zip_size
  zip_size=$(du -h "$target_zip" 2>/dev/null | cut -f1 || echo "unknown")

  echo ""
  log_ok "${BOLD}Rice successfully repacked!${RESET}"
  echo "-----------------------------------------"
  printf "  ${CYAN}%-16s${RESET} : %s\n" "Format" "$format"
  printf "  ${CYAN}%-16s${RESET} : %s\n" "Window Manager" "$detected_wm"
  printf "  ${CYAN}%-16s${RESET} : %s\n" "Configs Saved" "${#included_apps[@]} (${included_apps[*]})"
  printf "  ${CYAN}%-16s${RESET} : %s\n" "Wallpaper" "${wallpaper_filename:-none}"
  printf "  ${CYAN}%-16s${RESET} : %s (%s)\n" "Output File" "$target_zip" "$zip_size"
  echo "-----------------------------------------"
  echo ""
  log_info "You can now share this zip file, upload it to GitHub, or install it on another system with:"
  echo -e "    ${BOLD}ricer install ${target_zip}${RESET}"
  echo ""
}
