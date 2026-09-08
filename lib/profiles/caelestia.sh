#!/usr/bin/env bash
# lib/profiles/caelestia.sh — Caelestia pre-rice configuration profile

profile_caelestia_detect() {
  [ -d "${HOME}/.config/caelestia" ] \
    || [ -d "${HOME}/.local/share/caelestia" ] \
    || command -v caelestia &>/dev/null
}

profile_caelestia_name() {
  echo "Caelestia (AGS / Aylur GTK Shell & Hyprland Rice)"
}

profile_caelestia_conflicts() {
  local repo_dir="$1"
  local conflicts=()

  # Caelestia runs AGS as its bar and notification center
  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    conflicts+=("Status bar: Active Caelestia AGS daemon conflicts with incoming Waybar (AGS must be stopped)")
  fi

  if [ -d "$repo_dir/dunst" ] || [ -d "$repo_dir/.config/dunst" ] || [ -d "$repo_dir/mako" ] || [ -d "$repo_dir/.config/mako" ]; then
    conflicts+=("Notification daemon: Caelestia AGS notification daemon conflicts with incoming notification system")
  fi

  if [ -d "$repo_dir/hypr" ] || [ -d "$repo_dir/hyprland" ] || [ -d "$repo_dir/.config/hypr" ]; then
    conflicts+=("Hyprland config: Caelestia hyprland scripts & autostarts will be safely backed up")
  fi

  printf '%s\n' "${conflicts[@]}"
}

profile_caelestia_resolution_steps() {
  local repo_dir="$1"
  local steps=()

  steps+=('{"type":"resolve_conflict","args":["kill_proc","ags"],"description":"Stop running Caelestia AGS daemon"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","waybar"],"description":"Stop running Waybar"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","swaync"],"description":"Stop running swaync"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","mako"],"description":"Stop running mako"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","dunst"],"description":"Stop running dunst"}')

  if [ -d "${HOME}/.config/caelestia" ]; then
    steps+=('{"type":"resolve_conflict","args":["backup_quarantine","~/.config/caelestia"],"description":"Backup Caelestia settings"}')
  fi
  if [ -d "${HOME}/.config/ags" ]; then
    steps+=('{"type":"resolve_conflict","args":["backup_quarantine","~/.config/ags"],"description":"Backup existing AGS configuration"}')
  fi

  if [ ${#steps[@]} -gt 0 ]; then
    local json
    json=$(IFS=,; echo "[${steps[*]}]")
    echo "$json"
  else
    echo "[]"
  fi
}

profile_caelestia_dependencies() {
  local repo_dir="$1"
  local -a pkgs=()

  _chk() {
    local cmd="$1" pkg="$2"
    if ! command -v "$cmd" &>/dev/null; then
      pkgs+=("$pkg")
    fi
  }

  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    _chk waybar waybar
  fi
  if [ -d "$repo_dir/wofi" ] || [ -d "$repo_dir/.config/wofi" ]; then
    _chk wofi wofi
  fi
  if [ -d "$repo_dir/rofi" ] || [ -d "$repo_dir/.config/rofi" ]; then
    _chk rofi rofi
  fi
  if [ -d "$repo_dir/kitty" ] || [ -d "$repo_dir/.config/kitty" ]; then
    _chk kitty kitty
  fi
  if [ -d "$repo_dir/alacritty" ] || [ -d "$repo_dir/.config/alacritty" ]; then
    _chk alacritty alacritty
  fi
  if [ -d "$repo_dir/dunst" ] || [ -d "$repo_dir/.config/dunst" ]; then
    _chk dunst dunst
  fi
  if [ -d "$repo_dir/mako" ] || [ -d "$repo_dir/.config/mako" ]; then
    _chk mako mako
  fi
  if [ -d "$repo_dir/hyprpaper" ] || grep -rq "hyprpaper" "$repo_dir" 2>/dev/null; then
    _chk hyprpaper hyprpaper
  fi
  if [ -d "$repo_dir/swww" ] || grep -rq "swww" "$repo_dir" 2>/dev/null; then
    _chk swww swww
  fi

  printf '%s\n' "${pkgs[@]}"
}
