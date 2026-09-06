#!/usr/bin/env bash
# lib/ai.sh — AI backend: Pollinations.ai (primary) + Ollama (if already running)

POLLINATIONS_TEXT="https://text.pollinations.ai"
POLLINATIONS_OPENAI="https://text.pollinations.ai/openai"
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
You are a Linux rice/dotfile installer assistant. Analyze the repo and output ONLY a raw JSON array of install steps — no markdown fences, no explanation, just the JSON.

System context:
  distro: ${RICER_DISTRO} (${RICER_DISTRO_PRETTY})
  wm: ${RICER_WM}
  session: ${RICER_SESSION}
  package_managers: ${RICER_PKG_MANAGERS}
  arch: ${RICER_ARCH}

Rice repo URL: ${github_url}

Repo file tree (top 3 levels):
${tree}

README (first 80 lines):
${readme}

Output a JSON array where each element is one step:
[
  { "type": "install_pkg", "args": ["pkg1","pkg2"], "description": "Install required packages" },
  { "type": "stow",        "args": ["."],           "description": "Stow all dotfiles" },
  { "type": "copy",        "args": ["src","dst"],   "description": "Copy config file" },
  { "type": "symlink",     "args": ["src","dst"],   "description": "Create symlink" },
  { "type": "run_cmd",     "args": ["command"],     "description": "Run setup command" }
]

Valid types: install_pkg, stow, copy, symlink, run_cmd.
For paths, use ~ for home directory. Be concise. Output raw JSON only.
PROMPT
}

# ── Ask Pollinations.ai ────────────────────────────────────────────────────────
_ask_pollinations() {
  local prompt="$1"
  local encoded
  encoded=$(_urlencode "$prompt")

  # POST to the OpenAI-compatible endpoint for better JSON reliability
  curl -fsSL --max-time "$AI_TIMEOUT" \
    -X POST "$POLLINATIONS_OPENAI" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n \
      --arg model "openai" \
      --arg content "$prompt" \
      '{model: $model, messages: [{role:"system", content:"You are a Linux rice installer. Output only raw JSON arrays."},{role:"user",content:$content}], response_format:{type:"json_object"}}'
    )" 2>/dev/null \
  | jq -r '.choices[0].message.content // empty' 2>/dev/null \
  || curl -fsSL --max-time "$AI_TIMEOUT" \
       "${POLLINATIONS_TEXT}/${encoded}?model=openai&json=true" 2>/dev/null
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
