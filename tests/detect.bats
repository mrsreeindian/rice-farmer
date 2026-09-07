#!/usr/bin/env bats
# Tests for lib/detect.sh

load '../lib/utils.sh'
load '../lib/detect.sh'

setup() {
  detect_system
}

@test "RICER_DISTRO is set and non-empty" {
  [ -n "$RICER_DISTRO" ]
}

@test "RICER_DISTRO_PRETTY is set" {
  [ -n "$RICER_DISTRO_PRETTY" ]
}

@test "RICER_PKG_MANAGERS is set" {
  [ -n "$RICER_PKG_MANAGERS" ]
}

@test "RICER_CPU is set and non-empty" {
  [ -n "$RICER_CPU" ]
}

@test "RICER_RAM is set and non-empty" {
  [ -n "$RICER_RAM" ]
}

@test "RICER_ARCH is set and non-empty" {
  [ -n "$RICER_ARCH" ]
}

@test "RICER_WM is set" {
  [ -n "$RICER_WM" ]
}

@test "RICER_SESSION is x11, wayland, or tty" {
  [[ "$RICER_SESSION" =~ ^(x11|wayland|tty)$ ]]
}

@test "RICER_BOOTLOADER is set" {
  [ -n "$RICER_BOOTLOADER" ]
}

@test "RICER_HAS_GRUB is boolean" {
  [[ "$RICER_HAS_GRUB" =~ ^(true|false)$ ]]
}

@test "RICER_DISTRO_FAMILY is set" {
  [ -n "$RICER_DISTRO_FAMILY" ]
}

@test "RICER_PM_CMD matches supported package managers or empty" {
  [[ "$RICER_PM_CMD" =~ ^(pacman|apt|apt-get|dnf|yum|zypper|emerge|apk|xbps-install|brew|)$ ]]
}
