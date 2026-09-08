#!/usr/bin/env bats
# Tests for lib/prerice.sh — Pre-rice conflict management & profiles

load '../lib/utils.sh'
load '../lib/detect.sh'
load '../lib/prerice.sh'

_tmpdir() { mktemp -d; }

@test "Detects Omarchy profile" {
  RICER_PRE_RICE="" RICER_DISTRO="omarchy" result=$(detect_pre_rice)
  [ "$result" = "omarchy" ]
}

@test "Detects CachyOS profile" {
  RICER_PRE_RICE="" RICER_DISTRO="cachyos" result=$(detect_pre_rice)
  [ "$result" = "cachyos" ]
}

@test "Detects Garuda profile" {
  RICER_PRE_RICE="" RICER_DISTRO="garuda" result=$(detect_pre_rice)
  [ "$result" = "garuda" ]
}

@test "Detects Omakub profile" {
  RICER_PRE_RICE="omakub"
  result=$(detect_pre_rice)
  [ "$result" = "omakub" ]
}

@test "Detects Caelestia profile" {
  RICER_PRE_RICE="caelestia"
  result=$(detect_pre_rice)
  [ "$result" = "caelestia" ]
}

@test "Omarchy detects notification conflict with dunst" {
  d=$(_tmpdir)
  mkdir -p "$d/dunst"
  touch "$d/dunst/dunstrc"
  result=$(prerice_check_conflicts "omarchy" "$d")
  rm -rf "$d"
  echo "$result" | grep -q "Notification daemon"
}

@test "Caelestia detects conflict with waybar" {
  d=$(_tmpdir)
  mkdir -p "$d/waybar"
  touch "$d/waybar/config"
  result=$(prerice_check_conflicts "caelestia" "$d")
  rm -rf "$d"
  echo "$result" | grep -q "Status bar"
}

@test "Omarchy generates conflict resolution steps" {
  d=$(_tmpdir)
  mkdir -p "$d/dunst"
  touch "$d/dunst/dunstrc"
  result=$(prerice_get_resolutions "omarchy" "$d")
  rm -rf "$d"
  echo "$result" | jq -e 'length > 0 and (.[0].type == "resolve_conflict")'
}
