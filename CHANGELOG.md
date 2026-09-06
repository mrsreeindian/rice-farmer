# Changelog

## [0.1.2] — 2026-09-06
### Added
- Scriptless dotfile repo support: AI model automatically synthesizes install steps by mapping app config folders to `~/.config/` and dotfiles to `$HOME`, even without `install.sh` or setup scripts
- Enhanced offline rule engine with multi-pattern detection for root-level config directories and software configs
- Added `ricer update` command to pull latest releases from GitHub
- Added `ricer uninstall` command for clean removal
- Pure ASCII output across all terminals

## [0.1.0] — 2026-09-06
### Added
- Initial release
- System detection (distro, WM, package managers, CPU, RAM, GPU)
- Pollinations.ai cloud AI backend (no API key, no local model)
- Ollama auto-detect (used if already running locally)
- Offline rule engine for 6 common dotfile repo patterns
- Config backup & restore
- GNU Stow, copy, symlink, run_cmd install step types
- cURL one-liner installer
- `--dry-run`, `--no-backup`, `--offline`, `--model` flags
