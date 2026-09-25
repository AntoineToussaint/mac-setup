#!/usr/bin/env bash
# ~/mac-setup/setup.sh — macOS developer setup (Apple Silicon)
# Review before running. Re-runnable (idempotent).
#
#   Setup + update everything:  bash ~/mac-setup/setup.sh
#   User-space updates, no sudo: bash ~/mac-setup/setup.sh --user-only
#   Skip security hardening:    bash ~/mac-setup/setup.sh --no-security
#   Install everything, no prompts (CI/unattended):  bash ~/mac-setup/setup.sh --yes
#   Re-choose language toolchains:  bash ~/mac-setup/setup.sh --reconfigure
#
# One command does it all: installs anything missing, upgrades Homebrew
# packages, mise runtimes, and Nix, applies security hardening, and verifies the
# result with doctor.sh. Use --user-only to skip every sudo-dependent step, or
# --no-security to upgrade Nix but skip security hardening.
#
# On the first run, toolchains already configured in mise are adopted without
# prompting. It only asks about unconfigured toolchains (Node, Python, Go,
# Rust); press Enter to accept the default (yes). Choices are saved to
# ~/.config/mac-setup/toolchains.env and reused silently on later runs — pass
# --reconfigure to be asked again. Pass --yes, or run non-interactively (no
# TTY), to install all of them without prompting.
set -euo pipefail

# macOS ships bash 3.2 (2007) as /bin/bash, which rejects read_line's fractional
# `read -t` — an error on every prompt, and the paste drain silently doing
# nothing. Hand over to Homebrew's bash; MAC_SETUP_REEXEC stops this looping.
# BASH_SOURCE is EMPTY when the script is piped (`curl … | bash`) or run via
# `bash -c`, and `exec bash ""` dies with "No such file or directory". Only
# hand over when there is a real file to hand over to. The :- matters: set -u
# is already on, and a bare ${BASH_SOURCE[0]} aborts right here when it is empty.
if [ "${BASH_VERSINFO[0]}" -lt 4 ] && [ -x /opt/homebrew/bin/bash ] \
   && [ -f "${BASH_SOURCE[0]:-}" ] && [ -z "${MAC_SETUP_REEXEC:-}" ]; then
  export MAC_SETUP_REEXEC=1
  exec /opt/homebrew/bin/bash "${BASH_SOURCE[0]}" "$@"
fi

export HOMEBREW_NO_ENV_HINTS=1   # quiet Homebrew's hint chatter (errors still show)
# Homebrew 6's parallel downloader (concurrency "auto") can deadlock: it prints
# "Fetching a, b, c, …" then hangs with no active curl. Force serial downloads —
# a bit slower, but reliable. Remove once the upstream hang is fixed.
export HOMEBREW_DOWNLOAD_CONCURRENCY=1

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
DOTS="$DIR/dotfiles"
STAMP="$(date +%Y%m%d-%H%M%S)"

SECURITY=1
USER_ONLY=0
ASSUME_YES=0
RECONFIGURE=0
for arg in "$@"; do
  case "$arg" in
    --user-only) USER_ONLY=1 ;;
    --no-security) SECURITY=0 ;;
    -y|--yes) ASSUME_YES=1 ;;
    --reconfigure) RECONFIGURE=1 ;;   # re-prompt for toolchains, ignoring saved choices
    -h|--help)
      awk 'NR>1 { if (/^#/) { sub(/^# ?/,""); print } else exit }' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $arg (use --user-only, --no-security, --yes, --reconfigure, or --help)" >&2; exit 1 ;;
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
paste_off() { { printf '\033[?2004l' > /dev/tty; } 2>/dev/null || true; }  # bracketed paste OFF (see cleanup)
paste_on()  { { printf '\033[?2004h' > /dev/tty; } 2>/dev/null || true; }  # ...and back ON
read_line() { # read_line VAR "prompt text" — paste-hardened `read`
  # A pasted value (an SSH key copied with a trailing blank line, or a
  # terminal that wraps paste in bracketed-paste escapes) can leave stray
  # bytes buffered after this read returns. Left alone, they get consumed by
  # the *next* prompt instead of this one — looking like garbage input or a
  # terminal that stopped accepting keystrokes. Disable bracketed paste for
  # the read, then drain anything still buffered before moving on. The control
  # sequences go to the terminal (/dev/tty), never to a redirected stdout, and
  # the EXIT trap restores paste mode even if we're interrupted mid-read.
  local __junk
  paste_off
  printf '%s' "$2"
  read -r "$1"
  paste_on
  # bash 4+ only. The re-exec above usually spares us, but a first run happens
  # before Homebrew's bash exists.
  if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
    while read -r -t 0.05 __junk; do :; done
  fi
}
ask() { # ask "Question?" — yes/no prompt, default yes. Auto-yes with --yes or no TTY.
  if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then return 0; fi
  local reply
  read_line reply "$(printf "\033[1;36m??\033[0m %s [Y/n] " "$*")"
  case "$reply" in
    [nN]|[nN][oO]) return 1 ;;
    *) return 0 ;;
  esac
}
ask_no() { # ask_no "Question?" — yes/no prompt, default NO. Never auto-yes: an
  # unattended run must not opt into what the interactive default declines.
  if [ ! -t 0 ]; then return 1; fi
  local reply
  read_line reply "$(printf "\033[1;36m??\033[0m %s [y/N] " "$*")"
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
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
write_identity() { # write_identity FILE NAME EMAIL SIGNKEY SIGNPROG — emit a git identity [include] file
  local file="$1" name="$2" email="$3" signkey="$4" signprog="$5"
  mkdir -p "$(dirname "$file")"
  {
    echo "# Git identity — generated by ~/mac-setup/setup.sh. NOT tracked in git."
    echo "# Edit freely, or re-run: bash ~/mac-setup/setup.sh --reconfigure"
    echo "[user]"
    [ -n "$name" ]  && printf "\tname = %s\n" "$name"
    [ -n "$email" ] && printf "\temail = %s\n" "$email"
    if [ -n "$signkey" ]; then
      printf "\tsigningkey = %s\n" "$signkey"
      echo "[gpg]"
      echo "	format = ssh"
      echo '[gpg "ssh"]'
      # Always named: a per-folder identity is included from another one, and
      # without its own line it would INHERIT that one's signer (op-ssh-sign),
      # which cannot resolve a key file path and breaks every commit. A plain
      # SSH key signs with ssh-keygen, git's own default.
      printf "\tprogram = %s\n" "${signprog:-ssh-keygen}"
      echo "	allowedSignersFile = ~/.ssh/allowed_signers"
      echo "[commit]"
      echo "	gpgsign = true"
      echo "[tag]"
      echo "	gpgsign = true"
    else
      # Signing explicitly OFF: a per-folder identity overrides another, and
      # without this it would INHERIT the other's gpgsign=true (and its key),
      # signing personal commits with the wrong key.
      echo "[commit]"
      echo "	gpgsign = false"
      echo "[tag]"
      echo "	gpgsign = false"
    fi
  } > "$file"
}

seed_allowed_signer() { # seed_allowed_signer EMAIL SIGNKEY — entry for ~/.ssh/allowed_signers
  local email="$1" signkey="$2" pub
  [ -n "$signkey" ] && [ -n "$email" ] || return 0
  case "$signkey" in
    ssh-*) pub="$signkey" ;;                                        # inline (1Password)
    *)     pub="$(cut -d' ' -f1,2 < "$signkey" 2>/dev/null || true)" ;;
  esac
  [ -n "$pub" ] || return 0
  mkdir -p "$HOME/.ssh"; touch "$HOME/.ssh/allowed_signers"
  grep -qF -- "$email $pub" "$HOME/.ssh/allowed_signers" \
    || printf '%s %s\n' "$email" "$pub" >> "$HOME/.ssh/allowed_signers"
}

# Always-run cleanup (normal exit, error, or Ctrl-C). Bracketed paste is owned
# by the interactive shell / Claude Code, which expect it ON; read_line turns it
# OFF around a prompt, so if we die mid-prompt we MUST turn it back on or the
# next program's multi-line paste breaks. Also reap the sudo keep-alive below.
cleanup() {
  paste_on
  [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Sudo up front, ONCE ---------------------------------------------------------
# The Nix upgrade and (unless --no-security) security.sh need root. Prompt a
# single time here and keep the credential warm for the whole run so the long
# brew step in between doesn't let it expire. Run this script as your normal
# user — never `sudo bash setup.sh` (that would run brew/mise/dotfiles as root).
if [ "$USER_ONLY" -eq 0 ]; then
  log "Caching sudo (you'll be asked once)"
  if ! sudo -v; then
    log "Could not cache sudo now — you may be prompted again at the Nix/security steps."
  fi
  # Keep the sudo timestamp warm for the whole run, QUIETLY. `sudo -n true` can't
  # renew a lapsed/tty-scoped ticket and would otherwise print "sudo: a password
  # is required" mid-run (alarming but harmless) — so send its stderr to /dev/null.
  # Refresh every 30s (well under the default 5-min timeout) and stop when we exit.
  ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 30; done ) &
  SUDO_KEEPALIVE_PID=$!   # reaped by the cleanup() trap set above
else
  log "User-only mode — skipping sudo, Nix, and security hardening"
fi

# 0a) PATH for THIS process --------------------------------------------------
# Mirror what dotfiles/zshenv adds; setup.sh is bash and cannot source it (zsh
# arrays). Otherwise it inherits the PATH of a shell that predates the dotfiles,
# and the Claude Code installer tells the reader to append to ~/.zshrc — which
# by then is a symlink into this repo.
INHERITED_PATH="$PATH"   # what the calling shell had, for the closing notice
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
mkdir -p "$HOME/.local/bin" "$HOME/go/bin"

# 0) Homebrew ----------------------------------------------------------------
# Resolve it from disk, not PATH. Homebrew's PATH entry comes from
# /etc/paths.d/homebrew via path_helper, which only login shells read — so a
# terminal already open when Homebrew landed never sees it, and this script died
# on `brew update` with brew sitting right there in /opt/homebrew/bin.
BREW=/opt/homebrew/bin/brew          # Apple Silicon only; bootstrap.sh refuses Intel
if ! command -v brew >/dev/null 2>&1; then
  if [ -x "$BREW" ]; then
    log "Homebrew is installed but not on this shell's PATH — loading it for this run"
  else
    log "Installing Homebrew"
    if [ -t 0 ]; then
      retry 3 bash -c 'set -o pipefail; curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash'
    else
      retry 3 bash -c 'set -o pipefail; curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | NONINTERACTIVE=1 bash'
    fi
  fi
  [ -x "$BREW" ] || { log "Homebrew install did not produce $BREW"; exit 1; }
fi
# Unconditionally, so brew sits ahead of the user bin dirs added above — the
# order a login shell ends up with (zshenv prepends them, then zprofile's
# shellenv prepends brew). Without this the two disagree whenever a binary
# exists in both, e.g. claude from the cask and from the native installer.
if [ -x "$BREW" ]; then
  eval "$("$BREW" shellenv)"
fi

# 1) Homebrew packages -------------------------------------------------------
# NOTE on hangs: a *corrupt* cached bottle (rare — usually left by a hard-killed
# run) can make Homebrew 6 FREEZE silently ("Fetching <pkg>…", no curl, no
# error). If that happens, scrub the cache once with `brew cleanup -s` and
# re-run. We deliberately DON'T auto-delete *.incomplete files here: those let
# large flaky downloads (e.g. the ChatGPT cask) RESUME across re-runs.
log "Refreshing Homebrew and installing packages (Brewfile)"
# Guarded for the same reason as `brew bundle` below: a flaky network here, or
# a cask that will not quit during the upgrade, must not cost the dotfiles,
# runtimes, Nix and the hardening.
retry 2 brew update || log "brew update failed — continuing with what is already cached"
# Homebrew 6 refuses to install formulae from third-party taps unless trusted,
# and the prompt it would show is invisible to a non-interactive run — so
# `brew bundle` just aborts the whole batch. Pre-tap and pre-trust every
# tap-qualified entry in the Brewfile (schpet/tap/linear,
# f1bonacc1/tap/process-compose, ...) so new ones need no edit here.
# No-ops if already trusted.
while read -r kind pkg; do
  [[ -n "$pkg" ]] || continue
  brew tap "${pkg%/*}"                  >/dev/null 2>&1 || true
  brew trust --"$kind" "$pkg"           >/dev/null 2>&1 || true
done < <(awk -F'"' '/^(brew|cask) "[^"]+\/[^"]+\/[^"]+"/ {
           print ($1 ~ /^cask/ ? "cask" : "formula"), $2 }' "$DIR/Brewfile")
# One failing cask must not cost the dotfiles, runtimes, Nix and the hardening.
# `brew bundle` exits non-zero if ANY entry fails, most often because an app was
# installed by hand and macOS blocks the chgrp Homebrew runs when adopting it.
# Record it, carry on, and let doctor.sh be the gate.
BREW_BUNDLE_FAILED=0
brew bundle --file="$DIR/Brewfile" || {
  BREW_BUNDLE_FAILED=1
  log "brew bundle had failures — continuing; doctor.sh reports what is missing"
}
log "Upgrading Homebrew packages"
brew upgrade --yes || log "brew upgrade had failures — continuing; doctor.sh reports what is outdated"
brew cleanup || log "brew cleanup failed — disk space only, continuing"
# To remove anything not in the Brewfile:  brew bundle cleanup --file="$DIR/Brewfile"

# 2) Dotfiles (symlinked so future edits in ~/mac-setup take effect) ---------
log "Linking dotfiles"
link "$DOTS/zshenv"         "$HOME/.zshenv"
link "$DOTS/zprofile"       "$HOME/.zprofile"
link "$DOTS/zshrc"          "$HOME/.zshrc"
link "$DOTS/shortcuts.zsh"  "$HOME/.config/zsh/shortcuts.zsh"
link "$DOTS/zsh_plugins.txt" "$HOME/.zsh_plugins.txt"
link "$DOTS/completions/_shell-coach" "$HOME/.config/zsh/completions/_shell-coach"
link "$DIR/bin/shell-coach" "$HOME/.local/bin/shell-coach"
link "$DIR/bin/devtunnel"   "$HOME/.local/bin/devtunnel"
link "$DIR/bin/devtunnel-guard" "$HOME/.local/bin/devtunnel-guard"
link "$DIR/bin/setapp-sync" "$HOME/.local/bin/setapp-sync"
link "$DOTS/starship.toml"  "$HOME/.config/starship.toml"
link "$DOTS/ghostty-config" "$HOME/.config/ghostty/config"
link "$DOTS/gitconfig"      "$HOME/.gitconfig"

# Silence the "Last login: … on ttys###" banner every new shell prints. An
# empty ~/.hushlogin is the macOS-standard opt-out (also suppresses any MOTD).
[ -f "$HOME/.hushlogin" ] || { touch "$HOME/.hushlogin" && echo "created ~/.hushlogin (silences the 'Last login' banner)"; }

# 2a) Pre-install zsh plugins so the FIRST login shell never has to clone them.
# Antidote clones missing plugins lazily on first use. That clone runs under
# your global gitconfig, which may rewrite github HTTPS URLs to SSH
# (url."git@github.com:".insteadOf). On a machine with no SSH key every plugin
# clone then fails with "Permission denied (publickey)" and spams the errors on
# every new shell — a broken-looking login. We clone them here instead, with a
# neutral global git config (GIT_CONFIG_GLOBAL=/dev/null) so that rewrite and
# the gh credential helpers don't apply — the plugin repos are public and clone
# over plain anonymous HTTPS. Bonus: the first login is fast instead of blocking
# on four network clones. Idempotent — antidote skips anything already cached.
log "Pre-installing zsh plugins (antidote)"
ANTIDOTE_ZSH="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/antidote/share/antidote/antidote.zsh"
if [ -r "$ANTIDOTE_ZSH" ] && [ -r "$HOME/.zsh_plugins.txt" ]; then
  antidote_prime() { # clone every plugin into antidote's cache, bypassing the URL rewrite
    GIT_CONFIG_GLOBAL=/dev/null zsh -f -c \
      "source '$ANTIDOTE_ZSH'; antidote bundle < '$HOME/.zsh_plugins.txt' >/dev/null"
  }
  retry 3 antidote_prime \
    || log "Plugin pre-install failed — the first login shell will retry the clone"
else
  log "antidote or ~/.zsh_plugins.txt missing — skipping plugin pre-install"
fi

# 2b) GitHub sign-in ----------------------------------------------------------
# Everything downstream assumes it — git's credential helper, the key upload
# below, gh-dash, doctor — yet the script only ever printed a reminder, so a
# first run always exited non-zero over a step nobody had attempted. The scopes
# matter: a plain `gh auth login` grants repo/gist/read:org and `gh ssh-key add`
# then fails. GIT_CONFIG_GLOBAL is a throwaway because gh offers to write its
# credential helper into ~/.gitconfig, a symlink into this repo; --skip-ssh-key
# because keys are the next step's job.
GH_SCOPES="write:public_key,admin:ssh_signing_key"
if command -v gh >/dev/null 2>&1 && [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
  if ! gh auth status >/dev/null 2>&1; then
    log "GitHub sign-in"
    echo "  gh prints a one-time code and opens your browser to paste it into."
    if ask "Sign in to GitHub now?"; then
      GH_THROWAWAY_CONFIG="$(mktemp -t mac-setup-gitconfig)"
      GIT_CONFIG_GLOBAL="$GH_THROWAWAY_CONFIG" \
        gh auth login -h github.com -p https -s "$GH_SCOPES" -w --skip-ssh-key \
        || log "gh auth login did not complete — run later: gh auth login -s $GH_SCOPES"
      rm -f "$GH_THROWAWAY_CONFIG"
    fi
  elif ! gh auth status 2>&1 | grep -q 'admin:ssh_signing_key'; then
    # Only ask when the scopes are genuinely absent: `gh auth refresh` opens a
    # browser even when it has nothing to do.
    if ask "Add SSH-key permissions to your GitHub login? (needed to register your signing key)"; then
      gh auth refresh -h github.com -s "$GH_SCOPES" \
        || log "Scope refresh skipped — run later: gh auth refresh -s $GH_SCOPES"
    fi
  fi
fi

# 2c) Git identity (personal — kept OUT of the tracked gitconfig) -------------
# dotfiles/gitconfig is shared and symlinked, so it must not carry one person's
# name, email, or signing key. It [include]s the file written here instead.
# Existing values are adopted silently; we only prompt when something is missing.
SSH_KEY_PENDING=0
GIT_IDENTITY="$HOME/.config/git/identity"
if [ "$RECONFIGURE" -eq 1 ] || [ ! -f "$GIT_IDENTITY" ]; then
  log "Configuring Git identity"
  # Read any current values so a re-run (or --reconfigure) offers them as defaults
  # rather than making you retype them.
  CUR_NAME="$(git config --global --includes user.name 2>/dev/null || true)"
  CUR_EMAIL="$(git config --global --includes user.email 2>/dev/null || true)"
  CUR_KEY="$(git config --global --includes user.signingkey 2>/dev/null || true)"

  if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
    # Unattended: never invent an identity. Keep whatever exists and let the
    # follow-up check below flag it if it is still unset.
    GIT_NAME="$CUR_NAME"; GIT_EMAIL="$CUR_EMAIL"
  else
    read_line GIT_NAME "$(printf "\033[1;36m??\033[0m Your name for git commits%s: " "${CUR_NAME:+ [$CUR_NAME]}")"
    GIT_NAME="${GIT_NAME:-$CUR_NAME}"
    read_line GIT_EMAIL "$(printf "\033[1;36m??\033[0m Your email for git commits%s: " "${CUR_EMAIL:+ [$CUR_EMAIL]}")"
    GIT_EMAIL="${GIT_EMAIL:-$CUR_EMAIL}"
  fi

  # Commit signing ------------------------------------------------------------
  # A plain SSH key by default: git signs with ssh-keygen itself, no agent and no
  # external signer. 1Password comes second — Obin does not use it, and that path
  # needs a key already in the account. Both routes end with a key we have seen:
  # gpgsign=true plus a key you do not have breaks every commit.
  OP_SSH_SIGN="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
  CUR_PROG="$(git config --global --includes gpg.ssh.program 2>/dev/null || true)"
  GIT_SIGNKEY=""; GIT_SIGNPROG=""

  SSH_KEY=""   # private-key path; "$SSH_KEY.pub" is the public half
  for _k in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ecdsa" "$HOME/.ssh/id_rsa"; do
    if [ -f "$_k.pub" ]; then SSH_KEY="$_k"; break; fi
  done

  # No key at all is the common case for a new hire. ssh-keygen asks for the
  # passphrase itself, so it never passes through this script.
  if [ -z "$SSH_KEY" ] && [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    log "No SSH key found"
    echo "  An SSH key signs your commits so GitHub shows them as 'Verified',"
    echo "  and it is what you will use for any host that wants a key."
    if ask "Generate one now (ed25519)?"; then
      mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
      echo "  A passphrase is optional but recommended — macOS can remember it."
      if ssh-keygen -t ed25519 -C "${GIT_EMAIL:-$USER@$(hostname -s)}" -f "$HOME/.ssh/id_ed25519"; then
        SSH_KEY="$HOME/.ssh/id_ed25519"
        # Keychain holds the passphrase, so it is typed once ever rather than
        # once per reboot. Harmless with no passphrase.
        ssh-add --apple-use-keychain "$SSH_KEY" 2>/dev/null || true
        if ! grep -qs UseKeychain "$HOME/.ssh/config"; then
          { echo ""
            echo "# Added by ~/mac-setup/setup.sh — remember the passphrase in the Keychain."
            echo "Host *"
            echo "  AddKeysToAgent yes"
            echo "  UseKeychain yes"
            printf "  IdentityFile %s\n" "$SSH_KEY"
          } >> "$HOME/.ssh/config"
          echo "  wrote a Keychain block to ~/.ssh/config"
        fi
      else
        log "ssh-keygen did not complete — leaving signing off"
      fi
    fi
  fi

  if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ]; then
    if [ -n "$SSH_KEY" ] && ask "Sign commits with $(basename "$SSH_KEY").pub? (shows 'Verified' on GitHub)"; then
      GIT_SIGNKEY="$SSH_KEY.pub"
    elif [ -x "$OP_SSH_SIGN" ] && ask_no "Use a 1Password SSH key instead?"; then
      read_line GIT_SIGNKEY "$(printf "\033[1;36m??\033[0m Public signing key (ssh-ed25519 AAAA…)%s: " "${CUR_KEY:+ [keep current]}")"
      GIT_SIGNKEY="${GIT_SIGNKEY:-$CUR_KEY}"
      # op-ssh-sign looks the key up in 1Password BY its public key, so a file
      # path cannot resolve — and [keep current] happily hands one back from an
      # earlier plain-key run. Refuse rather than write a config that fails
      # every commit.
      case "$GIT_SIGNKEY" in
        "")    ;;
        ssh-*) GIT_SIGNPROG="$OP_SSH_SIGN" ;;
        *)     log "Not a public key — op-ssh-sign needs the ssh-ed25519 AAAA… text, not a path. Leaving signing off."
               GIT_SIGNKEY="" ;;
      esac
    fi
  elif [ -n "$CUR_KEY" ]; then
    # Unattended: preserve whatever is already working, signer program included.
    GIT_SIGNKEY="$CUR_KEY"; GIT_SIGNPROG="$CUR_PROG"
  fi

  # write_identity has always pointed allowedSignersFile here and nothing ever
  # created it, so no signature this setup produced could be verified locally.
  seed_allowed_signer "$GIT_EMAIL" "$GIT_SIGNKEY"

  # Registering a key writes to a GitHub account, so it is asked for explicitly
  # rather than riding along with the signing choice: the key found on disk may
  # be one you keep for something else entirely, and an unattended run must
  # never publish it. Checked per TYPE — `gh ssh-key list` returns both kinds in
  # one stream, so a key already present for authentication is not proof that
  # the signing one is, which is exactly the "pushes work, commits still read
  # Unverified" trap this block exists to avoid.
  if [ -n "$SSH_KEY" ] && command -v gh >/dev/null 2>&1; then
    if ! gh auth status >/dev/null 2>&1; then
      SSH_KEY_PENDING=1
    elif [ ! -t 0 ] || [ "$ASSUME_YES" -eq 1 ]; then
      SSH_KEY_PENDING=1   # nothing reaches an account without someone saying so
    else
      _body="$(cut -d' ' -f2 < "$SSH_KEY.pub")"
      _keys="$(gh ssh-key list 2>/dev/null || true)"
      # Fields are title, key, added, id, type; index() not ~ because a base64
      # key body is full of regex metacharacters.
      _have_key() {
        awk -F'\t' -v b="$_body" -v t="$1" 'index($2, b) && $NF == t { f = 1 } END { exit !f }' <<< "$_keys"
      }
      _missing=""
      _have_key authentication || _missing="authentication"
      _have_key signing        || _missing="${_missing:+$_missing and }signing"
      if [ -z "$_missing" ]; then
        echo "  SSH key already on your GitHub account (authentication and signing)"
      elif ask "Add $(basename "$SSH_KEY").pub to your GitHub account as the $_missing key?"; then
        _title="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
        log "Adding your SSH key to GitHub"
        _have_key authentication || gh ssh-key add "$SSH_KEY.pub" --title "$_title" \
          || log "Could not add the auth key — run: gh auth refresh -s write:public_key,admin:ssh_signing_key"
        _have_key signing || gh ssh-key add "$SSH_KEY.pub" --type signing --title "$_title (signing)" \
          || log "Could not add the signing key — run: gh auth refresh -s write:public_key,admin:ssh_signing_key"
      else
        SSH_KEY_PENDING=1
      fi
    fi
  fi

  write_identity "$GIT_IDENTITY" "$GIT_NAME" "$GIT_EMAIL" "$GIT_SIGNKEY" "$GIT_SIGNPROG"
  log "Wrote $GIT_IDENTITY"

  # Optional SECOND identity for personal projects, selected by folder. Commits
  # in repos under the chosen folder use this name/email/signing key instead of
  # the default above — no gh multi-account needed. git evaluates includes
  # recursively, so we put the includeIf inside the (untracked) default identity
  # file; the shared gitconfig stays free of personal paths.
  GIT_IDENTITY_PERSONAL="$HOME/.config/git/identity-personal"
  if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ] \
     && ask "Use a separate Git identity for personal projects kept in one folder?"; then
    read_line PERSONAL_DIR "$(printf "\033[1;36m??\033[0m Folder that holds your personal projects [~/personal]: ")"
    PERSONAL_DIR="${PERSONAL_DIR:-$HOME/personal}"
    # Expand a leading ~ (read gives it literally). These are case PATTERNS
    # matching a literal tilde, not paths to expand — the quotes are what stops
    # glob interpretation, so SC2088's "use $HOME" advice is inverted here.
    # shellcheck disable=SC2088
    case "$PERSONAL_DIR" in
      "~")   PERSONAL_DIR="$HOME" ;;
      "~/"*) PERSONAL_DIR="$HOME/${PERSONAL_DIR#\~/}" ;;
    esac
    read_line P_NAME "$(printf "\033[1;36m??\033[0m Name for personal commits [%s]: " "$GIT_NAME")"
    P_NAME="${P_NAME:-$GIT_NAME}"
    read_line P_EMAIL "$(printf "\033[1;36m??\033[0m Email for personal commits: ")"
    if [ -z "$P_EMAIL" ]; then
      log "No personal email entered — skipping personal identity (its whole point is a different email)"
    else
      P_SIGNKEY=""; P_SIGNPROG=""
      if [ -n "$SSH_KEY" ] && ask "Sign personal commits with $(basename "$SSH_KEY").pub too?"; then
        P_SIGNKEY="$SSH_KEY.pub"
      elif [ -x "$OP_SSH_SIGN" ] && ask_no "Sign personal commits with a 1Password SSH key?"; then
        read_line P_SIGNKEY "$(printf "\033[1;36m??\033[0m Public signing key for personal commits (ssh-ed25519 AAAA…): ")"
        # Same guard as the default identity: op-ssh-sign needs the key text.
        case "$P_SIGNKEY" in
          "")    ;;
          ssh-*) P_SIGNPROG="$OP_SSH_SIGN" ;;
          *)     log "Not a public key — op-ssh-sign needs the ssh-ed25519 AAAA… text, not a path. Leaving personal signing off."
                 P_SIGNKEY="" ;;
        esac
      fi
      write_identity "$GIT_IDENTITY_PERSONAL" "$P_NAME" "$P_EMAIL" "$P_SIGNKEY" "$P_SIGNPROG"
      # The personal identity signs with its own email, and often its own key;
      # without its own entry those commits fail local verification while the
      # default identity's succeed.
      seed_allowed_signer "$P_EMAIL" "$P_SIGNKEY"
      mkdir -p "$PERSONAL_DIR"
      # gitdir needs a trailing slash (git appends ** to match repos beneath it);
      # /i is case-insensitive to match macOS's case-insensitive filesystem.
      {
        printf '\n# Repos under %s/ are authored with the personal identity below.\n' "${PERSONAL_DIR%/}"
        printf '[includeIf "gitdir/i:%s/"]\n' "${PERSONAL_DIR%/}"
        printf '\tpath = %s\n' "$GIT_IDENTITY_PERSONAL"
      } >> "$GIT_IDENTITY"
      log "Personal identity active for repos under ${PERSONAL_DIR%/}/ (wrote $GIT_IDENTITY_PERSONAL)"
    fi
  fi
else
  echo "git identity already configured in $GIT_IDENTITY (--reconfigure to change)"
fi

# 3) Languages via mise ------------------------------------------------------
# Toolchain choices are remembered across runs in $TOOLCHAIN_PREFS. When that
# file is missing, existing mise selections are adopted and only unconfigured
# toolchains are prompted for. The answers are saved and reused silently
# thereafter. --reconfigure asks again; --yes installs everything for this run
# without clobbering a saved selection. Each choice covers the runtime plus its
# extra tooling.
log "Choosing language toolchains"
TOOLCHAIN_PREFS="$HOME/.config/mac-setup/toolchains.env"
if [ -f "$TOOLCHAIN_PREFS" ] && [ "$RECONFIGURE" -eq 0 ]; then
  # shellcheck source=/dev/null
  . "$TOOLCHAIN_PREFS"
  if [ "$ASSUME_YES" -eq 1 ]; then WANT_NODE=1; WANT_PYTHON=1; WANT_GO=1; WANT_RUST=1; fi
  log "Using saved choices from $TOOLCHAIN_PREFS (run with --reconfigure to change)"
else
  # A missing preferences file does not necessarily mean a new machine. Adopt
  # toolchains already selected in mise instead of asking to "install" them
  # again. --reconfigure intentionally bypasses this detection.
  if [ "$RECONFIGURE" -eq 0 ] && mise current node >/dev/null 2>&1; then
    WANT_NODE=1
    echo "using existing mise Node configuration"
  else
    ask "Install Node (lts)?" && WANT_NODE=1 || WANT_NODE=0
  fi
  if [ "$RECONFIGURE" -eq 0 ] && mise current python >/dev/null 2>&1; then
    WANT_PYTHON=1
    echo "using existing mise Python configuration"
  else
    ask "Install Python?" && WANT_PYTHON=1 || WANT_PYTHON=0
  fi
  if [ "$RECONFIGURE" -eq 0 ] && mise current go >/dev/null 2>&1; then
    WANT_GO=1
    echo "using existing mise Go configuration"
  else
    ask "Install Go + air?" && WANT_GO=1 || WANT_GO=0
  fi
  if [ "$RECONFIGURE" -eq 0 ] && mise current rust >/dev/null 2>&1; then
    WANT_RUST=1
    echo "using existing mise Rust configuration"
  else
    ask "Install Rust + tauri-cli?" && WANT_RUST=1 || WANT_RUST=0
  fi
  # Persist for next time (skip under --yes so an unattended run can't overwrite
  # a real selection with all-on). Delete the file or use --reconfigure to reset.
  if [ "$ASSUME_YES" -eq 0 ]; then
    mkdir -p "$(dirname "$TOOLCHAIN_PREFS")"
    cat > "$TOOLCHAIN_PREFS" <<EOF
# mac-setup toolchain choices — reused on each run. Edit, delete, or run
# 'setup.sh --reconfigure' to change. Generated $(date +%Y-%m-%d).
WANT_NODE=$WANT_NODE
WANT_PYTHON=$WANT_PYTHON
WANT_GO=$WANT_GO
WANT_RUST=$WANT_RUST
EOF
    log "Saved choices to $TOOLCHAIN_PREFS"
  fi
fi

log "Installing selected language runtimes via mise"
eval "$(mise activate bash)"
# AFTER the activation: mise points GOBIN at the active toolchain's bin dir, so
# `go install` would drop air in a path that moves on every Go release and leave
# ~/go/bin — which zshenv puts on PATH — empty. zshenv pins it; so do we.
export GOBIN="$HOME/go/bin"
if [ "$WANT_PYTHON" -eq 1 ]; then
  # Use precompiled Python (astral python-build-standalone) instead of compiling
  # from source — faster, and avoids the pyenv git-clone step that fails on a
  # transient network blip.
  mise settings set python.compile false
fi
# Wrapped in retry(): downloads from mise-versions.jdx.dev / GitHub occasionally
# refuse a connection on a network hiccup. The block is idempotent — a retry
# skips already-installed runtimes and only re-attempts what failed.
install_runtimes() {
  if [ "$WANT_NODE" -eq 1 ];   then mise use --global node@lts;      fi
  if [ "$WANT_PYTHON" -eq 1 ]; then mise use --global python@latest; fi
  if [ "$WANT_GO" -eq 1 ];     then mise use --global go@latest;     fi
  if [ "$WANT_RUST" -eq 1 ];   then mise use --global rust@latest;   fi
  mise install
}
retry 4 install_runtimes
log "Upgrading mise-managed runtimes"
retry 3 mise upgrade

# 3b) Extra language tooling not covered by Homebrew -------------------------
if [ "$WANT_RUST" -eq 1 ]; then
  # Rust: ensure rustup components (rust-analyzer/clippy/rustfmt) are present.
  if command -v rustup >/dev/null 2>&1; then
    log "Ensuring rustup components (rust-analyzer, clippy, rustfmt)"
    rustup component add rust-analyzer clippy rustfmt 2>/dev/null || true
  fi
  # Rust: `tauri-cli` (needed by mind-desktop) has no Homebrew formula. Prefer
  # cargo-binstall (prebuilt binary, seconds) and fall back to compiling from
  # source. Lands in ~/.cargo/bin, which zshenv adds to PATH. Skip if present.
  if command -v cargo >/dev/null 2>&1 && ! command -v cargo-tauri >/dev/null 2>&1; then
    log "Installing cargo tools (tauri-cli v2)"
    if command -v cargo-binstall >/dev/null 2>&1; then
      cargo binstall --no-confirm 'tauri-cli@^2' || cargo install tauri-cli --version '^2'
    else
      cargo install tauri-cli --version '^2'
    fi
  fi
fi
if [ "$WANT_GO" -eq 1 ]; then
  # Go: `air` (live reload) has no stable Homebrew formula — install via go.
  # Lands in $(go env GOPATH)/bin = ~/go/bin, which zshenv adds to PATH.
  if command -v go >/dev/null 2>&1; then
    log "Installing Go tools via go install (air — live reload)"
    # The one unguarded network call: no "already present" skip, so it re-fetches
    # every run, and a proxy.golang.org blip would abort the script before Nix,
    # the hardening and doctor.
    retry 3 go install github.com/air-verse/air@latest \
      || log "air install failed — install later: go install github.com/air-verse/air@latest"
  fi
fi

# Tailscale: do NOT symlink the CLI into ~/.local/bin. The app installs its own
# shim at /usr/local/bin/tailscale on first login, and that shim calls the
# in-bundle binary by its real path. Reaching that binary through a symlink from
# elsewhere breaks its bundle code signature and the process dies on SIGTRAP —
# and because zshenv puts ~/.local/bin early in PATH, such a symlink shadows the
# working shim in every zsh. Deliberately the cask, not the `tailscale` formula:
# the formula runs a second tailscaled that fights the menu-bar app.
if [ ! -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
  log "Tailscale.app not found — 'devtunnel funnel' will be unavailable"
elif ! command -v tailscale >/dev/null 2>&1; then
  log "Tailscale CLI not on PATH yet — log into Tailscale.app once and it installs /usr/local/bin/tailscale"
fi

# gh extensions: gh-dash (PR/issue TUI dashboard) has no Homebrew formula.
if command -v gh >/dev/null 2>&1; then
  if ! gh extension list 2>/dev/null | grep -q 'dlvhdr/gh-dash'; then
    log "Installing gh extension: gh-dash (PR/issue dashboard — run with 'gh dash')"
    gh extension install dlvhdr/gh-dash || log "gh-dash install skipped (gh not authenticated yet? run 'gh extension install dlvhdr/gh-dash' later)"
  fi
fi

# Claude Code (CLI): install via the official self-updating native installer —
# NOT Homebrew. It's Anthropic's recommended method, auto-updates in the
# background, and lands in ~/.local/bin (already on PATH via zshenv). A brew cask
# exists but doesn't auto-update. Skip if already present (it updates itself).
# Docs: https://code.claude.com/docs/en/setup
if ! command -v claude >/dev/null 2>&1; then
  log "Installing Claude Code (native installer — self-updating)"
  retry 3 bash -c 'set -o pipefail; curl -fsSL https://claude.ai/install.sh | bash' \
    || log "Claude Code install failed — install later: curl -fsSL https://claude.ai/install.sh | bash"
else
  log "Claude Code present ($(claude --version 2>/dev/null || echo installed)) — it self-updates"
fi

# 4) Nix (Determinate installer — NOT via Homebrew) --------------------------
if [ "$USER_ONLY" -eq 1 ]; then
  log "Skipping Nix (--user-only)"
# From disk, not PATH: the Determinate installer publishes `nix` by patching
# /etc/zshrc and friends, which only login and interactive shells read. A
# non-interactive re-run would read that as "not installed" and re-run the
# installer, which refuses once /nix/receipt.json exists — killing the run.
elif command -v nix >/dev/null 2>&1 || [ -e /nix/receipt.json ]; then
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
if [ "$USER_ONLY" -eq 1 ]; then
  log "Skipping security hardening (--user-only)"
elif [ "$SECURITY" -eq 1 ]; then
  log "Applying security hardening (security.sh — will prompt for sudo)"
  bash "$DIR/security.sh"
else
  log "Skipping security hardening (--no-security)"
fi

# 5b) Optional app walkthroughs ----------------------------------------------
# After Nix and the hardening on purpose. Both are interactive and the likeliest
# place for a run to stall — Raycast wants a passphrase typed by hand, Setapp
# asks about every missing app — and anyone who answers "n" or walks away here
# used to end up with an unhardened Mac. Nothing below this line is load-bearing.

# Raycast extensions: there is NO scriptable installer. Extensions live in
# Raycast's own store and an encrypted sqlite DB (raycast-enc.sqlite, key in the
# Keychain), so `brew bundle` can't restore them and copying the support dir
# between machines does not survive. The web store's Install button resolves to
# `raycast://extensions/<author>/<ext>?source=webstore`, but firing that with
# `open` does nothing outside the browser handoff — tested, no install.
#
# What does work is Raycast's own Export/Import (free, not Pro). "Export
# Settings & Data" writes a passphrase-encrypted .rayconfig bundling 11
# categories, one of which is "Extensions installed from the Store"; Raycast
# registers .rayconfig as an owned document type, so `open` on the file lands
# directly in the import dialog. Still needs the passphrase typed by hand.
#
# Point RAYCAST_CONFIG at an export, or drop one in ~/mac-setup/raycast/.
# NEVER commit it: the same bundle carries clipboard history, notes and AI chats
# (.gitignore excludes it).
# Idempotency is a stamp file, not a probe of Raycast's state: the installed-
# extension list lives in the encrypted sqlite DB, and ~/…/com.raycast.macos/
# extensions/ holds a com.raycast.api.cache directory even with zero extensions
# installed — so "directory is non-empty" is NOT a usable signal.
RAYCAST_STAMP="$HOME/.config/mac-setup/raycast-imported"
RAYCAST_CONFIG="${RAYCAST_CONFIG:-}"
if [ -d "/Applications/Raycast.app" ] && [ -z "$RAYCAST_CONFIG" ]; then
  for candidate in "$DIR/raycast/"*.rayconfig \
                   "$HOME/Library/Mobile Documents/com~apple~CloudDocs/mac-setup/"*.rayconfig; do
    [ -f "$candidate" ] && { RAYCAST_CONFIG="$candidate"; break; }
  done
fi
if [ -d "/Applications/Raycast.app" ] && [ -n "$RAYCAST_CONFIG" ] && [ ! -e "$RAYCAST_STAMP" ]; then
  log "Restoring Raycast settings + store extensions"
  if ask "Import $(basename "$RAYCAST_CONFIG") into Raycast now?"; then
    open "$RAYCAST_CONFIG"
    mkdir -p "$(dirname "$RAYCAST_STAMP")"
    printf 'imported %s from %s\n' "$STAMP" "$RAYCAST_CONFIG" > "$RAYCAST_STAMP"
    echo "  Raycast is showing the import dialog: enter the export passphrase,"
    echo "  then tick at least 'Extensions installed from the Store'."
    echo "  Delete $RAYCAST_STAMP to be offered this again."
  fi
fi

# Setapp apps: the subscription is not visible to `brew bundle`, but the tracked
# Setappfile lists what you had installed, and bin/setapp-sync replays it via the
# SetappAgent's `setapp://install?app_id=<UUID>` deeplink (see that script for
# how the UUIDs are recovered). Setapp confirms each install with its own panel
# and only handles one at a time, so setapp-sync asks per app and waits for each
# download; this is just the gate into that walkthrough. The probe is real
# state — the bundle ids under /Applications/Setapp — so nothing goes stale.
#
# The gate tests Setapp's catalogue too, not just the app bundle: the Brewfile
# installs Setapp.app, so its presence proves nothing, while the setapp: scheme
# stays unregistered until someone signs in. Before that every deeplink fails
# with kLSApplicationNotFoundErr — 28 apps in a row.
SETAPP_PENDING=0
SETAPP_CATALOG="$HOME/Library/Application Support/Setapp/Default/Databases/Apps.sqlite"
if [ -d "/Applications/Setapp.app" ] && [ -f "$DIR/Setappfile" ] && [ ! -e "$SETAPP_CATALOG" ]; then
  log "Setapp is installed but not signed in yet — skipping the app walkthrough"
  echo "  Open Setapp.app, sign in, then run:  setapp-sync install"
  SETAPP_PENDING=1
elif [ -d "/Applications/Setapp.app" ] && [ -f "$DIR/Setappfile" ]; then
  SETAPP_MISSING="$("$DIR/bin/setapp-sync" install --dry-run 2>/dev/null | grep -c 'setapp://' || true)"
  if [ "${SETAPP_MISSING:-0}" -gt 0 ]; then
    log "Setapp apps"
    "$DIR/bin/setapp-sync" list --missing | sed 's/^/  /'
    if ask "Go through the $SETAPP_MISSING missing Setapp app(s) now? (asks per app)"; then
      # Guarded: nothing an optional app walkthrough does justifies losing the run.
      if [ "$ASSUME_YES" -eq 1 ]; then
        "$DIR/bin/setapp-sync" install --yes || log "setapp-sync stopped early — finish later with: setapp-sync install"
      else
        "$DIR/bin/setapp-sync" install || log "setapp-sync stopped early — finish later with: setapp-sync install"
      fi
    else
      echo "  Later:  setapp-sync install"
    fi
  fi
fi

log "Checking conditional follow-ups"
NEXT_STEP=0
next_step() {
  NEXT_STEP=$((NEXT_STEP+1))
  printf "  %d. %s\n" "$NEXT_STEP" "$*"
}

if [ "$BREW_BUNDLE_FAILED" -eq 1 ]; then
  next_step "Some Brewfile entries failed to install (scroll up for which). If it was \`chgrp ... Operation not permitted\` while \"Adopting existing App\", that app was installed by hand and macOS protects its bundle: move it to the Trash in Finder and re-run, or grant this terminal App Management in System Settings -> Privacy & Security."
fi

if [ "$SETAPP_PENDING" -eq 1 ]; then
  next_step "Sign in to Setapp (open Setapp.app), then restore your apps: setapp-sync install"
fi

if ! gh auth status >/dev/null 2>&1; then
  next_step "Authenticate GitHub CLI: gh auth login"
fi

if [ "$SSH_KEY_PENDING" -eq 1 ]; then
  _pub="$SSH_KEY.pub"
  next_step "Put your SSH key on GitHub (it was not added during setup): gh auth login && gh auth refresh -s write:public_key,admin:ssh_signing_key && gh ssh-key add $_pub && gh ssh-key add $_pub --type signing"
fi

if [ ! -f "$HOME/.ssh/id_ed25519.pub" ] && [ ! -f "$HOME/.ssh/id_rsa.pub" ] && [ ! -f "$HOME/.ssh/id_ecdsa.pub" ]; then
  next_step "No SSH key on this Mac — create one with: bash ~/mac-setup/setup.sh --reconfigure"
fi

LINEAR_AUTH_STATE="$(linear auth list 2>/dev/null || true)"
if [ -z "$LINEAR_AUTH_STATE" ] || [[ "$LINEAR_AUTH_STATE" == *"No workspaces configured"* ]]; then
  next_step "Authenticate Linear CLI: linear auth login"
fi

if [ -d "/Applications/Raycast.app" ] && [ -z "$RAYCAST_CONFIG" ] && [ ! -e "$RAYCAST_STAMP" ]; then
  next_step "Raycast extensions were NOT restored — no .rayconfig export is available, and nothing here can create one (it is an encrypted blob, and Raycast has no CLI). Ask whoever set up your team to run Raycast's 'Export Settings & Data' on a configured Mac and send you the file and its passphrase; put it in ~/mac-setup/raycast/ (gitignored) or point RAYCAST_CONFIG at it, then re-run. Raycast works fine meanwhile — it just has none of the shared extensions."
fi

if [ -z "$(git config --global --includes user.name 2>/dev/null)" ] \
   || [ -z "$(git config --global --includes user.email 2>/dev/null)" ]; then
  next_step "Set your Git identity: bash ~/mac-setup/setup.sh --reconfigure"
fi

if [ "$NEXT_STEP" -eq 0 ]; then
  echo "  No authentication or identity follow-ups detected."
fi

# 6) Verification ------------------------------------------------------------
log "Verifying setup (doctor.sh)"
DOCTOR_OK=1
bash "$DIR/doctor.sh" || DOCTOR_OK=0

# A child cannot change its parent's environment, so the shell this ran in may
# still have the PATH it started with. Test that against the PATH we were
# actually handed rather than asserting it: on a re-run from an already
# configured terminal the claim would be false, and advice that is visibly
# wrong is how people learn to skim past the rest of the output.
case ":$INHERITED_PATH:" in
  *":$HOME/.local/bin:"*) SHELL_PATH_OK=1 ;;
  *)                      SHELL_PATH_OK=0 ;;
esac
if [ "$SHELL_PATH_OK" -eq 0 ]; then
  log "Open a new terminal before you start work"
  cat <<'EOF'
  The shell you ran this from does not have ~/.local/bin (and likely Homebrew
  and mise) on its PATH — claude, air and friends will say "command not found"
  there even though they installed correctly. Open a new terminal, or run:
  exec zsh -l
EOF
fi

if [ "$DOCTOR_OK" -eq 1 ]; then
  log "Setup verified successfully"
else
  log "Updates completed, but doctor.sh found failures that need attention"
  exit 1
fi
