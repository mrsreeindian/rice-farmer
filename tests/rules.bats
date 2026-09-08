#!/usr/bin/env bats
# Tests for lib/rules.sh — offline rule engine

load '../lib/utils.sh'
load '../lib/rules.sh'

_tmpdir() { mktemp -d; }

@test "Pattern 1: detects install.sh" {
  d=$(_tmpdir)
  touch "$d/install.sh"
  result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e '.[0].type == "run_cmd"'
}

@test "Pattern 1b: detects GRUB theme with theme.txt" {
  d=$(_tmpdir)
  touch "$d/theme.txt"
  result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e '.[0].type == "grub_theme"'
}

@test "Pattern 2: detects chezmoi dot_ files" {
  d=$(_tmpdir)
  touch "$d/dot_bashrc" "$d/dot_vimrc"
  result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e '.[0].type == "install_pkg" or .[0].type == "run_cmd"'
}

@test "Pattern 3: detects stow layout via .stow-local-ignore" {
  d=$(_tmpdir)
  touch "$d/.stow-local-ignore"
  mkdir -p "$d/bash" "$d/nvim"
  result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e 'map(select(.type=="stow")) | length > 0'
}

@test "Pattern 5: detects .config directory and creates copy steps" {
  d=$(_tmpdir)
  mkdir -p "$d/.config/alacritty"
  result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e '.[0].type == "copy" and (.[0].args[1] | test("~/.config/alacritty"))'
}

@test "Pattern 6: detects root dotfiles" {
  d=$(_tmpdir)
  touch "$d/.bashrc" "$d/.vimrc" "$d/.zshrc"
  result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e '.[0].type == "copy"'
}

@test "Pattern 7: detects app config directories without install script" {
  d=$(_tmpdir)
  mkdir -p "$d/hypr" "$d/waybar"
  result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e 'length == 2 and .[0].type == "copy"'
}

@test "Empty directory returns empty array" {
  d=$(_tmpdir)
  result=$(rules_detect_plan "$d" 2>/dev/null || echo "[]")
  rm -rf "$d"
  echo "$result" | jq -e '. == []'
}

@test "Barebones Arch auto-installs Hyprland and core display environment" {
  d=$(_tmpdir)
  mkdir -p "$d/hypr"
  touch "$d/hypr/hyprland.conf"
  RICER_IS_BAREBONES="true" RICER_DISTRO_FAMILY="arch" RICER_PM_CMD="pacman" \
    result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e '.[0].type == "install_pkg" and (.[0].args | contains(["hyprland", "waybar"]))'
}

@test "Barebones Gentoo auto-installs Hyprland atoms" {
  d=$(_tmpdir)
  mkdir -p "$d/hypr"
  touch "$d/hypr/hyprland.conf"
  RICER_IS_BAREBONES="true" RICER_DISTRO_FAMILY="gentoo" RICER_PM_CMD="emerge" \
    result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e '.[0].type == "install_pkg" and (.[0].args | contains(["gui-wm/hyprland", "gui-apps/waybar"]))'
}

@test "Barebones Arch auto-installs i3 and X11 stack" {
  d=$(_tmpdir)
  mkdir -p "$d/.config/i3"
  touch "$d/.config/i3/config"
  RICER_IS_BAREBONES="true" RICER_DISTRO_FAMILY="arch" RICER_PM_CMD="pacman" \
    result=$(rules_detect_plan "$d")
  rm -rf "$d"
  echo "$result" | jq -e '.[0].type == "install_pkg" and (.[0].args | contains(["xorg-server", "i3-wm"]))'
}

