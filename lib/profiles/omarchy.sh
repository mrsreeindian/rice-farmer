#!/usr/bin/env bash
# lib/profiles/omarchy.sh — Omarchy pre-rice configuration profile

profile_omarchy_detect() {
  [ "${RICER_DISTRO:-}" = "omarchy" ] \
    || [ -d /usr/share/omarchy ] \
    || [ -d "${HOME}/.config/omarchy" ] \
    || [ -d "${HOME}/.local/share/omarchy" ] \
    || command -v omarchy-version &>/dev/null
}

profile_omarchy_name() {
  echo "Omarchy (Tailored Hyprland & Theme Ecosystem)"
}

profile_omarchy_conflicts() {
  local repo_dir="$1"
  local conflicts=()

  # Check notification daemon conflict
  if [ -d "$repo_dir/dunst" ] || [ -d "$repo_dir/.config/dunst" ] || [ -f "$repo_dir/dunstrc" ]; then
    conflicts+=("Notification daemon: Omarchy active daemon (mako) conflicts with incoming (dunst)")
  elif [ -d "$repo_dir/swaync" ] || [ -d "$repo_dir/.config/swaync" ]; then
    conflicts+=("Notification daemon: Omarchy active daemon (mako) conflicts with incoming (swaync)")
  fi

  # Check window manager / Hyprland config conflict
  if [ -d "$repo_dir/hypr" ] || [ -d "$repo_dir/hyprland" ] || [ -d "$repo_dir/.config/hypr" ]; then
    if [ -f "${HOME}/.config/hypr/omarchy.conf" ] || [ -f "${HOME}/.config/hypr/hyprland.conf" ]; then
      conflicts+=("Hyprland config: Omarchy hyprland configs & theme-set hooks will be isolated to avoid binding collisions")
    fi
  fi

  # Check status bar conflict
  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    conflicts+=("Status bar: Omarchy default waybar modules will be replaced by incoming rice")
  fi

  # Check terminal conflict
  if [ -d "$repo_dir/kitty" ] || [ -d "$repo_dir/.config/kitty" ]; then
    if [ -f "${HOME}/.config/foot/foot.ini" ]; then
      conflicts+=("Terminal: Omarchy default (foot) vs incoming rice (kitty)")
    fi
  fi

  printf '%s\n' "${conflicts[@]}"
}

profile_omarchy_resolution_steps() {
  local repo_dir="$1"
  local steps=()

  # Stop conflicting daemons
  if [ -d "$repo_dir/dunst" ] || [ -d "$repo_dir/.config/dunst" ] || [ -f "$repo_dir/dunstrc" ]; then
    steps+=('{"type":"resolve_conflict","args":["kill_proc","mako"],"description":"Stop conflicting Omarchy mako daemon"}')
  fi
  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    steps+=('{"type":"resolve_conflict","args":["kill_proc","waybar"],"description":"Stop running Waybar before config replacement"}')
  fi

  # Quarantine Omarchy specific hypr includes
  if [ -f "${HOME}/.config/hypr/omarchy.conf" ]; then
    steps+=('{"type":"resolve_conflict","args":["quarantine_file","~/.config/hypr/omarchy.conf"],"description":"Backup & isolate Omarchy hyprland include"}')
  fi

  # Isolate Omarchy auto-theme switcher to prevent overriding the new rice
  if [ -d "${HOME}/.config/omarchy" ]; then
    steps+=('{"type":"resolve_conflict","args":["backup_quarantine","~/.config/omarchy"],"description":"Backup Omarchy theme config"}')
  fi

  if [ ${#steps[@]} -gt 0 ]; then
    local json
    json=$(IFS=,; echo "[${steps[*]}]")
    echo "$json"
  else
    echo "[]"
  fi
}

profile_omarchy_dependencies() {
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
  if [ -d "$repo_dir/dunst" ] || [ -d "$repo_dir/.config/dunst" ]; then
    _chk dunst dunst
  fi
  if [ -d "$repo_dir/swaync" ] || [ -d "$repo_dir/.config/swaync" ]; then
    _chk swaync swaync
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
