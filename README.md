# Rice Farmer

> Install any Linux rice/dotfiles from a GitHub URL — in one command.

[![version](https://img.shields.io/badge/version-1.0.0-blue)](#)
[![license](https://img.shields.io/badge/license-MIT-green)](#)
[![shell](https://img.shields.io/badge/shell-bash-orange)](#)

**Rice Farmer** is a lightweight (~30 KB), pure-Bash tool that:
- Auto-detects your distro (Ubuntu/Debian, Red Hat/Fedora/CentOS, Arch, Gentoo, openSUSE), WM, package managers, hardware, and bootloader (GRUB)
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

# Check and update Rice Farmer to the latest version
ricer update

# Uninstall Rice Farmer
ricer uninstall
```

### Flags

| Flag | Description |
|---|---|
| `--dry-run` | Show the plan, don't execute |
| `--no-backup` | Skip config backup (use with care) |
| `--offline` | Force rule engine, skip AI call |
| `--model <name>` | Override AI model name (default: `openai`) |

---

## How It Works

```
1. detect    -> reads /proc, /etc/os-release, $XDG_CURRENT_DESKTOP
2. clone     -> git clone --depth=1 <url> /tmp/ricer-XXXX/
3. AI plan   -> AI analyzes repo tree + configs, returns JSON steps
4. confirm   -> shows you the plan, asks for approval
5. execute   -> backup -> install deps -> stow / copy / symlink configs
6. cleanup   -> rm -rf /tmp/ricer-XXXX/
```

The AI step uses a lightweight cloud AI endpoint — no account, no API key, and no heavy local model required. If the AI call fails or you are running offline, the built-in rule engine takes over automatically to handle common dotfile structures and scriptless repositories.

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
