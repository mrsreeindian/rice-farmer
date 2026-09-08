# Rice Farmer — Project Vision & Specification

A lightweight, pure-Bash Linux ricing utility designed to automatically install any Linux rice, dotfiles, or GRUB theme from a GitHub URL in a single command.

---

## Core Initial Idea

A Linux ricing utility that can:
- Identify distro
- Identify WM / desktop session
- Identify package managers
- Identify hardware (CPU, RAM, GPU, architecture)
- Accept a GitHub link corresponding to a Linux rice / dotfile repo
- Call a free cloud AI model (no API key required) to analyze the repo and generate install steps
- Automatically back up existing configurations and apply the new rice
- Clean up temporary clone and residual files after installation
- Publishable with version control and releases
- One-liner cURL installer (`curl -fsSL ... | bash`)

---

## New Additions & Expanded Capabilities

### 1. Broad Multi-Distro Support
- Native detection and automatic package installation across major Linux distributions:
  - **Arch Linux & derivatives** (`pacman`)
  - **Gentoo Linux** (`emerge` with non-interactive flags and category atoms)
  - **Ubuntu / Debian & derivatives** (`apt`, `apt-get`)
  - **Red Hat / Fedora / CentOS / Rocky** (`dnf`, `yum`)
  - **openSUSE / SUSE** (`zypper`)
  - **Alpine Linux** (`apk`), **Void Linux** (`xbps-install`), and **Homebrew** (`brew`)

### 2. Barebones Arch Linux & Gentoo Auto-Install
- **Barebones Detection**: Detects minimal TTY-only installations where no window manager, desktop environment, or display server exists (`RICER_IS_BAREBONES`).
- **Target WM/DE Identification**: Intelligently identifies the target environment from the repo structure (Hyprland, Sway, i3, BSPWM, River, Awesome, Qtile, DWM, KDE Plasma, GNOME, XFCE).
- **Full Stack Provisioning**: Automatically installs the DE/WM along with all supporting display and system infrastructure:
  - Display server / compositor (Wayland or X11)
  - Audio stack (`pipewire`, `wireplumber`, `pipewire-pulse`)
  - Desktop portals (`xdg-desktop-portal-*`) & polkit agents
  - Status bars (`waybar`, `polybar`), launchers (`wofi`, `rofi`, `dmenu`), terminals (`kitty`, `alacritty`, `foot`), and iconic fonts (`ttf-font-awesome`, `noto-fonts`)
- Tailored for Arch packages and Gentoo Portage atoms (e.g. `gui-wm/hyprland`, `x11-wm/i3`, `media-video/pipewire`).
- Works smoothly in root/chroot environments without requiring `sudo`.

### 3. Pre-Rice Profiles & Conflict Resolution Engine (v1.1.0)
- **Dedicated Profiles**: Separate configuration profiles for **Omarchy**, **CachyOS**, **Garuda Linux**, **Omakub**, and modern pre-rices (e.g. **Caelestia**, **Hyprdots**).
- **Collision & Conflict Warning**: Automatically detects potential collisions between active or installed desktop components and incoming rices:
  - Conflicting notification daemons (`dunst` vs `mako` vs `swaync`)
  - Conflicting status bars (`waybar` vs `polybar` vs `ags` vs `latte-dock`)
  - Conflicting wallpaper daemons (`swww` vs `hyprpaper` vs `mpvpaper`)
  - Conflicting theme switchers, autostart services, and shell hooks
- **Automated Conflict Avoidance & Quarantine**:
  - Halts colliding background processes before new rice deployment
  - Quarantines and isolates conflicting autostart configs and includes into timestamped backups
- **Automatic Dependency Resolution**:
  - Automatically identifies tools and dependencies required by the incoming rice that are missing on the host
  - Injects native package manager installation steps into the plan automatically

### 4. Scriptless Dotfile Repositories
- Handles repositories that lack any install or setup script.
- Intelligently maps folders and configs:
  - `.config/` directories into `~/.config/`
  - Root app folders (`hypr/`, `nvim/`, `waybar/`, etc.) into `~/.config/<app>`
  - Root dotfiles (`.bashrc`, `.zshrc`, `.tmux.conf`, etc.) into `~/`
  - GNU Stow multi-package layouts and chezmoi dotfile repositories

### 5. GRUB Bootloader Customization
- Detects GRUB bootloader presence (`RICER_HAS_GRUB`).
- Identifies GRUB theme repos and directories containing `theme.txt`.
- Automatically copies themes to `/boot/grub/themes/` (or `/boot/grub2/themes/`).
- Backs up `/etc/default/grub` and safely sets `GRUB_THEME`.
- Automatically executes `grub-mkconfig` or `update-grub`.

### 6. Safe Backup & Restore System
- Automatic timestamped backups of displaced configs into `~/.config-backup-<timestamp>` before modifying anything.
- Subcommand `ricer restore` to quickly roll back to the latest backup.
- Configurable with `--no-backup` flag for ephemeral or disposable environments.

### 7. Offline Rule Engine Fallback
- Built-in deterministic pattern matcher supporting 8 structural patterns:
  - Explicit scripts (`install.sh`, `setup.sh`, `rice.sh`, etc.)
  - GRUB bootloader themes
  - chezmoi dotfiles
  - GNU Stow packages
  - Bare git repos (`yadm`/`home-manager` style)
  - `.config` directory structure
  - Root dotfiles
  - Root app config directories
- Automatically used when offline (`--offline`) or when cloud AI service is unreachable.

### 8. CLI Lifecycle & Self-Management
- `ricer update`: Atomic self-update command supporting both git clones and cURL-installed setups (with GitHub release and tag API fallbacks).
- `ricer uninstall`: Clean interactive removal of binary, libraries, and share files while preserving user backups.
- `ricer detect`: Formatted system diagnostic display compatible with pure ASCII terminals and minimal TTYs.
- CLI flags: `--dry-run`, `--offline`, `--no-backup`, `--model`, `--version`, `--help`.
