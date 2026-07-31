#!/bin/bash
# bootstrap.sh — one-command setup for a brand-new Mac.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/AntoineToussaint/mac-setup/main/bootstrap.sh)"
#
# A fresh Mac has no git and no Homebrew, so setup.sh cannot run yet and the repo
# cannot even be cloned. This script closes that gap and nothing more:
#
#   1. Xcode Command Line Tools  (provides git)
#   2. Homebrew                  (into /opt/homebrew, and onto PATH for THIS run)
#   3. clone this repo           (over HTTPS — a new machine has no SSH key yet)
#   4. hand off to setup.sh      (which does the real work, and is re-runnable)
#
# Everything after that — packages, dotfiles, runtimes, Nix, hardening — is
# setup.sh's job. Re-running this script is safe: it updates an existing clone
# instead of failing, so it doubles as an updater.
#
# Options are passed straight through to setup.sh:
#   /bin/bash -c "$(curl -fsSL …/bootstrap.sh)" -- --user-only
#
# Environment overrides:
#   MAC_SETUP_DIR=~/src/mac-setup   clone somewhere other than ~/mac-setup
#   MAC_SETUP_REF=some-branch       check out a branch other than main
set -euo pipefail

REPO_URL="${MAC_SETUP_REPO:-https://github.com/AntoineToussaint/mac-setup.git}"
DEST="${MAC_SETUP_DIR:-$HOME/mac-setup}"
REF="${MAC_SETUP_REF:-main}"

log()  { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m!!  %s\033[0m\n" "$*" >&2; }
die()  { printf "\033[1;31mxx  %s\033[0m\n" "$*" >&2; exit 1; }

# 0) Refuse to run where the rest of the repo's assumptions do not hold --------
[ "$(uname -s)" = "Darwin" ] || die "macOS only (found $(uname -s))."
if [ "$(uname -m)" != "arm64" ]; then
  # Intel Macs put Homebrew in /usr/local; the Brewfile and dotfiles assume
  # /opt/homebrew, and several casks here are Apple-Silicon-only.
  die "Apple Silicon only (found $(uname -m))."
fi
# Never run the whole thing as root: brew refuses, and every dotfile and runtime
# would land in root's home instead of yours.
[ "$(id -u)" -ne 0 ] || die "Run as your normal user, not with sudo. You'll be prompted for sudo when it's needed."

if [ ! -t 0 ]; then
  warn "No terminal on stdin — setup.sh will accept every prompt automatically."
  warn "For an interactive run use:  /bin/bash -c \"\$(curl -fsSL …/bootstrap.sh)\""
fi

# 1) Xcode Command Line Tools -------------------------------------------------
# git lives here. Homebrew's installer would also install the CLT, but doing it
# first keeps the two failure modes separate and lets us report progress.
if ! xcode-select -p >/dev/null 2>&1; then
  log "Installing Xcode Command Line Tools (a system dialog will open)"
  xcode-select --install >/dev/null 2>&1 || true
  # `xcode-select --install` returns immediately while the GUI installer runs,
  # so poll until the tools actually land rather than racing ahead to git.
  printf "    waiting for the install to finish"
  until xcode-select -p >/dev/null 2>&1; do printf "."; sleep 10; done
  printf "\n"
fi
command -v git >/dev/null 2>&1 || die "git still not available after installing the Command Line Tools."

# 2) Homebrew -----------------------------------------------------------------
if [ -x /opt/homebrew/bin/brew ]; then
  log "Homebrew already installed"
else
  log "Installing Homebrew (will prompt for sudo)"
  # NONINTERACTIVE stops the installer waiting on a RETURN we cannot supply when
  # this script is being piped rather than run from a terminal.
  if [ -t 0 ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
fi
# Put brew on PATH for THIS process — setup.sh calls it immediately. Persistent
# PATH is not our job: setup.sh symlinks dotfiles/zprofile, which runs the same
# `brew shellenv` in every future login shell.
[ -x /opt/homebrew/bin/brew ] || die "Homebrew install did not produce /opt/homebrew/bin/brew."
eval "$(/opt/homebrew/bin/brew shellenv)"

# 3) Get the repo -------------------------------------------------------------
if [ -d "$DEST/.git" ]; then
  log "Updating existing clone at $DEST"
  git -C "$DEST" fetch --quiet origin "$REF"
  if [ -n "$(git -C "$DEST" status --porcelain)" ]; then
    # Local edits are the normal state here — this repo is meant to be tweaked.
    # Never blow them away; just run what is already on disk.
    warn "$DEST has uncommitted changes — leaving them alone and using the working tree as-is."
  else
    git -C "$DEST" checkout --quiet "$REF"
    git -C "$DEST" merge --quiet --ff-only "origin/$REF"
  fi
elif [ -e "$DEST" ]; then
  die "$DEST exists but is not a git clone. Move it aside, or set MAC_SETUP_DIR."
else
  log "Cloning $REPO_URL -> $DEST"
  # GIT_CONFIG_GLOBAL=/dev/null ignores ~/.gitconfig for this one command. This
  # repo's own gitconfig sets `url.git@github.com:.insteadOf = https://github.com/`,
  # which would rewrite the HTTPS URL below to SSH and fail on a machine that has
  # no key yet — exactly the machine this script exists to set up.
  GIT_CONFIG_GLOBAL=/dev/null git clone --branch "$REF" "$REPO_URL" "$DEST"
fi

# 4) Hand off -----------------------------------------------------------------
log "Running setup.sh"
exec bash "$DEST/setup.sh" "$@"
