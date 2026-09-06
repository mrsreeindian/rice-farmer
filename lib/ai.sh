#!/usr/bin/env bash
# lib/ai.sh — AI backend: Pollinations.ai (primary) + Ollama (if already running)

POLLINATIONS_TEXT="https://text.pollinations.ai"
AI_TIMEOUT=40   # seconds before falling back to rule engine
RICER_AI_BACKEND=""

# ── Backend detection ──────────────────────────────────────────────────────────
detect_ai_backend() {
  # Prefer local Ollama if already running (offline, faster)
  if curl -s --max-time 2 http://localhost:11434/api/tags &>/dev/null; then
    RICER_AI_BACKEND="ollama"
    # Pick best available model (smallest first for low-end hw)
    for model in llama3.2:3b llama3.2 llama3.1 mistral phi3; do
      if curl -s http://localhost:11434/api/tags | grep -q "\"$model\""; then
        RICER_OLLAMA_MODEL="$model"
        break
      fi
    done
    RICER_OLLAMA_MODEL="${RICER_OLLAMA_MODEL:-llama3.2}"
    log_dim "AI: Ollama (${RICER_OLLAMA_MODEL})"
  else
    RICER_AI_BACKEND="pollinations"
    log_dim "AI: Pollinations.ai (cloud, no key)"
  fi
  export RICER_AI_BACKEND
}

# ── URL-encode a string (pure bash, no python required) ───────────────────────
_urlencode() {
  local string="$1" encoded="" c
  for (( i=0; i<${#string}; i++ )); do
    c="${string:$i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) encoded+="$c" ;;
      ' ') encoded+="%20" ;;
      $'\n') encoded+="%0A" ;;
      *) encoded+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  echo "$encoded"
}

# ── Build structured prompt ────────────────────────────────────────────────────
build_prompt() {
  local repo_dir="$1" github_url="$2"

  # Gather repo info (limit sizes to keep prompt short → faster response)
  local tree readme
  tree=$(find "$repo_dir" -maxdepth 3 \
           ! -path '*/.git/*' ! -name '*.png' ! -name '*.jpg' \
           -printf '%P\n' 2>/dev/null | head -80 || true)
  if [ -f "$repo_dir/README.md" ]; then
    readme=$(head -80 "$repo_dir/README.md")
  elif [ -f "$repo_dir/readme.md" ]; then
    readme=$(head -80 "$repo_dir/readme.md")
  elif [ -f "$repo_dir/README" ]; then
    readme=$(head -80 "$repo_dir/README")
  else
    readme="(no README found)"
  fi

  cat <<PROMPT
You are an expert Linux ricing and dotfile automation assistant.
Analyze the repository structure and output ONLY a raw JSON array of install steps.
No markdown fences, no code blocks, no chat explanation, just the raw JSON array.

CRITICAL INSTRUCTIONS:
1. EVEN IF THERE IS NO INSTALL SCRIPT (no install.sh, setup.sh, Makefile, etc.), YOU MUST STILL INSTALL AND CONFIGURE THE RICE:
   - Identify configuration folders (e.g., nvim, hypr, sway, i3, waybar, rofi, kitty, alacritty, polybar, fastfetch, dunst, fish, zsh, tmux, etc.).
   - If directories belong in ~/.config/, map each folder with "copy": ["<folder>", "~/.config/<folder>"] or "symlink".
   - If files are dotfiles for the home directory (e.g., .bashrc, .zshrc, .tmux.conf), map them to "~/<file>".
   - If the repository has a GNU Stow structure (packages containing .config or dotfiles), use {"type":"stow","args":["."],"description":"Stow dotfiles"}.
   - Identify any obvious software dependencies from the configs or README (e.g. hyprland, waybar, rofi, kitty, neovim, tmux) and include an "install_pkg" step for package manager (${RICER_PM_CMD:-pacman}).
2. Never return an empty array if there are any config files or directories present.

System context:
  distro: ${RICER_DISTRO} (${RICER_DISTRO_PRETTY})
  wm: ${RICER_WM}
  session: ${RICER_SESSION}
  package_managers: ${RICER_PKG_MANAGERS}
  canonical_pm: ${RICER_PM_CMD}
  arch: ${RICER_ARCH}

Rice repo URL: ${github_url}

Repo file tree (top 3 levels):
${tree}

README (first 80 lines):
${readme}

Output format:
[
  { "type": "install_pkg", "args": ["pkg1", "pkg2"], "description": "Install required packages" },
  { "type": "copy",        "args": ["<src_rel_path>", "~/.config/<app>"], "description": "Install <app> config" },
  { "type": "stow",        "args": ["."],           "description": "Stow all dotfiles" },
  { "type": "symlink",     "args": ["<src>", "<dst>"], "description": "Symlink config" },
  { "type": "run_cmd",     "args": ["<command>"],   "description": "Run command" }
]

Valid types: install_pkg, copy, symlink, stow, run_cmd.
Output raw JSON only.
PROMPT
}

# ── Ask Pollinations.ai (anonymous GET — free, no key) ────────────────────────
_ask_pollinations() {
  local prompt="$1"
  local encoded
  encoded=$(_urlencode "$prompt")

  # --no-netrc: guarantees anonymous request (no injected auth credentials)
  # -f: fail silently on 4xx/5xx (returns non-zero exit code)
  local response http_code
  http_code=$(curl -o /tmp/ricer_ai_resp.tmp -s -w "%{http_code}" \
    --max-time "$AI_TIMEOUT" \
    --no-netrc \
    --no-keepalive \
    "${POLLINATIONS_TEXT}/${encoded}" 2>/dev/null || echo "000")

  case "$http_code" in
    200) cat /tmp/ricer_ai_resp.tmp ;;
    402) log_warn "Pollinations.ai: rate limit hit — falling back to rule engine." ;;
    000) log_warn "Pollinations.ai: request timed out (${AI_TIMEOUT}s) — falling back." ;;
    *)   log_warn "Pollinations.ai: HTTP ${http_code} — falling back to rule engine." ;;
  esac
  rm -f /tmp/ricer_ai_resp.tmp
}

# ── Ask Ollama ─────────────────────────────────────────────────────────────────
_ask_ollama() {
  local prompt="$1"
  curl -s --max-time "$AI_TIMEOUT" \
    http://localhost:11434/api/generate \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg model "$RICER_OLLAMA_MODEL" --arg p "$prompt" \
      '{model:$model, prompt:$p, stream:false, format:"json"}')" 2>/dev/null \
  | jq -r '.response // empty' 2>/dev/null
}

# ── Main entry: get install plan from AI ──────────────────────────────────────
get_ai_plan() {
  local repo_dir="$1" github_url="$2"
  local prompt response

  detect_ai_backend
  prompt=$(build_prompt "$repo_dir" "$github_url")

  spinner_start "Asking AI for install plan..."
  if [ "$RICER_AI_BACKEND" = "ollama" ]; then
    response=$(_ask_ollama "$prompt")
  else
    response=$(_ask_pollinations "$prompt")
  fi
  spinner_stop

  # Try to extract a JSON array from the response
  local plan
  plan=$(echo "$response" | jq '
    if type == "array" then .
    elif type == "object" then
      (.steps // .plan // .install_steps // .commands // .[keys[0]])
      | if type == "array" then . else null end
    else null
    end
  ' 2>/dev/null)

  if [ -n "$plan" ] && [ "$plan" != "null" ]; then
    echo "$plan"
    return 0
  else
    log_warn "Could not parse AI response — using built-in rule engine."
    return 1
  fi
}
