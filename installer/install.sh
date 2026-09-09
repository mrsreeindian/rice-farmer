#!/usr/bin/env bash
# installer/install.sh — cURL bootstrap for Rice Farmer
# Usage: curl -fsSL https://raw.githubusercontent.com/mrsreeindian/rice-farmer/main/installer/install.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/mrsreeindian/rice-farmer/main"
BIN_DIR="${HOME}/.local/bin"
LIB_DIR="${HOME}/.local/lib/ricer"

# ── Colours (minimal, no sourcing) ───────────────────────────────────────────
G='\033[0;32m'; C='\033[0;36m'; Y='\033[0;33m'; R='\033[0;31m'; N='\033[0m'
info()  { echo -e "${C}[*]${N} $*"; }
ok()    { echo -e "${G}[+]${N} $*"; }
warn()  { echo -e "${Y}[!]${N} $*"; }
die()   { echo -e "${R}[x]${N} $*" >&2; exit 1; }

# ── Dependency check ──────────────────────────────────────────────────────────
for dep in curl git jq bash; do
  command -v "$dep" &>/dev/null || die "Required tool missing: $dep — install it and retry."
done

# ── Fetch version ─────────────────────────────────────────────────────────────
VERSION=$(curl -fsSL --max-time 10 "${REPO_RAW}/.version" 2>/dev/null || echo "?")
echo ""
echo -e "  ${C}Rice Farmer${N} installer — version ${VERSION}"
echo ""

# ── Create dirs ───────────────────────────────────────────────────────────────
mkdir -p "$BIN_DIR" "$LIB_DIR"

# ── Download files ────────────────────────────────────────────────────────────
info "Downloading ricer..."
curl -fsSL --max-time 30 "${REPO_RAW}/ricer" -o "${BIN_DIR}/ricer"
chmod +x "${BIN_DIR}/ricer"

info "Downloading library files..."
for lib in utils detect prerice ai rules install; do
  curl -fsSL --max-time 30 "${REPO_RAW}/lib/${lib}.sh" -o "${LIB_DIR}/${lib}.sh"
done

info "Downloading pre-rice profile configs..."
mkdir -p "${LIB_DIR}/profiles"
for profile in omarchy cachyos garuda omakub caelestia generic; do
  curl -fsSL --max-time 30 "${REPO_RAW}/lib/profiles/${profile}.sh" -o "${LIB_DIR}/profiles/${profile}.sh"
done

# Save .version for the ricer script to read
mkdir -p "${HOME}/.local/share/ricer"
echo "$VERSION" > "${HOME}/.local/share/ricer/.version"

# ── PATH setup ────────────────────────────────────────────────────────────────
added_path=false
if ! echo "$PATH" | tr ':' '\n' | grep -qx "${BIN_DIR}"; then
  for rc in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
    if [ -f "$rc" ]; then
      if ! grep -Eq '(\$HOME|'"${HOME}"'|~)/\.local/bin' "$rc" 2>/dev/null; then
        echo "" >> "$rc"
        echo "# Rice Farmer" >> "$rc"
        echo "export PATH=\"${BIN_DIR}:\$PATH\"" >> "$rc"
        added_path=true
        break
      fi
    fi
  done
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
ok "Rice Farmer v${VERSION} installed to ${BIN_DIR}/ricer"
if [ "$added_path" = "true" ]; then
  warn "Restart your shell or run:  export PATH=\"${BIN_DIR}:\$PATH\""
fi
echo ""
echo -e "  Quick start:"
echo -e "    ${C}ricer detect${N}                      # show system info"
echo -e "    ${C}ricer install <github-url>${N}         # install a rice"
echo -e "    ${C}ricer --help${N}                       # full usage"
echo ""
