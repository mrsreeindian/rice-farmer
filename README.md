# Rice Farmer

> Install any Linux rice/dotfiles from a GitHub URL — in one command.

[![version](https://img.shields.io/badge/version-1.2.3-blue)](#)
[![license](https://img.shields.io/badge/license-MIT-green)](#)
[![shell](https://img.shields.io/badge/shell-bash-orange)](#)

**Rice Farmer** is a lightweight (~30 KB), pure-Bash tool that:
- Auto-detects your distro (Ubuntu/Debian, Red Hat/Fedora/CentOS, Arch, Gentoo, openSUSE), WM, package managers, hardware, and bootloader (GRUB)
- **Pre-Rice & Desktop Conflict Management**: Separate profiles for **Omarchy**, **CachyOS**, **Garuda**, **Omakub**, and pre-rices (e.g. **Caelestia**, **Hyprdots**); warns of conflicts, automatically isolates/quarantines incompatible configs, stops colliding daemons, and installs missing dependencies
- **Barebones Arch & Gentoo support**: Automatically detects minimal/TTY-only systems without a GUI and installs the required DE/WM stack, display servers/compositors, audio (`pipewire`), portals, waybar, terminals, and fonts
- Uses a free cloud AI model (no API key required) to intelligently install any rice, dotfiles, or GRUB bootloader themes
- Backs up your existing configs (including `/etc/default/grub`) before touching anything
- Works fully offline using a built-in rule engine
- Installs itself via a single `curl` command

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mrsreeindian/rice-farmer/main/installer/install.sh | bash
```

Restart your shell, then:

```bash
ricer --help
```

**Requirements:** `bash`, `curl`, `git`, `jq` (all commonly pre-installed)

---

## Usage

```bash
# Show detected system info
ricer detect

# Install a rice from GitHub
ricer install https://github.com/username/dotfiles

# Preview the plan without making changes
ricer install https://github.com/username/dotfiles --dry-run

# Restore your previous configs
ricer restore

# Check and update Rice Farmer to the latest official release
ricer update

# Update to the latest git tag (beta / edge builds)
ricer update --beta

# Uninstall Rice Farmer
ricer uninstall
```

### Flags

| Flag | Description |
|---|---|
| `--dry-run` | Show the plan, don't execute |
| `--local` | Search for and use local Ollama / llama.cpp models (>4B params) |
| `--no-backup` | Skip config backup (use with care) |
| `--offline` | Force rule engine, skip AI call |
| `--clean-orphans` | Remove orphan/unused packages after install |
| `--beta` | Pull latest git tag instead of release (`ricer update` only) |
| `--model <name>` | Override AI model name (default: `openai`) |

---

## How It Works

```
1. detect    -> reads /proc, /etc/os-release, $XDG_CURRENT_DESKTOP
2. clone     -> git clone --depth=1 <url> /tmp/ricer-XXXX/
3. search    -> searches repo files for install script (skips AI if found)
4. AI plan   -> if no script, searches local models (Ollama, llama.cpp >4B) before online
5. confirm   -> shows you the plan, asks for approval
6. execute   -> backup -> install deps -> stow / copy / symlink / run script
7. cleanup   -> rm -rf /tmp/ricer-XXXX/
```

Rice Farmer is **local-first**:
1. **File Search First**: It searches repository files first. If an install script (`install.sh`, `setup.sh`, etc.) is present, it executes the script and never touches AI or online endpoints.
2. **Local AI Discovery**: When no install script exists, it searches for local models in **Ollama** and **llama.cpp** before attempting any online requests.
3. **4B Parameter Threshold**: It verifies if the local model has over 4B parameters (`>4B`). If found, it initializes and runs inference locally. If the local model has 4B parameters or fewer, it warns the user and falls back to the online model (or built-in rule engine if `--offline` is set).

---

## Supported Repo Patterns

| Pattern | Detection |
|---|---|
| `install.sh` / `setup.sh` | Runs the script directly |
| GRUB Theme | `theme.txt` in root or subdirectory |
| GNU Stow | `.stow-local-ignore` or multi-package layout |
| chezmoi | `.chezmoi/` dir or `dot_*` files |
| Bare git | `bare = true` in `.git/config` |
| Plain `.config/` | Installs each subfolder into `~/.config` |
| Root dotfiles | Copies `.*` files to `$HOME` |

---

## License

MIT © 2026
