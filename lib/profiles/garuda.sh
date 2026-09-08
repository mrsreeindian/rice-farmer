#!/usr/bin/env bash
# lib/profiles/garuda.sh — Garuda Linux pre-rice configuration profile

profile_garuda_detect() {
  if [ -n "${RICER_DISTRO:-}" ] && [ "$RICER_DISTRO" != "garuda" ]; then
    return 1
  fi
  [ "${RICER_DISTRO:-}" = "garuda" ] \
    || [ -f /etc/garuda-release ] \
    || [ -d /usr/share/garuda ] \
    || [ -d "${HOME}/.config/garuda" ]
}

profile_garuda_name() {
  echo "Garuda Linux (Dr460nized & Sweet Theme Environment)"
}

profile_garuda_conflicts() {
  local repo_dir="$1"
  local conflicts=()

  if [ -d "$repo_dir/hypr" ] || [ -d "$repo_dir/hyprland" ] || [ -d "$repo_dir/.config/hypr" ]; then
    conflicts+=("Hyprland config: Garuda dr460nized configs & sweet themes will be safely backed up")
  fi

  if pgrep -x "latte-dock" &>/dev/null; then
    conflicts+=("Dock/Bar: Active latte-dock conflicts with incoming rice bar")
  fi

  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    conflicts+=("Status bar: Garuda Waybar configs will be replaced by incoming rice")
  fi

  if [ -d "${HOME}/.config/autostart" ]; then
    conflicts+=("Autostart services: Garuda system autostarts will be analyzed and isolated")
  fi

  printf '%s\n' "${conflicts[@]}"
}

profile_garuda_resolution_steps() {
  local repo_dir="$1"
  local steps=()

  steps+=('{"type":"resolve_conflict","args":["kill_proc","latte-dock"],"description":"Stop running Latte Dock"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","waybar"],"description":"Stop running Waybar"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","dunst"],"description":"Stop existing notification daemon (dunst)"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","swaync"],"description":"Stop existing notification daemon (swaync)"}')

  if [ -d "${HOME}/.config/garuda" ]; then
    steps+=('{"type":"resolve_conflict","args":["backup_quarantine","~/.config/garuda"],"description":"Backup Garuda settings"}')
  fi

  if [ ${#steps[@]} -gt 0 ]; then
    local json
    json=$(IFS=,; echo "[${steps[*]}]")
    echo "$json"
  else
    echo "[]"
  fi
}

profile_garuda_dependencies() {
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
  if [ -d "$repo_dir/wofi" ] || [ -d "$repo_dir/.config/wofi" ]; then
    _chk wofi wofi
  fi
  if [ -d "$repo_dir/rofi" ] || [ -d "$repo_dir/.config/rofi" ]; then
    _chk rofi rofi
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
