# Changelog

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
