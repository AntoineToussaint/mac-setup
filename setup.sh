#!/usr/bin/env bash
# ~/mac-setup/setup.sh — macOS developer setup (Apple Silicon)
# Review before running. Re-runnable (idempotent).
#
#   Install / sync:  bash ~/mac-setup/setup.sh
#   Update all:      bash ~/mac-setup/setup.sh --update
#
# Without --update the script installs anything missing but leaves already
# installed packages at their current versions. With --update it also upgrades
# Homebrew packages, mise runtimes, and Nix to the latest versions.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS="$DIR/dotfiles"
STAMP="$(date +%Y%m%d-%H%M%S)"

UPDATE=0
for arg in "$@"; do
  case "$arg" in
    --update|-u|update) UPDATE=1 ;;
    -h|--help)
      grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (use --update or --help)" >&2; exit 1 ;;
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

# 1) Homebrew packages -------------------------------------------------------
log "Refreshing Homebrew and installing packages (Brewfile)"
brew update
brew bundle --file="$DIR/Brewfile"
if [ "$UPDATE" -eq 1 ]; then
  log "Upgrading Homebrew packages"
  brew upgrade
  brew cleanup
  # To remove anything not in the Brewfile:  brew bundle cleanup --file="$DIR/Brewfile"
fi

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
mise use --global node@lts
mise use --global python@latest
mise use --global go@latest
mise use --global rust@latest
mise install
if [ "$UPDATE" -eq 1 ]; then
  log "Upgrading mise-managed runtimes"
  mise upgrade
fi

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
  if [ "$UPDATE" -eq 1 ]; then
    log "Upgrading Nix (Determinate)"
    if command -v determinate-nixd >/dev/null 2>&1; then
      sudo determinate-nixd upgrade
    else
      sudo -i nix upgrade-nix
    fi
  else
    log "Nix already installed, skipping (use --update to upgrade)"
  fi
else
  log "Installing Nix (Determinate Systems installer — will prompt for sudo)"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi

if [ "$UPDATE" -eq 1 ]; then
  log "Update complete."
else
  log "Done. Next steps:"
  cat <<'EOF'
  1. Restart your terminal (or: exec zsh) to load the new shell config.
  2. Open Ghostty and set it as your default terminal.
  3. Authenticate GitHub CLI:   gh auth login
  4. Edit ~/mac-setup/dotfiles/gitconfig if name/email need changes.
  5. Sign in to Setapp and install a window manager (Swish / Rectangle Pro /
     Mosaic) — TablePlus, DevUtils, Paste, and CleanShot X are also worth it.
EOF
fi
