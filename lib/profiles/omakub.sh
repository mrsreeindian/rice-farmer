#!/usr/bin/env bash
# lib/profiles/omakub.sh — Omakub pre-rice configuration profile

profile_omakub_detect() {
  [ -d "${HOME}/.local/share/omakub" ] \
    || [ -d "${HOME}/.config/omakub" ] \
    || command -v omakub &>/dev/null
}

profile_omakub_name() {
  echo "Omakub (Ubuntu Developer Environment)"
}

profile_omakub_conflicts() {
  local repo_dir="$1"
  local conflicts=()

  if [ -f "$repo_dir/.bashrc" ] || [ -f "$repo_dir/bashrc" ]; then
    conflicts+=("Shell config: Omakub ~/.bashrc sourcing will be backed up to ~/.bashrc.omakub.bak")
  fi

  if [ -d "$repo_dir/alacritty" ] || [ -d "$repo_dir/.config/alacritty" ]; then
    conflicts+=("Terminal config: Omakub alacritty theme setup will be preserved in backup")
  fi

  if [ -d "$repo_dir/hypr" ] || [ -d "$repo_dir/.config/hypr" ]; then
    conflicts+=("Hyprland config: Omakub Hyprland desktop will be replaced by incoming rice")
  fi

  printf '%s\n' "${conflicts[@]}"
}

profile_omakub_resolution_steps() {
  local repo_dir="$1"
  local steps=()

  if [ -f "$repo_dir/.bashrc" ] || [ -f "$repo_dir/bashrc" ]; then
    steps+=('{"type":"resolve_conflict","args":["backup_quarantine","~/.bashrc"],"description":"Backup Omakub .bashrc"}')
  fi

  steps+=('{"type":"resolve_conflict","args":["kill_proc","waybar"],"description":"Stop running Waybar"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","mako"],"description":"Stop running mako"}')
  steps+=('{"type":"resolve_conflict","args":["kill_proc","dunst"],"description":"Stop running dunst"}')

  if [ ${#steps[@]} -gt 0 ]; then
    local json
    json=$(IFS=,; echo "[${steps[*]}]")
    echo "$json"
  else
    echo "[]"
  fi
}

profile_omakub_dependencies() {
  local repo_dir="$1"
  local -a pkgs=()

  _chk() {
    local cmd="$1" pkg="$2"
    if ! command -v "$cmd" &>/dev/null; then
      pkgs+=("$pkg")
    fi
  }

  # Debian / Ubuntu package mapping
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
  if [ -d "$repo_dir/waybar" ] || [ -d "$repo_dir/.config/waybar" ]; then
    _chk waybar waybar
  fi
  if [ -d "$repo_dir/dunst" ] || [ -d "$repo_dir/.config/dunst" ]; then
    _chk dunst dunst
  fi
  if [ -d "$repo_dir/mako" ] || [ -d "$repo_dir/.config/mako" ]; then
    _chk mako mako-notifier
  fi

  printf '%s\n' "${pkgs[@]}"
}
