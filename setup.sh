#!/usr/bin/env bash
# ~/mac-setup/setup.sh — macOS developer setup (Apple Silicon)
# Review before running. Re-runnable (idempotent).
#
#   Setup + update everything:  bash ~/mac-setup/setup.sh
#   Skip security hardening:    bash ~/mac-setup/setup.sh --no-security
#
# One command does it all: installs anything missing, upgrades Homebrew
# packages, mise runtimes, and Nix, and applies security hardening
# (security.sh — secure by default; opt out with --no-security).
set -euo pipefail

export HOMEBREW_NO_ENV_HINTS=1   # quiet Homebrew's hint chatter (errors still show)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS="$DIR/dotfiles"
STAMP="$(date +%Y%m%d-%H%M%S)"

SECURITY=1
for arg in "$@"; do
  case "$arg" in
    --no-security) SECURITY=0 ;;
    -h|--help)
      awk 'NR>1 { if (/^#/) { sub(/^# ?/,""); print } else exit }' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $arg (use --no-security or --help)" >&2; exit 1 ;;
  esac
done

log()  { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }
link() { # link SRC -> DEST, backing up any existing real file
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    log "Backing up $dest -> $dest.bak-$STAMP"
    mv "$dest" "$dest.bak-$STAMP"
  fi
  ln -sfn "$src" "$dest"
  echo "linked $dest -> $src"
}
retry() { # retry <n> <cmd...> — re-run a flaky (usually network) command with backoff
  local n="$1"; shift
  local i=1
  until "$@"; do
    if [ "$i" -ge "$n" ]; then
      log "still failing after $n attempts: $* — giving up"
      return 1
    fi
    log "attempt $i/$n failed: $* — retrying in $((i*5))s"
    sleep $((i*5))
    i=$((i+1))
  done
}

# Sudo up front, ONCE ---------------------------------------------------------
# The Nix upgrade and (unless --no-security) security.sh need root. Prompt a
# single time here and keep the credential warm for the whole run so the long
# brew step in between doesn't let it expire. Run this script as your normal
# user — never `sudo bash setup.sh` (that would run brew/mise/dotfiles as root).
log "Caching sudo (you'll be asked once)"
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done &
trap 'kill %1 2>/dev/null' EXIT

# 1) Homebrew packages -------------------------------------------------------
log "Refreshing Homebrew and installing packages (Brewfile)"
brew update
brew bundle --file="$DIR/Brewfile"
log "Upgrading Homebrew packages"
brew upgrade --yes
brew cleanup
# To remove anything not in the Brewfile:  brew bundle cleanup --file="$DIR/Brewfile"

# 2) Dotfiles (symlinked so future edits in ~/mac-setup take effect) ---------
log "Linking dotfiles"
link "$DOTS/zshrc"          "$HOME/.zshrc"
link "$DOTS/shortcuts.zsh"  "$HOME/.config/zsh/shortcuts.zsh"
link "$DOTS/zsh_plugins.txt" "$HOME/.zsh_plugins.txt"
link "$DOTS/starship.toml"  "$HOME/.config/starship.toml"
link "$DOTS/ghostty-config" "$HOME/.config/ghostty/config"
link "$DOTS/gitconfig"      "$HOME/.gitconfig"

# 3) Languages via mise ------------------------------------------------------
log "Installing language runtimes via mise (node, python, go, rust)"
eval "$(mise activate bash)"
# Use precompiled Python (astral python-build-standalone) instead of compiling
# from source — faster, and avoids the pyenv git-clone step that fails on a
# transient network blip.
mise settings set python.compile false
# Wrapped in retry(): downloads from mise-versions.jdx.dev / GitHub occasionally
# refuse a connection on a network hiccup. The block is idempotent — a retry
# skips already-installed runtimes and only re-attempts what failed.
install_runtimes() {
  mise use --global node@lts
  mise use --global python@latest
  mise use --global go@latest
  mise use --global rust@latest
  mise install
}
retry 4 install_runtimes
log "Upgrading mise-managed runtimes"
retry 3 mise upgrade

# 3b) Extra language tooling not covered by Homebrew -------------------------
# Rust: ensure rustup components (rust-analyzer/clippy/rustfmt) are present.
if command -v rustup >/dev/null 2>&1; then
  log "Ensuring rustup components (rust-analyzer, clippy, rustfmt)"
  rustup component add rust-analyzer clippy rustfmt 2>/dev/null || true
fi
# Go: `air` (live reload) has no stable Homebrew formula — install via go.
# Lands in $(go env GOPATH)/bin = ~/go/bin, which zshrc adds to PATH.
if command -v go >/dev/null 2>&1; then
  log "Installing Go tools via go install (air — live reload)"
  go install github.com/air-verse/air@latest
fi

# 4) Nix (Determinate installer — NOT via Homebrew) --------------------------
if command -v nix >/dev/null 2>&1; then
  log "Upgrading Nix (Determinate)"
  if command -v determinate-nixd >/dev/null 2>&1; then
    sudo determinate-nixd upgrade
  else
    sudo -i nix upgrade-nix
  fi
else
  log "Installing Nix (Determinate Systems installer — will prompt for sudo)"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi

# 5) Security hardening (secure by default — skip with --no-security) --------
if [ "$SECURITY" -eq 1 ]; then
  log "Applying security hardening (security.sh — will prompt for sudo)"
  bash "$DIR/security.sh"
else
  log "Skipping security hardening (--no-security)"
fi

log "Done. Next steps:"
cat <<'EOF'
  1. Restart your terminal (or: exec zsh) to load the new shell config.
  2. Open Ghostty and set it as your default terminal.
  3. Authenticate GitHub CLI:   gh auth login
  4. Edit ~/mac-setup/dotfiles/gitconfig if name/email need changes.
  5. Sign in to Setapp and install a window manager (Swish / Rectangle Pro /
     Mosaic) — TablePlus, DevUtils, Paste, and CleanShot X are also worth it.
EOF
