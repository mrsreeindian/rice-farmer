#!/usr/bin/env bats
# Tests for lib/repack.sh — System repackaging into shareable rice zip

load '../lib/utils.sh'
load '../lib/detect.sh'
load '../lib/prerice.sh'
load '../lib/repack.sh'

_tmpdir() { mktemp -d; }

@test "repack_resolve_format honors explicit valid format" {
  RICER_REPACK_FORMAT="omarchy" run repack_resolve_format
  [ "$status" -eq 0 ]
  [ "$output" = "omarchy" ]

  RICER_REPACK_FORMAT="caelestia" run repack_resolve_format
  [ "$status" -eq 0 ]
  [ "$output" = "caelestia" ]

  RICER_REPACK_FORMAT="garuda" run repack_resolve_format
  [ "$status" -eq 0 ]
  [ "$output" = "garuda" ]

  RICER_REPACK_FORMAT="generic" run repack_resolve_format
  [ "$status" -eq 0 ]
  [ "$output" = "generic" ]
}

@test "repack_resolve_format falls back to generic for unknown format" {
  RICER_REPACK_FORMAT="nonexistent" run repack_resolve_format
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "generic" ]
}

@test "repack_resolve_format uses detect_pre_rice when no format specified" {
  RICER_REPACK_FORMAT="" RICER_PRE_RICE="omarchy" RICER_DISTRO="arch" run repack_resolve_format
  [ "$status" -eq 0 ]
  [ "$output" = "omarchy" ]

  RICER_REPACK_FORMAT="" RICER_PRE_RICE="caelestia" RICER_DISTRO="arch" run repack_resolve_format
  [ "$status" -eq 0 ]
  [ "$output" = "caelestia" ]
}

@test "repack_find_wallpaper detects hyprpaper wallpaper" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  HOME="$test_h"

  mkdir -p "$HOME/.config/hypr"
  mkdir -p "$HOME/Pictures"
  touch "$HOME/Pictures/test_wp.png"
  echo "preload = ~/Pictures/test_wp.png" > "$HOME/.config/hypr/hyprpaper.conf"
  echo "wallpaper = ,~/Pictures/test_wp.png" >> "$HOME/.config/hypr/hyprpaper.conf"

  result=$(repack_find_wallpaper "generic")
  rm -rf "$test_h"
  HOME="$orig_home"

  [ "$result" = "$test_h/Pictures/test_wp.png" ]
}

@test "repack_find_wallpaper detects fehbg wallpaper" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  HOME="$test_h"

  mkdir -p "$HOME/wallpapers"
  touch "$HOME/wallpapers/sunset.jpg"
  echo "feh --no-fehbg --bg-fill '~/wallpapers/sunset.jpg'" > "$HOME/.fehbg"

  result=$(repack_find_wallpaper "generic")
  rm -rf "$test_h"
  HOME="$orig_home"

  [ "$result" = "$test_h/wallpapers/sunset.jpg" ]
}

@test "repack_copy_app_config excludes .git and sensitive secret patterns" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  local stage=$(_tmpdir)
  HOME="$test_h"

  mkdir -p "$HOME/.config/testapp/.git"
  touch "$HOME/.config/testapp/.git/HEAD"
  touch "$HOME/.config/testapp/config.conf"
  touch "$HOME/.config/testapp/id_rsa.key"
  touch "$HOME/.config/testapp/api_token.json"
  touch "$HOME/.config/testapp/app.sock"
  touch "$HOME/.config/testapp/app.log"

  repack_copy_app_config "testapp" "$stage"

  [ -f "$stage/testapp/config.conf" ]
  [ ! -d "$stage/testapp/.git" ]
  [ ! -f "$stage/testapp/id_rsa.key" ]
  [ ! -f "$stage/testapp/api_token.json" ]
  [ ! -f "$stage/testapp/app.sock" ]
  [ ! -f "$stage/testapp/app.log" ]

  rm -rf "$test_h" "$stage"
  HOME="$orig_home"
}

@test "repack_generate_installer creates valid executable installer" {
  local stage=$(_tmpdir)
  repack_generate_installer "$stage" "omarchy" "Hyprland"

  [ -x "$stage/install.sh" ]
  grep -q "Rice Farmer — Installing Repacked Rice" "$stage/install.sh"
  grep -q "Restored Omarchy ecosystem configurations." "$stage/install.sh"

  rm -rf "$stage"
}

@test "repack_create_zip packages directory into valid zip" {
  local stage=$(_tmpdir)
  local out_zip="$stage/test_output.zip"

  echo "hello" > "$stage/test.txt"
  mkdir -p "$stage/sub"
  echo "world" > "$stage/sub/data.txt"

  repack_create_zip "$stage" "$out_zip"

  [ -f "$out_zip" ]
  unzip -l "$out_zip" | grep -q "test.txt"
  unzip -l "$out_zip" | grep -q "sub/data.txt"

  rm -rf "$stage"
}

@test "run_repack end-to-end generates archive with rice.json and install.sh" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  local out_zip="$test_h/output.zip"
  HOME="$test_h"

  mkdir -p "$HOME/.config/hypr"
  echo "monitor=,preferred,auto,1" > "$HOME/.config/hypr/hyprland.conf"
  mkdir -p "$HOME/Pictures/Wallpapers"
  touch "$HOME/Pictures/Wallpapers/default.png"

  RICER_REPACK_FORMAT="generic" RICER_WM="Hyprland" run_repack "$out_zip"

  [ -f "$out_zip" ]

  local extract_dir=$(_tmpdir)
  unzip -q "$out_zip" -d "$extract_dir"

  [ -f "$extract_dir/install.sh" ]
  [ -f "$extract_dir/rice.json" ]
  [ -f "$extract_dir/README.md" ]
  [ -f "$extract_dir/.config/hypr/hyprland.conf" ]
  [ -f "$extract_dir/wallpapers/default.png" ]

  format=$(jq -r .format "$extract_dir/rice.json")
  [ "$format" = "generic" ]
  wm=$(jq -r .wm "$extract_dir/rice.json")
  [ "$wm" = "Hyprland" ]

  rm -rf "$test_h" "$extract_dir"
  HOME="$orig_home"
}

@test "run_repack defaults to saving archive inside Downloads directory" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  HOME="$test_h"

  mkdir -p "$HOME/.config/hypr"
  touch "$HOME/.config/hypr/hyprland.conf"

  RICER_REPACK_FORMAT="generic" RICER_WM="Hyprland" run_repack ""

  [ -d "$test_h/Downloads" ]
  local count
  count=$(find "$test_h/Downloads" -maxdepth 1 -name "rice-repack-generic-*.zip" | wc -l)
  [ "$count" -ge 1 ]

  rm -rf "$test_h"
  HOME="$orig_home"
}

@test "repack_duplicate_item dereferences symlinks into real files" {
  local src_dir=$(_tmpdir)
  local dst_dir=$(_tmpdir)

  echo "real content" > "$src_dir/real.txt"
  ln -s "$src_dir/real.txt" "$src_dir/symlink.txt"

  repack_duplicate_item "$src_dir" "$dst_dir"

  [ -f "$dst_dir/real.txt" ]
  [ -f "$dst_dir/symlink.txt" ]
  [ ! -L "$dst_dir/symlink.txt" ]
  [ "$(cat "$dst_dir/symlink.txt")" = "real content" ]

  rm -rf "$src_dir" "$dst_dir"
}

@test "run_repack completely exports keybinds, vim, nvim, terminal configs, home dotfiles and dereferences all files" {
  local orig_home="$HOME"
  local test_h=$(_tmpdir)
  local out_zip="$test_h/full_rice.zip"
  HOME="$test_h"

  # 1. OS & WM keybinds
  mkdir -p "$HOME/.config/hypr"
  echo "bind = SUPER, Q, exec, kitty" > "$HOME/.config/hypr/bindings.conf"
  echo "source = ./bindings.conf" > "$HOME/.config/hypr/hyprland.conf"

  # 2. Neovim configs and keymaps
  mkdir -p "$HOME/.config/nvim/lua/config"
  echo "vim.keymap.set('n', '<leader>w', ':w<CR>')" > "$HOME/.config/nvim/lua/config/keymaps.lua"
  echo "require('config.keymaps')" > "$HOME/.config/nvim/init.lua"

  # 3. Terminal configs
  mkdir -p "$HOME/.config/kitty"
  echo "font_size 12.0" > "$HOME/.config/kitty/kitty.conf"
  mkdir -p "$HOME/.config/tmux"
  echo "bind-key r source-file ~/.config/tmux/tmux.conf" > "$HOME/.config/tmux/tmux.conf"

  # 4. Home dotfiles (Vim, Bash, Zsh)
  echo "set number" > "$HOME/.vimrc"
  echo "alias ll='ls -la'" > "$HOME/.bashrc"
  echo "export EDITOR=nvim" > "$HOME/.zshrc"

  # 5. Wallpapers
  mkdir -p "$HOME/Wallpapers"
  echo "fake wallpaper" > "$HOME/Wallpapers/rice-bg.jpg"

  RICER_REPACK_FORMAT="omarchy" RICER_WM="Hyprland" run_repack "$out_zip"

  [ -f "$out_zip" ]

  local extract_dir=$(_tmpdir)
  unzip -q "$out_zip" -d "$extract_dir"

  # Check .config items
  [ -f "$extract_dir/.config/hypr/bindings.conf" ]
  [ -f "$extract_dir/.config/nvim/lua/config/keymaps.lua" ]
  [ -f "$extract_dir/.config/kitty/kitty.conf" ]
  [ -f "$extract_dir/.config/tmux/tmux.conf" ]

  # Check home dotfiles
  [ -f "$extract_dir/home/.vimrc" ]
  [ -f "$extract_dir/home/.bashrc" ]
  [ -f "$extract_dir/home/.zshrc" ]

  # Check wallpaper
  [ -f "$extract_dir/wallpapers/rice-bg.jpg" ]

  # Verify NO symlinks exist anywhere in the extracted package
  local symlink_count
  symlink_count=$(find "$extract_dir" -type l | wc -l)
  [ "$symlink_count" -eq 0 ]

  # Verify manifest includes these configs and dotfiles
  grep -q "nvim" "$extract_dir/rice.json"
  grep -q "kitty" "$extract_dir/rice.json"
  grep -q ".bashrc" "$extract_dir/rice.json"
  grep -q ".vimrc" "$extract_dir/rice.json"

  rm -rf "$test_h" "$extract_dir"
  HOME="$orig_home"
}


