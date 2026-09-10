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
- `ricer update --latest`: Update channel pulling the latest git tag (`/tags`), allowing users and developers to update to the latest tagged edge versions before a formal GitHub release is published.
- `ricer update --beta`: Dedicated beta update channel specifically querying and installing tags named like `v1.x.y Beta`.
- Both modes support git clones (developer mode checking out target tag/release) and cURL-installed setups (atomic downloads pinned to the target version).
- `ricer uninstall`: Clean interactive removal of binary, libraries, and share files while preserving user backups.
- `ricer detect`: Formatted system diagnostic display compatible with pure ASCII terminals and minimal TTYs.
- **Orphan package pruning**: `--clean-orphans` flag (aliases: `--remove-orphans`, `--prune-orphans`) to automatically identify and clean up unneeded dependencies and orphaned packages across all supported package managers (`pacman -Rns $(pacman -Qtdq)`, `apt autoremove`, `dnf autoremove`, `emerge --depclean`, etc.) after rice installation.
- CLI flags: `--dry-run`, `--local`, `--offline`, `--no-backup`, `--clean-orphans`, `--latest`, `--beta`, `--model`, `--version`, `--help`.

### 9. Security, Data Safety & Robustness Hardening (v1.2.2)
- **Path Normalization & Deletion Guards**: Target paths are normalized with trailing-slash removal (`${dst%/}`); strict safety invariants prevent `rm -rf` from ever executing against `$HOME`, `$HOME/.config`, or `/` under any circumstances (including `~` or relative dotfile copies).
- **Safe Command Execution**: Commands run via `_run_in_repo` preserve distinct argument boundaries, preventing command flattening and shell injection vulnerabilities. Discovered install scripts are automatically verified and given executable permissions (`chmod +x`) prior to invocation.
- **Port Collision & Daemon Isolation**: Background AI server spawning (Ollama on port `11434` or llama-server on port `8080`) incorporates non-blocking socket checks (`_port_in_use`) to avoid port collisions with existing services.
- **Defensive Shell Standards**:
  - Array-based orphan package pruning eliminates unquoted word-splitting risks (ShellCheck SC2086).
  - CPU and GPU model parsing utilizes POSIX regex trimming (`sed -E`) to prevent `xargs` crashes on unmatched quotes.
  - Enforces `LC_ALL=C` across all floating-point `awk` calculations for parameter size checks (>4B) and RAM diagnostics.
  - Interactive prompts (`confirm`) emit strictly to `stderr` (`>&2`), preserving pure stdout data streams for JSON pipelines.

### 10. Threat Modeling & DevSecOps Hardening (v1.2.3)
- **Indirect Prompt Injection Defense (SEC-01)**: The AI engine is strictly confined to declarative filesystem operations (`copy`, `symlink`, `stow`, `install_pkg`, `grub_theme`). `run_cmd` is entirely stripped from AI-generated plans to eliminate prompt injection risks from adversarial `README.md` or repository file trees.
- **Sensitive Directory Sandboxing (SEC-02)**: Path resolution (`realpath -m`) blocks any attempt to copy or symlink into sensitive user credential directories (`~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.local/share/keyrings`, `/etc/shadow`, `/etc/sudoers`).
- **Git Option Injection Prevention**: Injects `--` argument delimiters before repository URLs in `git clone` commands to neutralize flag-based injection attacks.
- **Privacy Notice & Telemetry Awareness (SEC-04)**: Warns users when using the cloud AI backend and recommends `--local` or `--offline` for private or sensitive repositories.

### 11. Desktop Configuration Repackaging & Format Preservation (v1.3.0)
- **Subcommand `ricer repack`**: Packages the active desktop environment, keybindings, widgets, status bars, terminal configs, and wallpaper into an install-ready `.zip` archive saved by default into the user's `~/Downloads` folder (or user-specified filename/path).
- **Active Wallpaper Identification**: Multi-layer detection engine queries running services and config trees:
  - Compositor wallpaper daemons: `swww query`, `hyprpaper.conf`, `swaybg`, `feh --bg-fill` (`~/.fehbg`).
  - Pre-rice wallpaper stores: `~/.config/omarchy/backgrounds`, `~/.config/omarchy/wallpaper`, `~/.config/caelestia/wallpaper`, `~/.local/share/caelestia/wallpapers`, `/usr/share/wallpapers/garuda-wallpapers`.
  - Fallback scanning: `~/Pictures/Wallpapers`, `~/Pictures/Wallpaper`, `~/Pictures`, `~/.wallpapers`.
- **Ecosystem & Rice Format Implementations**:
  - **`omarchy`**: Packages the Omarchy desktop stack (`omarchy`, `hypr`, `waybar`, `mako`, `foot`, `kitty`, `fastfetch`, `cava`, `btop`, `alacritty`, `ghostty`) and configures post-install Omarchy hooks.
  - **`caelestia`**: Packages Caelestia widgets and controls (`caelestia`, `ags`, `hypr`, `waybar`, `rofi`, `wofi`, `dunst`, `swaync`, `kitty`, `alacritty`, `fastfetch`) and provisions AGS live restart hooks.
  - **`garuda`**: Packages Garuda desktop and shell configs (`garuda`, `hypr`, `waybar`, `fish`, `swaync`, `dunst`, `alacritty`, `kitty`, `fastfetch`, `starship.toml`) and configures Garuda desktop hooks.
  - **`generic` / Auto-resolve**: Detects pre-rice configuration automatically using `detect_pre_rice` or falls back to common Linux desktop components (`hypr`, `sway`, `i3`, `bspwm`, `river`, `waybar`, `polybar`, `mako`, `dunst`, `rofi`, `wofi`, terminals, system monitors, etc.).
- **Self-Contained Installer & Metadata Manifest**:
  - Automatically synthesizes a root `install.sh` in each repacked archive that backs up destination files, installs `.config` folders, copies wallpapers into `~/Pictures/Wallpapers/`, reloads the compositor, and reapplies wallpaper. Works standalone or via `ricer install <zip>`.
  - Generates a structured `rice.json` manifest recording format, window manager, captured config directories, active wallpaper filename, generator version, and UTC capture timestamp.
  - Includes an autogenerated `README.md` explaining archive contents and installation instructions.
- **Hygiene & Sanitization**:
  - Strips `.git`, `.github`, and version control metadata from nested theme repositories (reducing archive footprints significantly).
  - Automatically excludes socket files (`*.sock`), logs (`*.log`), caches (`*.cache`), and sensitive secret patterns (`*.key`, `*.pem`, `*token*`, `*secret*`, `*credential*`).
- **Archive Generation & Tool Fallback**:
  - Prioritizes system `zip` utility; falls back seamlessly to Python 3 / Python standard library `zipfile` module when `zip` is uninstalled.

### 12. Limine Bootloader & systemd Ecosystem Architecture (v1.3.1)
- **Limine Bootloader Detection & Theme Customization**:
  - Automatic detection of Limine bootloader (`RICER_BOOTLOADER="limine"`, `RICER_HAS_LIMINE="true"`) inspecting `limine` command and config/boot directories (`/boot/limine`, `/boot/efi/limine`, `/efi/limine`, `/boot/limine.conf`, `/boot/limine.cfg`).
  - Automatic identification of Limine themes and configurations from repositories containing `limine.conf` or `limine.cfg`.
  - Installs theme assets (backgrounds, fonts, bitmaps) into `/boot/limine/themes/` and safely updates styling keys (`wallpaper:`, `term_font:`) in the active `limine.conf`.
  - Automatic backup of existing `limine.conf` / `limine.cfg` into `~/.config-backup-<timestamp>` and restoration via `ricer restore`.
- **systemd-boot Splash & Configuration**:
  - Detects `systemd-boot` presence (`RICER_BOOTLOADER="systemd-boot"`, `RICER_HAS_SYSTEMD_BOOT="true"`).
  - Identifies `loader.conf` or splash image files (`splash.bmp`, `splash.png`) and installs them to `/boot/loader` / `/efi/loader`.
  - Backs up and restores `loader.conf` across updates and restorations.
- **systemd Init & User Units Management**:
  - Detects active init system (`RICER_INIT_SYSTEM="systemd"`, `RICER_HAS_SYSTEMD="true"`).
  - Automatically triggers non-intrusive `systemctl --user daemon-reload` whenever user units (`~/.config/systemd/user`) are copied or symlinked.
  - Supports declarative `systemd_service` step type in plans to enable and manage user services (`hypridle`, `swww`, `swaync`, `mpd`, etc.).
  - `ricer repack` captures active user services in `~/.config/systemd/user/` and includes automatic daemon reloading in the generated standalone installer.



