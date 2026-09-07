#!/usr/bin/env bash
# lib/detect.sh — System detection (distro, WM, package managers, hardware)

detect_system() {
  # ── Distro ──────────────────────────────────────────────────────────────────
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    RICER_DISTRO="${ID:-unknown}"
    RICER_DISTRO_PRETTY="${PRETTY_NAME:-Linux}"
  else
    RICER_DISTRO="unknown"
    RICER_DISTRO_PRETTY="Unknown Linux"
  fi

  # ── Package managers ─────────────────────────────────────────────────────────
  RICER_PKG_MANAGERS=""
  for pm in pacman apt apt-get dnf yum zypper apk xbps-install emerge nix brew; do
    command -v "$pm" &>/dev/null && RICER_PKG_MANAGERS+="${pm} "
  done
  RICER_PKG_MANAGERS="${RICER_PKG_MANAGERS% }"
  [ -z "$RICER_PKG_MANAGERS" ] && RICER_PKG_MANAGERS="unknown"

  # Canonical PM (first one found; used for installs)
  RICER_PM_CMD=""
  for pm in pacman apt dnf zypper apk xbps-install emerge; do
    if command -v "$pm" &>/dev/null; then
      RICER_PM_CMD="$pm"; break
    fi
  done

  # ── Window Manager / Desktop Environment ────────────────────────────────────
  RICER_WM="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
  if [ -z "$RICER_WM" ]; then
    for wm in hyprland sway i3 openbox bspwm xfwm4 kwin_x11 kwin_wayland \
              mutter marco qtile herbstluftwm dwm awesome xmonad; do
      pgrep -x "$wm" &>/dev/null && RICER_WM="$wm" && break
    done
  fi
  # Wayland vs X11 session hint
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    RICER_SESSION="wayland"
  elif [ -n "${DISPLAY:-}" ]; then
    RICER_SESSION="x11"
  else
    RICER_SESSION="tty"
  fi
  RICER_WM="${RICER_WM:-tty (${RICER_SESSION})}"

  # ── Hardware (read from /proc — no extra tools) ──────────────────────────────
  RICER_CPU=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null \
              | cut -d: -f2 | xargs || echo "unknown")
  RICER_RAM=$(awk '/MemTotal/{printf "%.0f MB", $2/1024}' /proc/meminfo 2>/dev/null \
              || echo "unknown")
  # GPU: try lspci first (lightweight), fall back gracefully
  if command -v lspci &>/dev/null; then
    RICER_GPU=$(lspci 2>/dev/null \
                | grep -Ei 'vga|3d controller|display controller' \
                | head -1 | cut -d: -f3 | xargs || echo "unknown")
  else
    RICER_GPU="unknown (lspci not installed)"
  fi
  RICER_ARCH=$(uname -m)

  # ── Bootloader ───────────────────────────────────────────────────────────────
  RICER_BOOTLOADER="unknown"
  RICER_HAS_GRUB="false"
  if command -v grub-install &>/dev/null || command -v grub-mkconfig &>/dev/null || \
     command -v grub2-mkconfig &>/dev/null || command -v update-grub &>/dev/null || \
     [ -d /boot/grub ] || [ -d /boot/grub2 ] || [ -f /etc/default/grub ]; then
    RICER_BOOTLOADER="grub"
    RICER_HAS_GRUB="true"
  elif command -v bootctl &>/dev/null && bootctl is-installed &>/dev/null; then
    RICER_BOOTLOADER="systemd-boot"
  elif [ -d /boot/loader ]; then
    RICER_BOOTLOADER="systemd-boot"
  fi

  export RICER_DISTRO RICER_DISTRO_PRETTY RICER_PKG_MANAGERS RICER_PM_CMD \
         RICER_WM RICER_SESSION RICER_CPU RICER_RAM RICER_GPU RICER_ARCH \
         RICER_BOOTLOADER RICER_HAS_GRUB
}
