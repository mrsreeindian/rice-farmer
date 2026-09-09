#!/usr/bin/env bats
# Tests for lib/install.sh & lib/ai.sh — Backup hierarchy, restore fidelity, parameter check

load '../lib/utils.sh'
load '../lib/detect.sh'
load '../lib/install.sh'
load '../lib/ai.sh'

_tmpdir() { mktemp -d; }

@test "_is_over_4b correctly classifies models" {
  [ "$(_is_over_4b 'llama3:8b')" -eq 1 ]
  [ "$(_is_over_4b 'mistral:7b')" -eq 1 ]
  [ "$(_is_over_4b 'qwen:14b')" -eq 1 ]
  [ "$(_is_over_4b 'deepseek-coder:1.3b')" -eq 0 ]
  [ "$(_is_over_4b 'phi3:3.8b')" -eq 0 ]
  [ "$(_is_over_4b 'smollm:360m')" -eq 0 ]
  [ "$(_is_over_4b '7')" -eq 1 ]
  [ "$(_is_over_4b '3')" -eq 0 ]
}

@test "_backup_copy preserves relative path hierarchy under ~/.config" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  local test_repo=$(_tmpdir)

  HOME="$test_h"
  mkdir -p "$HOME/.config/alacritty"
  echo "old_alacritty_config" > "$HOME/.config/alacritty/alacritty.toml"

  mkdir -p "$test_repo/.config/alacritty"
  echo "new_alacritty_config" > "$test_repo/.config/alacritty/alacritty.toml"

  init_backup

  _backup_copy "$test_repo" ".config/alacritty" "~/.config/alacritty"

  # Verify backup directory has .config/alacritty, NOT flat alacritty
  [ -d "$RICER_BACKUP_DIR/.config/alacritty" ]
  [ -f "$RICER_BACKUP_DIR/.config/alacritty/alacritty.toml" ]
  [ ! -d "$RICER_BACKUP_DIR/alacritty" ]

  # Verify new config was installed
  [ "$(cat "$HOME/.config/alacritty/alacritty.toml")" = "new_alacritty_config" ]

  rm -rf "$test_h" "$test_repo"
  HOME="$orig_home"
}

@test "restore_latest_backup accurately restores .config hierarchy without polluting HOME" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  local test_repo=$(_tmpdir)

  HOME="$test_h"
  mkdir -p "$HOME/.config/hypr"
  echo "original_hypr_config" > "$HOME/.config/hypr/hyprland.conf"

  mkdir -p "$test_repo/hypr"
  echo "new_hypr_config" > "$test_repo/hypr/hyprland.conf"

  init_backup
  _backup_copy "$test_repo" "hypr" "~/.config/hypr"

  # User is on new config
  [ "$(cat "$HOME/.config/hypr/hyprland.conf")" = "new_hypr_config" ]

  # Perform restore
  restore_latest_backup

  # Config in ~/.config/hypr must be restored
  [ "$(cat "$HOME/.config/hypr/hyprland.conf")" = "original_hypr_config" ]
  # Must NOT have created ~/hypr in HOME root
  [ ! -d "$HOME/hypr" ]

  rm -rf "$test_h" "$test_repo"
  HOME="$orig_home"
}

@test "_backup_copy does not recursively copy entire HOME on root dotfiles" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  local test_repo=$(_tmpdir)

  HOME="$test_h"
  mkdir -p "$HOME/Documents" "$HOME/Downloads"
  echo "important doc" > "$HOME/Documents/doc.txt"
  echo "existing bashrc" > "$HOME/.bashrc"

  touch "$test_repo/.bashrc"
  echo "new bashrc" > "$test_repo/.bashrc"

  init_backup
  _backup_copy "$test_repo" "." "~/"

  # Documents and Downloads must NEVER be in backup directory
  [ ! -d "$RICER_BACKUP_DIR/Documents" ]
  [ ! -d "$RICER_BACKUP_DIR/Downloads" ]
  # Only the modified dotfile should be backed up
  [ -f "$RICER_BACKUP_DIR/.bashrc" ]

  rm -rf "$test_h" "$test_repo"
  HOME="$orig_home"
}

@test "_backup_copy normalizes trailing slashes and never deletes HOME" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  local test_repo=$(_tmpdir)

  HOME="$test_h"
  mkdir -p "$HOME/keep_this_dir"
  echo "keep_me" > "$HOME/keep_this_dir/important.txt"
  echo "old_bashrc" > "$HOME/.bashrc"

  touch "$test_repo/.bashrc"
  echo "new_bashrc" > "$test_repo/.bashrc"

  init_backup
  # Calling with trailing slash "~/" must not delete HOME or other dirs
  _backup_copy "$test_repo" "." "~/"

  [ -d "$HOME/keep_this_dir" ]
  [ -f "$HOME/keep_this_dir/important.txt" ]
  [ "$(cat "$HOME/.bashrc")" = "new_bashrc" ]

  rm -rf "$test_h" "$test_repo"
  HOME="$orig_home"
}

@test "_is_sensitive_path correctly identifies protected paths" {
  local orig_home="$HOME"
  HOME="/home/testuser"

  _is_sensitive_path "/home/testuser/.ssh/authorized_keys"
  _is_sensitive_path "/home/testuser/.gnupg/secring.gpg"
  _is_sensitive_path "/home/testuser/.aws/credentials"
  _is_sensitive_path "/etc/shadow"
  _is_sensitive_path "/etc/sudoers"

  # Non-sensitive paths must return false
  ! _is_sensitive_path "/home/testuser/.config/hypr/hyprland.conf"
  ! _is_sensitive_path "/home/testuser/.config/nvim/init.lua"
  ! _is_sensitive_path "/home/testuser/.bashrc"

  HOME="$orig_home"
}

@test "_backup_copy blocks attempts to write to sensitive paths" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  local test_repo=$(_tmpdir)

  HOME="$test_h"
  mkdir -p "$HOME/.ssh"
  echo "legit_key" > "$HOME/.ssh/authorized_keys"

  mkdir -p "$test_repo"
  echo "evil_key" > "$test_repo/evil_key"

  init_backup
  # Attempting to copy to .ssh must be blocked
  local status=0
  _backup_copy "$test_repo" "evil_key" "~/.ssh/authorized_keys" || status=$?

  [ "$status" -ne 0 ]
  [ "$(cat "$HOME/.ssh/authorized_keys")" = "legit_key" ]

  rm -rf "$test_h" "$test_repo"
  HOME="$orig_home"
}
