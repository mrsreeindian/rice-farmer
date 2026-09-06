# Rice Farmer

> Install any Linux rice/dotfiles from a GitHub URL — in one command.

[![version](https://img.shields.io/badge/version-0.1.0-blue)](#)
[![license](https://img.shields.io/badge/license-MIT-green)](#)
[![shell](https://img.shields.io/badge/shell-bash-orange)](#)

**Rice Farmer** is a lightweight (~30 KB), pure-Bash tool that:
- Auto-detects your distro, WM, package managers, and hardware
- Uses [Pollinations.ai](https://pollinations.ai) (free, no API key) to generate an intelligent install plan from any dotfiles repo
- Backs up your existing configs before touching anything
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
```

### Flags

| Flag | Description |
|---|---|
| `--dry-run` | Show the plan, don't execute |
| `--no-backup` | Skip config backup (use with care) |
| `--offline` | Force rule engine, skip AI call |
| `--model <name>` | Override Pollinations model (default: `openai`) |

---

## How It Works

```
1. detect    → reads /proc, /etc/os-release, $XDG_CURRENT_DESKTOP
2. clone     → git clone --depth=1 <url> /tmp/ricer-XXXX/
3. AI plan   → Pollinations.ai reads the repo tree + README, returns JSON steps
4. confirm   → shows you the plan, asks for approval
5. execute   → backup → install deps → stow / copy / symlink configs
6. cleanup   → rm -rf /tmp/ricer-XXXX/
```

The AI step calls `https://text.pollinations.ai` — no account, no API key, no local model. If the AI call fails or you're offline, a built-in rule engine handles the 6 most common repo patterns (stow, chezmoi, install.sh, bare-git, `.config/` dir, root dotfiles).

---

## Supported Repo Patterns

| Pattern | Detection |
|---|---|
| `install.sh` / `setup.sh` | Runs the script directly |
| GNU Stow | `.stow-local-ignore` or multi-package layout |
| chezmoi | `.chezmoi/` dir or `dot_*` files |
| Bare git | `bare = true` in `.git/config` |
| Plain `.config/` | Symlinks into `~/.config` |
| Root dotfiles | Copies `.*` files to `$HOME` |

---

## License

MIT © 2026
