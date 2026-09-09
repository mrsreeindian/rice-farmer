#!/usr/bin/env bash
# lib/ai.sh — AI backend: Pollinations.ai (primary) + Ollama (if already running)

POLLINATIONS_TEXT="https://text.pollinations.ai"
AI_TIMEOUT=40   # seconds before falling back to rule engine
RICER_AI_BACKEND=""
RICER_OLLAMA_MODEL=""
RICER_LLAMACPP_URL=""
RICER_LLAMA_CLI_MODEL=""
RICER_SPAWNED_SERVER_PID=""

# ── Parameter size evaluation (>4B check) ──────────────────────────────────────
_is_over_4b() {
  local raw="$1"
  awk -v str="$raw" '
    BEGIN {
      s = tolower(str)
      if (s ~ /[0-9]+(\.[0-9]+)?m/) { print 0; exit }
      if (match(s, /([0-9]+(\.[0-9]+)?)[[:space:]]*b/, arr)) {
        print ((arr[1] + 0) > 4.0) ? 1 : 0
        exit
      }
      if (match(s, /[:\-_]([0-9]+(\.[0-9]+)?)[a-z]*/, arr)) {
        print ((arr[1] + 0) > 4.0) ? 1 : 0
        exit
      }
      if (s ~ /^[0-9]+(\.[0-9]+)?$/) {
        print ((s + 0) > 4.0) ? 1 : 0
        exit
      }
      print 0
    }
  '
}

_get_param_str() {
  local raw="$1"
  awk -v str="$raw" '
    BEGIN {
      s = tolower(str)
      if (match(s, /([0-9]+(\.[0-9]+)?)[[:space:]]*b/, arr)) { print arr[1] "B"; exit }
      if (match(s, /[:\-_]([0-9]+(\.[0-9]+)?)[a-z]*/, arr)) { print arr[1] "B"; exit }
      if (match(s, /([0-9]+(\.[0-9]+)?)[[:space:]]*m/, arr)) { print arr[1] "M"; exit }
      print str
    }
  '
}

# ── Backend detection (Local-First: Ollama & llama.cpp, threshold >4B) ─────────
detect_ai_backend() {
  RICER_AI_BACKEND=""
  local is_forced_local="${RICER_LOCAL:-false}"

  if [ "$is_forced_local" = "true" ]; then
    log_info "Local AI flag (--local) active. Searching for local models in Ollama and llama.cpp..."
  else
    log_info "Local-first check: searching for local models in Ollama and llama.cpp..."
  fi

  local -a candidates=()   # format: type|name|pstr|is_over_4b|path_or_url

  # ── 1. Check Ollama ────────────────────────────────────────────────────────
  local ollama_tags=""
  local ollama_running=false

  if ollama_tags=$(curl -fsSL --max-time 1 "http://127.0.0.1:11434/api/tags" 2>/dev/null); then
    ollama_running=true
  elif command -v ollama &>/dev/null; then
    log_dim "Starting local Ollama server to inspect models..."
    ollama serve >/dev/null 2>&1 &
    local opid=$!
    for _ in {1..10}; do
      if ollama_tags=$(curl -fsSL --max-time 1 "http://127.0.0.1:11434/api/tags" 2>/dev/null); then
        ollama_running=true
        RICER_SPAWNED_SERVER_PID="$opid"
        break
      fi
      sleep 0.2
    done
  fi

  if [ "$ollama_running" = "true" ] && [ -n "$ollama_tags" ]; then
    local count
    count=$(echo "$ollama_tags" | jq '.models | length' 2>/dev/null || echo 0)
    for (( i=0; i<count; i++ )); do
      local mname mparam
      mname=$(echo "$ollama_tags" | jq -r ".models[$i].name // empty")
      mparam=$(echo "$ollama_tags" | jq -r ".models[$i].details.parameter_size // empty")
      [ -z "$mparam" ] && mparam="$mname"
      local is_over pstr
      is_over=$(_is_over_4b "$mparam")
      pstr=$(_get_param_str "$mparam")
      candidates+=("ollama|${mname}|${pstr}|${is_over}|http://127.0.0.1:11434")
    done
  fi

  # ── 2. Check llama.cpp ──────────────────────────────────────────────────────
  local llamacpp_models=""
  local llamacpp_running=false

  if llamacpp_models=$(curl -fsSL --max-time 1 "http://127.0.0.1:8080/v1/models" 2>/dev/null); then
    llamacpp_running=true
    local count
    count=$(echo "$llamacpp_models" | jq '.data | length' 2>/dev/null || echo 0)
    for (( i=0; i<count; i++ )); do
      local mid
      mid=$(echo "$llamacpp_models" | jq -r ".data[$i].id // empty")
      local is_over pstr
      is_over=$(_is_over_4b "$mid")
      pstr=$(_get_param_str "$mid")
      candidates+=("llamacpp|${mid}|${pstr}|${is_over}|http://127.0.0.1:8080")
    done
  fi

  # Search disk for GGUF models for llama-server or llama-cli
  local -a gguf_files=()
  for search_dir in "$HOME/models" "$HOME/.cache/llama.cpp" "$HOME/.local/share/models" "/usr/share/models" "${MODELS_DIR:-}"; do
    [ -d "$search_dir" ] || continue
    while IFS= read -r -d '' f; do
      gguf_files+=("$f")
    done < <(find "$search_dir" -maxdepth 2 -name "*.gguf" -type f -print0 2>/dev/null)
  done

  for gfile in "${gguf_files[@]}"; do
    local gname is_over pstr
    gname=$(basename "$gfile")
    is_over=$(_is_over_4b "$gname")
    pstr=$(_get_param_str "$gname")
    candidates+=("llama-file|${gname}|${pstr}|${is_over}|${gfile}")
  done

  # ── 3. Evaluate local candidates ───────────────────────────────────────────
  local chosen=""
  local fallback_candidate=""

  for entry in "${candidates[@]}"; do
    IFS="|" read -r ctype cname cpstr cover cpath <<< "$entry"
    if [ "$cover" -eq 1 ]; then
      chosen="$entry"
      break
    fi
    [ -z "$fallback_candidate" ] && fallback_candidate="$entry"
  done

  if [ -n "$chosen" ]; then
    IFS="|" read -r ctype cname cpstr cover cpath <<< "$chosen"
    case "$ctype" in
      ollama)
        RICER_AI_BACKEND="ollama"
        RICER_OLLAMA_MODEL="$cname"
        log_ok "Local Ollama model initialized: ${cname} (${cpstr} > 4B). Using local AI."
        ;;
      llamacpp)
        RICER_AI_BACKEND="llamacpp"
        RICER_LLAMACPP_URL="$cpath"
        log_ok "Local llama.cpp server active: ${cname} (${cpstr} > 4B). Using local AI."
        ;;
      llama-file)
        if command -v llama-server &>/dev/null; then
          log_dim "Initializing llama-server with ${cname} on port 8080..."
          llama-server -m "$cpath" --port 8080 >/dev/null 2>&1 &
          local lpid=$!
          RICER_SPAWNED_SERVER_PID="$lpid"
          for _ in {1..15}; do
            if curl -fsSL --max-time 1 "http://127.0.0.1:8080/v1/models" &>/dev/null; then
              break
            fi
            sleep 0.2
          done
          RICER_AI_BACKEND="llamacpp"
          RICER_LLAMACPP_URL="http://127.0.0.1:8080"
          log_ok "Local llama.cpp model initialized: ${cname} (${cpstr} > 4B). Using local AI."
        elif command -v llama-cli &>/dev/null; then
          RICER_AI_BACKEND="llama-cli"
          RICER_LLAMA_CLI_MODEL="$cpath"
          log_ok "Local llama-cli model selected: ${cname} (${cpstr} > 4B). Using local AI."
        fi
        ;;
    esac
    export RICER_AI_BACKEND RICER_OLLAMA_MODEL RICER_LLAMACPP_URL RICER_LLAMA_CLI_MODEL
    return 0
  fi

  # If models were found but none has over 4B parameters
  if [ -n "$fallback_candidate" ]; then
    IFS="|" read -r ftype fname fpstr fover fpath <<< "$fallback_candidate"
    log_warn "Local model '${fname}' has only ${fpstr} parameters (minimum > 4B required for accurate dotfile planning)."
    log_warn "Your local model is not powerful enough. Falling back to online model..."
  elif [ "$is_forced_local" = "true" ]; then
    log_warn "No local models found in Ollama or llama.cpp. Falling back to online model..."
  fi

  RICER_AI_BACKEND="pollinations"
  export RICER_AI_BACKEND
  log_dim "AI: Pollinations.ai (cloud, no key)"
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
1. NO INSTALL SCRIPT EXISTS IN THIS REPOSITORY (no install.sh, setup.sh, bootstrap.sh, etc.).
   YOU ARE SPECIFICALLY CALLED TO MOVE AND MODIFY THE FILESYSTEM to deploy the dotfiles:
   - Identify configuration folders (e.g., nvim, hypr, sway, i3, waybar, rofi, kitty, alacritty, polybar, fastfetch, dunst, fish, zsh, tmux, etc.).
   - If directories belong in ~/.config/, map each folder with "copy": ["<folder>", "~/.config/<folder>"] or "symlink".
   - If the repository contains a GRUB theme (theme.txt, background images, fonts), use {"type":"grub_theme","args":["<theme_dir_or_.>","<theme_name>"],"description":"Install GRUB bootloader theme"}.
   - If files are dotfiles for the home directory (e.g., .bashrc, .zshrc, .tmux.conf), map them to "~/<file>".
   - If the repository has a GNU Stow structure (packages containing .config or dotfiles), use {"type":"stow","args":["."],"description":"Stow dotfiles"}.

2. BAREBONES ARCH / GENTOO SYSTEM HANDLING (is_barebones: ${RICER_IS_BAREBONES:-false}):
   - If the system is barebones (TTY only, no window manager or desktop environment installed):
     YOU MUST AUTO-INSTALL THE DESKTOP ENVIRONMENT / WINDOW MANAGER AND ALL SUPPORTING INFRASTRUCTURE:
     * Identify the target WM/DE from the repository (e.g., Hyprland, Sway, i3, BSPWM, River, Awesome, KDE Plasma, GNOME, XFCE).
     * Add an initial "install_pkg" step installing the WM/DE and core display infrastructure:
       - On Arch Linux (${RICER_PM_CMD:-pacman}):
         * If Hyprland rice: ["hyprland", "waybar", "wofi", "kitty", "polkit-kde-agent", "xdg-desktop-portal-hyprland", "qt5-wayland", "qt6-wayland", "pipewire", "pipewire-pulse", "wireplumber", "ttf-font-awesome", "noto-fonts"]
         * If Sway rice: ["sway", "swaybg", "waybar", "wofi", "foot", "polkit", "xdg-desktop-portal-wlr"]
         * If i3 rice: ["xorg-server", "xorg-xinit", "i3-wm", "i3status", "dmenu", "alacritty", "picom", "feh"]
         * If KDE/Plasma: ["plasma-meta", "sddm"]
         * If GNOME: ["gnome", "gdm"]
       - On Gentoo (${RICER_PM_CMD:-emerge}):
         * Target proper package atoms (e.g., gui-wm/hyprland, gui-wm/sway, x11-wm/i3, gui-apps/waybar, x11-terms/kitty, media-video/pipewire).
     * Also install any application dependencies found in the configs (e.g. rofi, dunst, mako, fastfetch, thunar, pavucontrol, brightnessctl).

3. Never return an empty array if there are any config files or directories present.

System context:
  distro: ${RICER_DISTRO} (${RICER_DISTRO_PRETTY})
  distro_family: ${RICER_DISTRO_FAMILY} (e.g. ubuntu/debian, redhat, arch, gentoo, opensuse)
  is_barebones: ${RICER_IS_BAREBONES:-false}
  pre_rice: ${RICER_PRE_RICE:-none} (e.g. omarchy, cachyos, garuda, omakub, caelestia, or none)
  wm: ${RICER_WM}
  session: ${RICER_SESSION}
  bootloader: ${RICER_BOOTLOADER} (grub_available: ${RICER_HAS_GRUB})
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
  { "type": "grub_theme",  "args": ["<dir_with_theme.txt>", "<theme_name>"], "description": "Install GRUB bootloader theme" },
  { "type": "stow",        "args": ["."],           "description": "Stow all dotfiles" },
  { "type": "symlink",     "args": ["<src>", "<dst>"], "description": "Symlink config" },
  { "type": "run_cmd",     "args": ["<command>"],   "description": "Run command" }
]

Valid types: install_pkg, copy, symlink, stow, grub_theme, run_cmd.
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
  local base_url="http://127.0.0.1:11434"
  curl -s --max-time "$AI_TIMEOUT" \
    "${base_url}/api/generate" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg model "$RICER_OLLAMA_MODEL" --arg p "$prompt" \
      '{model:$model, prompt:$p, stream:false, format:"json"}')" 2>/dev/null \
  | jq -r '.response // empty' 2>/dev/null
}

# ── Ask llama.cpp server ──────────────────────────────────────────────────────
_ask_llamacpp() {
  local prompt="$1"
  local base_url="${RICER_LLAMACPP_URL:-http://127.0.0.1:8080}"
  local resp=""

  # Try OpenAI-compatible chat completions
  resp=$(curl -s --max-time "$AI_TIMEOUT" \
    "${base_url}/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg p "$prompt" '{messages:[{role:"user", content:$p}], temperature:0.2}')" 2>/dev/null \
    | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)

  # Fallback to native /completion endpoint
  if [ -z "$resp" ]; then
    resp=$(curl -s --max-time "$AI_TIMEOUT" \
      "${base_url}/completion" \
      -H 'Content-Type: application/json' \
      -d "$(jq -n --arg p "$prompt" '{prompt:$p, temperature:0.2, n_predict:2048}')" 2>/dev/null \
      | jq -r '.content // empty' 2>/dev/null || true)
  fi

  echo "$resp"
}

# ── Ask llama-cli ─────────────────────────────────────────────────────────────
_ask_llama_cli() {
  local prompt="$1"
  local model_path="${RICER_LLAMA_CLI_MODEL}"
  llama-cli -m "$model_path" -p "$prompt" -n 2048 --temp 0.2 --log-disable 2>/dev/null || true
}

# ── Main entry: get install plan from AI ──────────────────────────────────────
get_ai_plan() {
  local repo_dir="$1" github_url="$2"
  local prompt response

  detect_ai_backend

  # If backend resolved to online (pollinations) but user requested offline mode, fallback to rules
  if [ "$RICER_AI_BACKEND" != "ollama" ] && [ "$RICER_AI_BACKEND" != "llamacpp" ] && [ "$RICER_AI_BACKEND" != "llama-cli" ]; then
    if [ "${RICER_OFFLINE:-false}" = "true" ]; then
      log_info "Offline mode enabled: skipping online AI and using built-in rule engine."
      return 1
    fi
  fi

  prompt=$(build_prompt "$repo_dir" "$github_url")

  spinner_start "Asking AI (${RICER_AI_BACKEND}) for install plan..."
  case "$RICER_AI_BACKEND" in
    ollama)    response=$(_ask_ollama "$prompt") ;;
    llamacpp)  response=$(_ask_llamacpp "$prompt") ;;
    llama-cli) response=$(_ask_llama_cli "$prompt") ;;
    *)         response=$(_ask_pollinations "$prompt") ;;
  esac
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
