#!/usr/bin/env bash
# lib/rules.sh — Offline rule engine for common rice repo patterns

# Returns a JSON plan array (printed to stdout) based on repo structure.
# Falls back gracefully if no known pattern is detected.
rules_detect_plan() {
  local repo_dir="$1"
  local plan=""

  # ── Pattern 1: explicit install/setup/bootstrap script ──────────────────────
  for script in install.sh setup.sh bootstrap.sh install setup bootstrap rice.sh deploy.sh; do
    if [ -f "$repo_dir/$script" ]; then
      log_dim "Rule: found $script"
      plan=$(jq -cn --arg s "./$script" \
        '[{"type":"run_cmd","args":[$s],"description":"Run repo install script"}]')
      echo "$plan"; return 0
    fi
  done

  # ── Pattern 2: chezmoi ───────────────────────────────────────────────────────
  if [ -d "$repo_dir/.chezmoi" ] \
     || find "$repo_dir" -maxdepth 1 -name 'dot_*' | grep -q .; then
    log_dim "Rule: chezmoi layout"
    plan=$(jq -cn '[
      {"type":"install_pkg","args":["chezmoi"],"description":"Install chezmoi"},
      {"type":"run_cmd","args":["chezmoi apply --source ."],"description":"Apply chezmoi dotfiles"}
    ]')
    echo "$plan"; return 0
  fi

  # ── Pattern 3: GNU Stow layout ───────────────────────────────────────────────
  # Stow repos have subdirs whose contents mirror $HOME
  local stow_indicator=0
  if [ -f "$repo_dir/.stow-local-ignore" ]; then
    stow_indicator=1
  else
    # Heuristic: ≥2 subdirs each containing dotfiles or .config
    local subdirs=0
    while IFS= read -r -d '' d; do
      if find "$d" -maxdepth 2 \( -name '.*' -o -name '.config' \) | grep -q .; then
        ((subdirs++))
      fi
    done < <(find "$repo_dir" -mindepth 1 -maxdepth 1 -type d \
               ! -name '.git' -print0)
    [ "$subdirs" -ge 2 ] && stow_indicator=1
  fi
  if [ "$stow_indicator" -eq 1 ]; then
    log_dim "Rule: GNU Stow layout"
    plan=$(jq -cn '[
      {"type":"install_pkg","args":["stow"],"description":"Install GNU Stow"},
      {"type":"stow","args":["."],"description":"Stow all packages to home directory"}
    ]')
    echo "$plan"; return 0
  fi

  # ── Pattern 4: bare git repo (yadm / home-manager style) ─────────────────────
  if [ -f "$repo_dir/.gitconfig" ] \
     || ([ -f "$repo_dir/.git/config" ] \
         && grep -q 'bare = true' "$repo_dir/.git/config" 2>/dev/null); then
    log_dim "Rule: bare git repo"
    plan=$(jq -cn --arg r "$repo_dir" '[
      {"type":"run_cmd",
       "args":["git --git-dir=\"$REPO_DIR/.git\" --work-tree=\"$HOME\" checkout -f"],
       "description":"Check out bare git repo into home directory"}
    ]' | sed "s|\\\$REPO_DIR|$repo_dir|g")
    echo "$plan"; return 0
  fi

  # ── Pattern 5: plain .config directory ───────────────────────────────────────
  # ── Pattern 5: .config directory present ─────────────────────────────────────
  if [ -d "$repo_dir/.config" ]; then
    log_dim "Rule: .config directory detected"
    local config_steps=()
    while IFS= read -r -d '' cdir; do
      local bname
      bname=$(basename "$cdir")
      config_steps+=("{\"type\":\"copy\",\"args\":[\".config/$bname\",\"~/.config/$bname\"],\"description\":\"Install $bname config\"}")
    done < <(find "$repo_dir/.config" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    if [ ${#config_steps[@]} -gt 0 ]; then
      local json_steps
      json_steps=$(IFS=,; echo "[${config_steps[*]}]")
      echo "$json_steps"; return 0
    else
      plan=$(jq -cn '[{"type":"copy","args":[".config","~/.config"],"description":"Copy .config into home"}]')
      echo "$plan"; return 0
    fi
  fi

  # ── Pattern 6: dotfiles at repo root (files starting with .) ─────────────────
  local dotfiles=0
  while IFS= read -r -d '' f; do
    ((dotfiles++))
  done < <(find "$repo_dir" -maxdepth 1 -name '.*' \
             ! -name '.git' ! -name '.gitignore' -print0 2>/dev/null)
  if [ "$dotfiles" -ge 2 ]; then
    log_dim "Rule: dotfiles at repo root"
    plan=$(jq -cn '[
      {"type":"copy","args":[".","~/"],"description":"Copy dotfiles to home directory"}
    ]')
    echo "$plan"; return 0
  fi

  # ── Pattern 7: app config folders at repo root (e.g. hypr, nvim, waybar, kitty) ───
  local common_apps=(hypr hyprland sway i3 waybar rofi wofi kitty alacritty foot wezterm \
                     nvim neovim fish zsh tmux dunst mako polybar fastfetch btop cava)
  local found_app_steps=()
  for app in "${common_apps[@]}"; do
    if [ -d "$repo_dir/$app" ]; then
      found_app_steps+=("{\"type\":\"copy\",\"args\":[\"$app\",\"~/.config/$app\"],\"description\":\"Install $app config to ~/.config/$app\"}")
    fi
  done
  if [ ${#found_app_steps[@]} -gt 0 ]; then
    log_dim "Rule: recognized app config directories at root"
    local json_app_steps
    json_app_steps=$(IFS=,; echo "[${found_app_steps[*]}]")
    echo "$json_app_steps"; return 0
  fi

  # ── Pattern 8: any subdirectories (generic config copy) ──────────────────────
  local generic_steps=()
  while IFS= read -r -d '' gdir; do
    local gname
    gname=$(basename "$gdir")
    case "$gname" in
      .git|.github|tests|docs|pictures|wallpapers|assets) ;;
      *)
        generic_steps+=("{\"type\":\"copy\",\"args\":[\"$gname\",\"~/.config/$gname\"],\"description\":\"Install $gname to ~/.config/$gname\"}")
        ;;
    esac
  done < <(find "$repo_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

  if [ ${#generic_steps[@]} -gt 0 ]; then
    log_dim "Rule: installing root config folders to ~/.config"
    local json_generic_steps
    json_generic_steps=$(IFS=,; echo "[${generic_steps[*]}]")
    echo "$json_generic_steps"; return 0
  fi

  # ── Unknown pattern ───────────────────────────────────────────────────────────
  log_warn "No config files or recognized structures found in repository."
  echo "[]"
  return 1
}
