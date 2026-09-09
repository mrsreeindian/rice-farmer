# Changelog

## [1.2.0] — 2026-09-09
### Added
- Local-First AI Architecture & Model Management:
  - Zero-online install search: searches repository files first and skips AI entirely when an install script is detected.
  - Searches local models in **Ollama** and **llama.cpp** (`llama-server`, `llama-cli`, and GGUF model stores) before making any online calls.
  - `--local` flag to search for and prioritize local models.
  - Parameter threshold check: evaluates whether local models have over 4B parameters (`> 4B`).
  - Automatic model initialization: boots and uses local models >4B parameters without contacting online cloud backends.
  - Under-powered model warning: alerts users when local models have ≤4B parameters and falls back to online models (or rule engine if `--offline`).

## [1.1.1] — 2026-09-08
### Added
- `--clean-orphans` flag (with `--remove-orphans` and `--prune-orphans` aliases): automatically removes unused / orphan packages across supported package managers (`pacman`, `apt`, `dnf`, `yum`, `zypper`, `emerge`, `xbps-remove`, `brew`) after rice installation.
- Reworked update channels:
  - `ricer update`: pulls the latest official GitHub release only (`/releases/latest`), preventing inadvertent edge/beta upgrades and version regressions.
  - `ricer update --beta`: pulls the latest git tag (`/tags`) directly from GitHub, allowing users to update to latest tagged pre-release builds.
  - Pinned raw file asset downloads using the resolved tag/release name.
- File-first script search & AI filesystem engine:
  - Repository files are searched for an install/setup script first before any AI action.
  - Skips AI initialization completely when an install script is detected, eliminating unnecessary network latency or model loading.
  - Initializes AI exclusively to inspect configs and generate filesystem operations (`copy`, `symlink`, `stow`, `grub_theme`) when no install script exists.

## [1.1.0] — 2026-09-08
### Added
- Pre-rice environment detection & profile configurations:
  - Separate profiles for **Omarchy**, **CachyOS**, **Garuda Linux**, **Omakub**, and pre-rice environments (e.g. **Caelestia**, **Hyprdots**)
  - Prominent ASCII conflict warning display highlighting colliding daemons, status bars, and desktop configs
  - Automated conflict resolution: gracefully stops colliding background daemons (e.g. `mako` vs `dunst`, `ags` vs `waybar`, `latte-dock`)
  - Config quarantine and isolation: backs up and isolates conflicting theme hooks, shell source lines, and autostarts before deploying the new rice
  - Automated dependency resolution: auto-identifies and installs any missing packages required by the incoming rice on that base environment
- Barebones Arch Linux and Gentoo support:
  - Automatic detection of minimal TTY environments without any DE/WM or display server installed (`RICER_IS_BAREBONES`)
  - Target WM/DE identification (Hyprland, Sway, i3, BSPWM, River, Awesome, Qtile, DWM, KDE Plasma, GNOME, XFCE)
  - Auto-installation of window managers, compositors, X11/Wayland backends, audio infrastructure (`pipewire`, `wireplumber`), desktop portals, status bars, terminals, and fonts
  - Distribution-specific package mappings with Arch Linux package names (`pacman`) and Gentoo category atoms (`emerge`, e.g. `gui-wm/hyprland`, `x11-wm/i3`)
  - Fallback support for root/chroot environments without `sudo`

## [1.0.0] — 2026-09-07
### Added
- First official major release of Rice Farmer v1.0.0
- Multi-distro detection & support: **Ubuntu/Debian** (`apt`), **Red Hat/Fedora/CentOS/Rocky** (`dnf`/`yum`), **Arch Linux** (`pacman`), **Gentoo** (`emerge`), and **openSUSE/SUSE** (`zypper`)
- GRUB bootloader customization: automatic theme installation, `/etc/default/grub` configuration, safe backup & restore, and `grub-mkconfig`/`update-grub` regeneration
- Scriptless dotfile repo support: intelligent automatic mapping of app configs to `~/.config/` and dotfiles to `$HOME`
- Cloud AI plan generation (free, no API key required) with automatic fallback to an 8-pattern offline rule engine
- One-liner cURL installer, atomic self-update (`ricer update`), and clean uninstaller (`ricer uninstall`)
- Pure ASCII terminal styling and box borders compatible with all terminals and TTYs
- System detection (distro, WM, package managers, CPU, RAM, GPU)
- Pollinations.ai cloud AI backend (no API key, no local model)
- Ollama auto-detect (used if already running locally)
- Offline rule engine for 6 common dotfile repo patterns
- Config backup & restore
- GNU Stow, copy, symlink, run_cmd install step types
- cURL one-liner installer
- `--dry-run`, `--no-backup`, `--offline`, `--model` flags
