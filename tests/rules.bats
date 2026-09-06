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
