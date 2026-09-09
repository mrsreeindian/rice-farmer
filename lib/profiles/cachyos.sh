#!/usr/bin/env bash
# lib/profiles/cachyos.sh — CachyOS pre-rice configuration profile

profile_cachyos_detect() {
  [ "${RICER_DISTRO:-}" = "cachyos" ] \
    || [ -f /etc/cachyos-release ] \
    || [ -d /etc/cachyos ] \
    || [ -d "${HOME}/.config/cachyos" ]
}

profile_cachyos_name() {
  echo "CachyOS (Performance Arch with Custom Desktop Stack)"
}

profile_cachyos_conflicts() {
  local repo_dir="$1"
  local conflicts=()

  if [ -d "$repo_dir/hypr" ] || [ -d "$repo_dir/hyprland" ] || [ -d "$repo_dir/.config/hypr" ]; then
    conflicts+=("Hyprland config: CachyOS default hyprland configs & keybindings will be backed up and replaced")
  fi

  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    conflicts+=("Status bar: CachyOS custom Waybar styling will be replaced by incoming rice")
  fi

  if [ -d "$repo_dir/fish" ] || [ -d "$repo_dir/.config/fish" ]; then
    conflicts+=("Shell config: CachyOS fish configs and plugins will be preserved in backup")
  fi

  printf '%s\n' "${conflicts[@]}"
}

profile_cachyos_resolution_steps() {
  local repo_dir="$1"
  local steps=()

  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    steps+=('{"type":"resolve_conflict","args":["kill_proc","waybar"],"description":"Stop running CachyOS Waybar"}')
  fi
  if [ -d "$repo_dir/dunst" ] || [ -d "$repo_dir/.config/dunst" ] || [ -d "$repo_dir/mako" ] || [ -d "$repo_dir/swaync" ]; then
    steps+=('{"type":"resolve_conflict","args":["kill_proc","swaync"],"description":"Stop CachyOS notification center"}')
    steps+=('{"type":"resolve_conflict","args":["kill_proc","mako"],"description":"Stop existing mako daemon"}')
    steps+=('{"type":"resolve_conflict","args":["kill_proc","dunst"],"description":"Stop existing dunst daemon"}')
  fi

  if [ -d "${HOME}/.config/cachyos" ]; then
    steps+=('{"type":"resolve_conflict","args":["backup_quarantine","~/.config/cachyos"],"description":"Backup CachyOS user configs"}')
  fi

  if [ ${#steps[@]} -gt 0 ]; then
    local json
    json=$(IFS=,; echo "[${steps[*]}]")
    echo "$json"
  else
    echo "[]"
  fi
}

profile_cachyos_dependencies() {
  local repo_dir="$1"
  local -a pkgs=()

  _chk() {
    local cmd="$1" pkg="$2"
    if ! command -v "$cmd" &>/dev/null; then
      pkgs+=("$pkg")
    fi
  }

  if [ -d "$repo_dir/kitty" ] || [ -d "$repo_dir/.config/kitty" ]; then
    _chk kitty kitty
  fi
  if [ -d "$repo_dir/alacritty" ] || [ -d "$repo_dir/.config/alacritty" ]; then
    _chk alacritty alacritty
  fi
  if [ -d "$repo_dir/foot" ] || [ -d "$repo_dir/.config/foot" ]; then
    _chk foot foot
  fi
  if [ -d "$repo_dir/rofi" ] || [ -d "$repo_dir/.config/rofi" ]; then
    _chk rofi rofi
  fi
  if [ -d "$repo_dir/wofi" ] || [ -d "$repo_dir/.config/wofi" ]; then
    _chk wofi wofi
  fi
  if [ -d "$repo_dir/swww" ] || grep -rq "swww" "$repo_dir" 2>/dev/null; then
    _chk swww swww
  fi
  if [ -d "$repo_dir/hyprpaper" ] || grep -rq "hyprpaper" "$repo_dir" 2>/dev/null; then
    _chk hyprpaper hyprpaper
  fi
  if [ -d "$repo_dir/hyprlock" ] || grep -rq "hyprlock" "$repo_dir" 2>/dev/null; then
    _chk hyprlock hyprlock
  fi
  if [ -d "$repo_dir/hypridle" ] || grep -rq "hypridle" "$repo_dir" 2>/dev/null; then
    _chk hypridle hypridle
  fi

  printf '%s\n' "${pkgs[@]}"
}
