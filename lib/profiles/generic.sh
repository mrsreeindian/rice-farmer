#!/usr/bin/env bash
# lib/profiles/generic.sh — Generic pre-rice / active rice configuration profile

profile_generic_detect() {
  [ -d "${HOME}/.config/hyprdots" ] \
    || [ -d "${HOME}/.local/lib/hyprdots" ] \
    || [ -d "${HOME}/.config/illogical-impulse" ]
}

profile_generic_name() {
  if [ -d "${HOME}/.config/hyprdots" ]; then
    echo "Hyprdots (Pre-rice System)"
  elif [ -d "${HOME}/.config/illogical-impulse" ]; then
    echo "End_4 / Illogical-Impulse (Pre-rice System)"
  else
    echo "Pre-Rice / Existing Rice Environment"
  fi
}

profile_generic_conflicts() {
  local repo_dir="$1"
  local conflicts=()

  # Detect conflicting running daemons
  if [ -d "$repo_dir/dunst" ] || [ -d "$repo_dir/.config/dunst" ]; then
    if pgrep -x "mako" &>/dev/null; then
      conflicts+=("Notification daemon: Active mako conflicts with incoming dunst")
    elif pgrep -x "swaync" &>/dev/null; then
      conflicts+=("Notification daemon: Active swaync conflicts with incoming dunst")
    fi
  fi

  if [ -d "$repo_dir/mako" ] || [ -d "$repo_dir/.config/mako" ]; then
    if pgrep -x "dunst" &>/dev/null; then
      conflicts+=("Notification daemon: Active dunst conflicts with incoming mako")
    elif pgrep -x "swaync" &>/dev/null; then
      conflicts+=("Notification daemon: Active swaync conflicts with incoming mako")
    fi
  fi

  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    if pgrep -x "polybar" &>/dev/null; then
      conflicts+=("Status bar: Active polybar conflicts with incoming waybar")
    elif pgrep -x "ags" &>/dev/null; then
      conflicts+=("Status bar: Active ags conflicts with incoming waybar")
    fi
  fi

  printf '%s\n' "${conflicts[@]}"
}

profile_generic_resolution_steps() {
  local repo_dir="$1"
  local steps=()

  # Stop conflicting daemons
  for p in dunst mako swaync waybar polybar ags eww swww-daemon hyprpaper; do
    if pgrep -x "$p" &>/dev/null; then
      steps+=("{\"type\":\"resolve_conflict\",\"args\":[\"kill_proc\",\"$p\"],\"description\":\"Stop conflicting active daemon: $p\"}")
    fi
  done

  if [ ${#steps[@]} -gt 0 ]; then
    local json
    json=$(IFS=,; echo "[${steps[*]}]")
    echo "$json"
  else
    echo "[]"
  fi
}

profile_generic_dependencies() {
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
  if [ -d "$repo_dir/rofi" ] || [ -d "$repo_dir/.config/rofi" ]; then
    _chk rofi rofi
  fi
  if [ -d "$repo_dir/wofi" ] || [ -d "$repo_dir/.config/wofi" ]; then
    _chk wofi wofi
  fi

  printf '%s\n' "${pkgs[@]}"
}
