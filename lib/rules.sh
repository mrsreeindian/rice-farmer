#!/usr/bin/env bash
# lib/rules.sh — Offline rule engine for common rice repo patterns

## ── Barebones WM & Infrastructure detection ──────────────────────────────────
rules_detect_target_wm() {
  local repo_dir="$1"
  if [ -d "$repo_dir/hypr" ] || [ -d "$repo_dir/hyprland" ] \
     || [ -d "$repo_dir/.config/hypr" ] || [ -d "$repo_dir/.config/hyprland" ] \
     || find "$repo_dir" -maxdepth 3 -name "hyprland.conf" 2>/dev/null | grep -q .; then
    echo "hyprland"
  elif [ -d "$repo_dir/sway" ] || [ -d "$repo_dir/.config/sway" ] \
       || find "$repo_dir" -maxdepth 3 -path "*/sway/config" 2>/dev/null | grep -q .; then
    echo "sway"
  elif [ -d "$repo_dir/i3" ] || [ -d "$repo_dir/.config/i3" ] \
       || find "$repo_dir" -maxdepth 3 -path "*/i3/config" 2>/dev/null | grep -q .; then
    echo "i3"
  elif [ -d "$repo_dir/bspwm" ] || [ -d "$repo_dir/.config/bspwm" ] \
       || find "$repo_dir" -maxdepth 3 -name "bspwmrc" 2>/dev/null | grep -q .; then
    echo "bspwm"
  elif [ -d "$repo_dir/river" ] || [ -d "$repo_dir/.config/river" ] \
       || find "$repo_dir" -maxdepth 3 -name "river" 2>/dev/null | grep -q .; then
    echo "river"
  elif [ -d "$repo_dir/awesome" ] || [ -d "$repo_dir/.config/awesome" ] \
       || find "$repo_dir" -maxdepth 3 -name "rc.lua" 2>/dev/null | grep -q .; then
    echo "awesome"
  elif [ -d "$repo_dir/qtile" ] || [ -d "$repo_dir/.config/qtile" ]; then
    echo "qtile"
  elif [ -d "$repo_dir/dwm" ] || [ -f "$repo_dir/dwm/config.h" ] || [ -f "$repo_dir/config.h" ]; then
    echo "dwm"
  elif [ -d "$repo_dir/xfce4" ] || [ -d "$repo_dir/.config/xfce4" ]; then
    echo "xfce"
  elif [ -d "$repo_dir/plasma" ] || [ -d "$repo_dir/.config/plasma" ] || [ -d "$repo_dir/kwin" ]; then
    echo "plasma"
  elif [ -d "$repo_dir/gnome" ] || [ -d "$repo_dir/.config/gnome" ]; then
    echo "gnome"
  else
    echo ""
  fi
}

rules_barebones_step() {
  local repo_dir="$1"
  [ "${RICER_IS_BAREBONES:-false}" = "true" ] || return 0

  local target_wm
  target_wm=$(rules_detect_target_wm "$repo_dir")
  [ -z "$target_wm" ] && return 0

  local distro_family="${RICER_DISTRO_FAMILY:-}"
  local pm="${RICER_PM_CMD:-}"
  local -a pkgs=()

  if [ "$distro_family" = "gentoo" ] || [ "$pm" = "emerge" ]; then
    case "$target_wm" in
      hyprland)
        pkgs=("gui-wm/hyprland" "gui-apps/waybar" "gui-apps/wofi" "x11-terms/kitty" "sys-auth/polkit" "gui-libs/xdg-desktop-portal-hyprland" "media-video/pipewire" "media-video/wireplumber" "media-fonts/fontawesome" "media-fonts/noto")
        ;;
      sway)
        pkgs=("gui-wm/sway" "gui-apps/swaybg" "gui-apps/waybar" "gui-apps/wofi" "gui-apps/foot" "sys-auth/polkit" "gui-libs/xdg-desktop-portal-wlr" "media-video/pipewire" "media-video/wireplumber")
        ;;
      i3)
        pkgs=("x11-base/xorg-server" "x11-base/xorg-xinit" "x11-wm/i3" "x11-misc/i3status" "x11-misc/dmenu" "x11-terms/alacritty" "x11-misc/picom" "media-gfx/feh")
        ;;
      bspwm)
        pkgs=("x11-base/xorg-server" "x11-base/xorg-xinit" "x11-wm/bspwm" "x11-misc/sxhkd" "x11-misc/polybar" "x11-misc/dmenu" "x11-terms/alacritty" "x11-misc/picom" "media-gfx/feh")
        ;;
      river)
        pkgs=("gui-wm/river" "gui-apps/waybar" "gui-apps/wofi" "gui-apps/foot" "sys-auth/polkit" "gui-libs/xdg-desktop-portal-wlr" "media-video/pipewire" "media-video/wireplumber")
        ;;
      dwm)
        pkgs=("x11-base/xorg-server" "x11-base/xorg-xinit" "x11-wm/dwm" "x11-misc/dmenu" "x11-terms/st")
        ;;
      awesome)
        pkgs=("x11-base/xorg-server" "x11-base/xorg-xinit" "x11-wm/awesome" "x11-misc/dmenu" "x11-terms/alacritty" "x11-misc/picom")
        ;;
      qtile)
        pkgs=("x11-base/xorg-server" "x11-base/xorg-xinit" "x11-wm/qtile" "x11-terms/alacritty" "x11-misc/picom")
        ;;
      xfce)
        pkgs=("xfce-base/xfce4-meta" "x11-base/xorg-server" "x11-misc/lightdm")
        ;;
      plasma)
        pkgs=("kde-plasma/plasma-meta" "x11-misc/sddm")
        ;;
      gnome)
        pkgs=("gnome-base/gnome" "gnome-base/gdm")
        ;;
    esac

    # Extra apps detection for Gentoo
    _check_app_gentoo() {
      local app_name="$1"
      local atom="$2"
      if [ -d "$repo_dir/$app_name" ] || [ -d "$repo_dir/.config/$app_name" ] || find "$repo_dir" -maxdepth 3 -name "$app_name" 2>/dev/null | grep -q .; then
        local found=0
        for p in "${pkgs[@]}"; do
          [ "$p" = "$atom" ] && found=1 && break
        done
        [ "$found" -eq 0 ] && pkgs+=("$atom")
      fi
    }
    _check_app_gentoo "rofi" "x11-misc/rofi"
    _check_app_gentoo "dunst" "x11-misc/dunst"
    _check_app_gentoo "mako" "gui-apps/mako"
    _check_app_gentoo "polybar" "x11-misc/polybar"
    _check_app_gentoo "fastfetch" "app-misc/fastfetch"
    _check_app_gentoo "kitty" "x11-terms/kitty"
    _check_app_gentoo "alacritty" "x11-terms/alacritty"
    _check_app_gentoo "foot" "gui-apps/foot"
  else
    # Arch and other distros
    case "$target_wm" in
      hyprland)
        pkgs=("hyprland" "waybar" "wofi" "kitty" "polkit-kde-agent" "xdg-desktop-portal-hyprland" "qt5-wayland" "qt6-wayland" "pipewire" "pipewire-pulse" "wireplumber" "ttf-font-awesome" "noto-fonts")
        ;;
      sway)
        pkgs=("sway" "swaybg" "waybar" "wofi" "foot" "polkit" "xdg-desktop-portal-wlr" "pipewire" "pipewire-pulse" "wireplumber")
        ;;
      i3)
        pkgs=("xorg-server" "xorg-xinit" "i3-wm" "i3status" "dmenu" "alacritty" "picom" "feh")
        ;;
      bspwm)
        pkgs=("xorg-server" "xorg-xinit" "bspwm" "sxhkd" "polybar" "dmenu" "alacritty" "picom" "feh")
        ;;
      river)
        pkgs=("river" "waybar" "wofi" "foot" "polkit" "xdg-desktop-portal-wlr" "pipewire" "pipewire-pulse" "wireplumber")
        ;;
      dwm)
        pkgs=("xorg-server" "xorg-xinit" "base-devel" "libx11" "libxinerama" "libxft" "dmenu" "st")
        ;;
      awesome)
        pkgs=("xorg-server" "xorg-xinit" "awesome" "dmenu" "alacritty" "picom")
        ;;
      qtile)
        pkgs=("xorg-server" "xorg-xinit" "qtile" "alacritty" "picom")
        ;;
      xfce)
        pkgs=("xfce4" "xfce4-goodies" "lightdm" "lightdm-gtk-greeter" "xorg-server")
        ;;
      plasma)
        pkgs=("plasma-meta" "sddm" "konsole" "dolphin")
        ;;
      gnome)
        pkgs=("gnome" "gdm")
        ;;
    esac

    # Extra apps detection for Arch/others
    _check_app_generic() {
      local app_name="$1"
      local pkg="$2"
      if [ -d "$repo_dir/$app_name" ] || [ -d "$repo_dir/.config/$app_name" ] || find "$repo_dir" -maxdepth 3 -name "$app_name" 2>/dev/null | grep -q .; then
        local found=0
        for p in "${pkgs[@]}"; do
          [ "$p" = "$pkg" ] && found=1 && break
        done
        [ "$found" -eq 0 ] && pkgs+=("$pkg")
      fi
    }
    _check_app_generic "rofi" "rofi"
    _check_app_generic "dunst" "dunst"
    _check_app_generic "mako" "mako"
    _check_app_generic "polybar" "polybar"
    _check_app_generic "fastfetch" "fastfetch"
    _check_app_generic "kitty" "kitty"
    _check_app_generic "alacritty" "alacritty"
    _check_app_generic "foot" "foot"
  fi

  if [ ${#pkgs[@]} -gt 0 ]; then
    local pkgs_json
    pkgs_json=$(printf '%s\n' "${pkgs[@]}" | jq -R . | jq -s .)
    jq -cn --arg wm "$target_wm" --argjson a "$pkgs_json" \
      '{"type":"install_pkg","args":$a,"description":"Auto-install \($wm) and core display environment for barebones system"}'
  fi
}

# ── Find install or setup script in repository ────────────────────────────────
find_install_script() {
  local repo_dir="$1"

  # 1. Root level common script filenames
  for s in install.sh setup.sh bootstrap.sh rice.sh deploy.sh install.bash setup.bash; do
    if [ -f "$repo_dir/$s" ]; then
      echo "./$s"
      return 0
    fi
  done

  # 2. Root level extensionless scripts (must be regular file and executable)
  for s in install setup bootstrap; do
    if [ -f "$repo_dir/$s" ] && [ -x "$repo_dir/$s" ]; then
      echo "./$s"
      return 0
    fi
  done

  # 3. Known subdirectories
  for subdir in scripts script bin install setup tools .scripts; do
    for s in install.sh setup.sh bootstrap.sh rice.sh deploy.sh install.bash setup.bash install setup; do
      if [ -f "$repo_dir/$subdir/$s" ]; then
        echo "./$subdir/$s"
        return 0
      fi
    done
  done

  # 4. Search up to depth 2 for any install/setup/bootstrap/rice script
  local found
  found=$(find "$repo_dir" -maxdepth 2 -type f \( \
    -name "install.sh" -o -name "setup.sh" -o -name "bootstrap.sh" -o -name "rice.sh" -o -name "deploy.sh" \
  \) 2>/dev/null | head -n 1)
  if [ -n "$found" ]; then
    local rel="${found#$repo_dir/}"
    echo "./$rel"
    return 0
  fi

  return 1
}

# Returns a JSON plan array (printed to stdout) based on repo structure.
# Falls back gracefully if no known pattern is detected.
rules_detect_plan() {
  local repo_dir="$1"
  local plan=""

  # ── Pattern 1: explicit install/setup/bootstrap script ──────────────────────
  local iscript
  if iscript=$(find_install_script "$repo_dir") && [ -n "$iscript" ]; then
    log_dim "Rule: found install script ($iscript)"
    plan=$(jq -cn --arg s "$iscript" \
      '[{"type":"run_cmd","args":[$s],"description":"Run repo install script"}]')
  fi

  # ── Pattern 1b: GRUB bootloader theme ─────────────────────────────────────────
  if [ -z "$plan" ]; then
    if [ -f "$repo_dir/theme.txt" ]; then
      log_dim "Rule: root GRUB theme (theme.txt detected)"
      local tname
      tname=$(basename "$repo_dir")
      plan=$(jq -cn --arg t "$tname" '[{"type":"grub_theme","args":[".",$t],"description":"Install GRUB bootloader theme"}]')
    else
      local grub_dir
      grub_dir=$(find "$repo_dir" -maxdepth 2 -name "theme.txt" -exec dirname {} \; 2>/dev/null | head -1)
      if [ -n "$grub_dir" ]; then
        local rel_grub_dir="${grub_dir#$repo_dir/}"
        local tname
        tname=$(basename "$grub_dir")
        log_dim "Rule: GRUB theme in subdirectory ($rel_grub_dir)"
        plan=$(jq -cn --arg d "$rel_grub_dir" --arg t "$tname" '[{"type":"grub_theme","args":[$d,$t],"description":"Install GRUB bootloader theme"}]')
      fi
    fi
  fi

  # ── Pattern 2: chezmoi ───────────────────────────────────────────────────────
  if [ -z "$plan" ]; then
    if [ -d "$repo_dir/.chezmoi" ] \
       || find "$repo_dir" -maxdepth 1 -name 'dot_*' 2>/dev/null | grep -q .; then
      log_dim "Rule: chezmoi layout"
      plan=$(jq -cn '[
        {"type":"install_pkg","args":["chezmoi"],"description":"Install chezmoi"},
        {"type":"run_cmd","args":["chezmoi apply --source ."],"description":"Apply chezmoi dotfiles"}
      ]')
    fi
  fi

  # ── Pattern 3: GNU Stow layout ───────────────────────────────────────────────
  if [ -z "$plan" ]; then
    local stow_indicator=0
    if [ -f "$repo_dir/.stow-local-ignore" ]; then
      stow_indicator=1
    else
      # Heuristic: ≥2 subdirs each containing dotfiles or .config
      local subdirs=0
      while IFS= read -r -d '' d; do
        if find "$d" -maxdepth 2 \( -name '.*' -o -name '.config' \) 2>/dev/null | grep -q .; then
          ((subdirs++))
        fi
      done < <(find "$repo_dir" -mindepth 1 -maxdepth 1 -type d \
                 ! -name '.git' -print0 2>/dev/null)
      [ "$subdirs" -ge 2 ] && stow_indicator=1
    fi
    if [ "$stow_indicator" -eq 1 ]; then
      log_dim "Rule: GNU Stow layout"
      plan=$(jq -cn '[
        {"type":"install_pkg","args":["stow"],"description":"Install GNU Stow"},
        {"type":"stow","args":["."],"description":"Stow all packages to home directory"}
      ]')
    fi
  fi

  # ── Pattern 4: bare git repo (yadm / home-manager style) ─────────────────────
  if [ -z "$plan" ]; then
    if [ -f "$repo_dir/.gitconfig" ] \
       || ([ -f "$repo_dir/.git/config" ] \
           && grep -q 'bare = true' "$repo_dir/.git/config" 2>/dev/null); then
      log_dim "Rule: bare git repo"
      plan=$(jq -cn --arg r "$repo_dir" '[
        {"type":"run_cmd",
         "args":["git --git-dir=\"$REPO_DIR/.git\" --work-tree=\"$HOME\" checkout -f"],
         "description":"Check out bare git repo into home directory"}
      ]' | sed "s|\\\$REPO_DIR|$repo_dir|g")
    fi
  fi

  # ── Pattern 5: .config directory present ─────────────────────────────────────
  if [ -z "$plan" ] && [ -d "$repo_dir/.config" ]; then
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
      plan="$json_steps"
    else
      plan=$(jq -cn '[{"type":"copy","args":[".config","~/.config"],"description":"Copy .config into home"}]')
    fi
  fi

  # ── Pattern 6: dotfiles at repo root (files starting with .) ─────────────────
  if [ -z "$plan" ]; then
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
    fi
  fi

  # ── Pattern 7: app config folders at repo root (e.g. hypr, nvim, waybar, kitty) ───
  if [ -z "$plan" ]; then
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
      plan="$json_app_steps"
    fi
  fi

  # ── Pattern 8: any subdirectories (generic config copy) ──────────────────────
  if [ -z "$plan" ]; then
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
      plan="$json_generic_steps"
    fi
  fi

  # ── Barebones Injection ──────────────────────────────────────────────────────
  # If running on barebones system, inject DE/WM and core infrastructure packages
  if [ "${RICER_IS_BAREBONES:-false}" = "true" ] && [ -n "$plan" ] && [ "$plan" != "[]" ]; then
    local bb_step
    bb_step=$(rules_barebones_step "$repo_dir")
    if [ -n "$bb_step" ]; then
      log_dim "Barebones: prepending DE/WM and core stack installation"
      plan=$(jq -c --argjson bb "$bb_step" '[$bb] + .' <<< "$plan")
    fi
  fi

  if [ -n "$plan" ] && [ "$plan" != "[]" ]; then
    echo "$plan"
    return 0
  fi

  # ── Unknown pattern ───────────────────────────────────────────────────────────
  log_warn "No config files or recognized structures found in repository."
  echo "[]"
  return 1
}
