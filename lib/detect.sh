#!/usr/bin/env bash
# lib/detect.sh — System detection (distro, WM, package managers, hardware)

detect_system() {
  # ── Distro ──────────────────────────────────────────────────────────────────
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    RICER_DISTRO="${ID:-unknown}"
    RICER_DISTRO_LIKE="${ID_LIKE:-}"
    RICER_DISTRO_PRETTY="${PRETTY_NAME:-Linux}"
  else
    RICER_DISTRO="unknown"
    RICER_DISTRO_LIKE=""
    RICER_DISTRO_PRETTY="Unknown Linux"
  fi

  # Distro family classification
  if [ -z "${RICER_DISTRO_FAMILY:-}" ]; then
    RICER_DISTRO_FAMILY="unknown"
    case "$RICER_DISTRO $RICER_DISTRO_LIKE" in
      *ubuntu*|*debian*|*pop*|*mint*|*elementary*)
        RICER_DISTRO_FAMILY="ubuntu/debian" ;;
      *rhel*|*redhat*|*fedora*|*centos*|*rocky*|*alma*)
        RICER_DISTRO_FAMILY="redhat" ;;
      *arch*|*manjaro*|*endeavouros*|*omarchy*|*garuda*|*artix*)
        RICER_DISTRO_FAMILY="arch" ;;
      *gentoo*|*funtoo*)
        RICER_DISTRO_FAMILY="gentoo" ;;
      *suse*|*opensuse*)
        RICER_DISTRO_FAMILY="opensuse" ;;
    esac
  fi

  # ── Package managers ─────────────────────────────────────────────────────────
  RICER_PKG_MANAGERS=""
  for pm in pacman apt apt-get dnf yum zypper emerge apk xbps-install nix brew; do
    command -v "$pm" &>/dev/null && RICER_PKG_MANAGERS+="${pm} "
  done
  RICER_PKG_MANAGERS="${RICER_PKG_MANAGERS% }"
  [ -z "$RICER_PKG_MANAGERS" ] && RICER_PKG_MANAGERS="unknown"

  # Canonical PM (prioritized according to distro family)
  if [ -z "${RICER_PM_CMD:-}" ]; then
    case "$RICER_DISTRO_FAMILY" in
      ubuntu/debian)
        for pm in apt apt-get; do command -v "$pm" &>/dev/null && { RICER_PM_CMD="$pm"; break; }; done ;;
      redhat)
        for pm in dnf yum; do command -v "$pm" &>/dev/null && { RICER_PM_CMD="$pm"; break; }; done ;;
      arch)
        command -v pacman &>/dev/null && RICER_PM_CMD="pacman" ;;
      gentoo)
        command -v emerge &>/dev/null && RICER_PM_CMD="emerge" ;;
      opensuse)
        command -v zypper &>/dev/null && RICER_PM_CMD="zypper" ;;
    esac

    if [ -z "$RICER_PM_CMD" ]; then
      for pm in pacman apt dnf zypper emerge apk xbps-install yum brew; do
        if command -v "$pm" &>/dev/null; then
          RICER_PM_CMD="$pm"; break
        fi
      done
    fi
  fi

  # ── Window Manager / Desktop Environment ────────────────────────────────────
  RICER_WM="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
  if [ -z "$RICER_WM" ]; then
    for wm in hyprland sway i3 openbox bspwm xfwm4 kwin_x11 kwin_wayland \
              mutter marco qtile herbstluftwm dwm awesome xmonad gnome-shell; do
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

  # Barebones detection (e.g. minimal Arch or Gentoo installed without DE/WM)
  if [ -z "${RICER_IS_BAREBONES:-}" ]; then
    RICER_IS_BAREBONES="false"
    if [ -z "$RICER_WM" ] || [ "$RICER_WM" = "tty" ] || [ "$RICER_SESSION" = "tty" ]; then
      # Check if any common display server or compositor binaries exist
      if ! command -v Xorg &>/dev/null && ! command -v X &>/dev/null && \
         ! command -v hyprland &>/dev/null && ! command -v sway &>/dev/null && \
         ! command -v wayfire &>/dev/null && ! command -v i3 &>/dev/null && \
         ! command -v gnome-shell &>/dev/null && ! command -v plasma_session &>/dev/null && \
         ! command -v startxfce4 &>/dev/null; then
        RICER_IS_BAREBONES="true"
      fi
    fi
  fi
  if [ "$RICER_IS_BAREBONES" = "true" ]; then
    RICER_WM="none (barebones)"
  else
    RICER_WM="${RICER_WM:-tty (${RICER_SESSION})}"
  fi

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

  # ── Pre-Rice Environment ───────────────────────────────────────────────────
  if [ -z "${RICER_PRE_RICE:-}" ]; then
    if [ "$RICER_DISTRO" = "omarchy" ] || [ -d /usr/share/omarchy ] || [ -d "${HOME}/.config/omarchy" ] || command -v omarchy-version &>/dev/null; then
      RICER_PRE_RICE="omarchy"
    elif [ "$RICER_DISTRO" = "cachyos" ] || [ -f /etc/cachyos-release ] || [ -d /etc/cachyos ] || [ -d "${HOME}/.config/cachyos" ]; then
      RICER_PRE_RICE="cachyos"
    elif [ "$RICER_DISTRO" = "garuda" ] || [ -f /etc/garuda-release ] || [ -d /usr/share/garuda ] || [ -d "${HOME}/.config/garuda" ]; then
      RICER_PRE_RICE="garuda"
    elif [ -d "${HOME}/.local/share/omakub" ] || [ -d "${HOME}/.config/omakub" ] || command -v omakub &>/dev/null; then
      RICER_PRE_RICE="omakub"
    elif [ -d "${HOME}/.config/caelestia" ] || [ -d "${HOME}/.local/share/caelestia" ] || command -v caelestia &>/dev/null; then
      RICER_PRE_RICE="caelestia"
    elif [ -d "${HOME}/.config/hyprdots" ] || [ -d "${HOME}/.local/lib/hyprdots" ]; then
      RICER_PRE_RICE="hyprdots"
    else
      RICER_PRE_RICE="none"
    fi
  fi

  export RICER_DISTRO RICER_DISTRO_LIKE RICER_DISTRO_FAMILY RICER_DISTRO_PRETTY \
         RICER_PKG_MANAGERS RICER_PM_CMD \
         RICER_WM RICER_SESSION RICER_IS_BAREBONES RICER_PRE_RICE \
         RICER_CPU RICER_RAM RICER_GPU RICER_ARCH \
         RICER_BOOTLOADER RICER_HAS_GRUB
}
