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

### 4. Local-First Architecture & AI Filesystem Engine (v1.2.0)
- **Local-First & Zero-Online Initial Phase**: Searches repository files for an install script (`install.sh`, `setup.sh`, `bootstrap.sh`, `rice.sh`, `deploy.sh`, etc.) first. If found, AI is never initialized and zero online calls are made; the script is executed directly.
- **Local AI Auto-Discovery**: When no install script exists, Rice Farmer automatically searches for local models in:
  - **Ollama**: Queries local daemon or spins up local server to inspect installed model tags and parameter sizes.
  - **llama.cpp**: Connects to active `llama-server` instances or discovers local `.gguf` weights (`~/models`, `~/.cache/llama.cpp`, `~/.local/share/models`).
- **4B Parameter Capability Threshold**:
  - Automatically evaluates model parameter count (e.g. `8B`, `7B`, `14B` vs `0.6B`, `1B`, `3B`).
  - If a local model with **over 4B parameters** (`> 4B`) is found, it initializes and executes the plan locally without touching online endpoints.
  - If local models have **4B parameters or fewer**, Rice Farmer displays a clear warning (`Your local model is not powerful enough`) and falls back to online models (or the rule engine if `--offline`).
- **`--local` Flag**: Dedicated flag to explicitly prioritize local Ollama and llama.cpp models.
- **AI Exclusively for Filesystem Moves & Modifications**: AI is only initialized when no install script exists in the repository. Its role is strictly to inspect the configuration tree and generate filesystem operations (`copy`, `symlink`, `stow`, `grub_theme`) to deploy configs into `~/.config/` and `$HOME`.
- **Scriptless Dotfile Repositories**: Intelligently handles repositories that lack any install or setup script:
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
- `ricer update`: Atomic self-update pulling the latest official GitHub release only (`/releases/latest`), preventing untested edge updates or unintended downgrades.
- `ricer update --beta`: Update channel pulling the latest git tag (`/tags`), allowing users and developers to update to the latest tagged beta/edge versions before a formal GitHub release is published.
- Both modes support git clones (developer mode checking out target tag/release) and cURL-installed setups (atomic downloads pinned to the target version).
- `ricer uninstall`: Clean interactive removal of binary, libraries, and share files while preserving user backups.
- `ricer detect`: Formatted system diagnostic display compatible with pure ASCII terminals and minimal TTYs.
- **Orphan package pruning**: `--clean-orphans` flag (aliases: `--remove-orphans`, `--prune-orphans`) to automatically identify and clean up unneeded dependencies and orphaned packages across all supported package managers (`pacman -Rns $(pacman -Qtdq)`, `apt autoremove`, `dnf autoremove`, `emerge --depclean`, etc.) after rice installation.
- CLI flags: `--dry-run`, `--local`, `--offline`, `--no-backup`, `--clean-orphans`, `--beta`, `--model`, `--version`, `--help`.


