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
