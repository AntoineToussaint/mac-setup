#!/usr/bin/env bash
# ~/mac-setup/doctor.sh — validate the setup. Read-only, no sudo, safe to re-run.
#
#   bash ~/mac-setup/doctor.sh
#
# Checks everything setup.sh/security.sh configured and reports PASS/WARN/FAIL.
# Exits non-zero if anything FAILs. Manual items it can't verify live in TODO.md.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS="$DIR/dotfiles"

PASS=0; WARN=0; FAIL=0
ok()   { printf "  \033[1;32m✔\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
warn() { printf "  \033[1;33m▲\033[0m %s\n" "$*"; WARN=$((WARN+1)); }
bad()  { printf "  \033[1;31m✘\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
section() { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }

check() { # check <description> <command...> — pass/fail on exit status
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else bad "$desc"; fi
}

# ---------- OS baseline -------------------------------------------------------
section "OS baseline"
case "$(fdesetup status 2>/dev/null)" in
  *"FileVault is On"*) ok "FileVault on" ;;
  *) bad "FileVault OFF — enable in System Settings → Privacy & Security" ;;
esac
case "$(csrutil status 2>/dev/null)" in
  *enabled*) ok "System Integrity Protection enabled" ;;
  *) bad "SIP disabled — re-enable from Recovery (csrutil enable)" ;;
esac
case "$(spctl --status 2>/dev/null)" in
  *enabled*) ok "Gatekeeper enabled" ;;
  *) bad "Gatekeeper disabled — sudo spctl --global-enable" ;;
esac

# ---------- Firewall ----------------------------------------------------------
section "Application firewall"
FW=/usr/libexec/ApplicationFirewall/socketfilterfw
case "$($FW --getglobalstate 2>/dev/null)" in
  *enabled*) ok "firewall enabled" ;;
  *) bad "firewall off — re-run security.sh" ;;
esac
case "$($FW --getstealthmode 2>/dev/null)" in
  *"stealth mode is on"*) ok "stealth mode on" ;;
  *) bad "stealth mode off — re-run security.sh" ;;
esac

# ---------- Automatic updates -------------------------------------------------
section "Automatic updates"
su_key() { # su_key <domain-path> <key> <label>
  if [ "$(defaults read "$1" "$2" 2>/dev/null)" = "1" ]; then ok "$3"
  else bad "$3 — re-run security.sh"; fi
}
SU=/Library/Preferences/com.apple.SoftwareUpdate
su_key "$SU" AutomaticCheckEnabled            "check for updates"
su_key "$SU" AutomaticDownload                "download updates"
su_key "$SU" AutomaticallyInstallMacOSUpdates "install macOS updates"
su_key "$SU" CriticalUpdateInstall            "install security responses"
su_key "$SU" ConfigDataInstall                "install system data files"
su_key /Library/Preferences/com.apple.commerce AutoUpdate "App Store auto-update"

# ---------- Supply chain ------------------------------------------------------
section "Supply chain"
if command -v npm >/dev/null 2>&1; then
  if [ "$(npm config get ignore-scripts 2>/dev/null)" = "true" ]; then
    ok "npm ignore-scripts=true"
  else
    bad "npm install scripts NOT disabled — re-run security.sh"
  fi
else
  warn "npm not found — is mise's node on PATH?"
fi

# ---------- Touch ID for sudo -------------------------------------------------
section "Touch ID for sudo"
if grep -q "^auth.*pam_tid" /etc/pam.d/sudo_local 2>/dev/null; then
  ok "pam_tid enabled in /etc/pam.d/sudo_local"
else
  bad "Touch ID for sudo not enabled — re-run security.sh"
fi

# ---------- Security apps -----------------------------------------------------
section "Security apps"
app() { # app <name.app> <label> [<hint>]
  if [ -d "/Applications/$1" ]; then ok "$2 installed"
  else bad "$2 missing${3:+ — $3}"; fi
}
app "Little Snitch.app"      "Little Snitch"    "brew install --cask little-snitch"
app "BlockBlock Helper.app"  "BlockBlock"       "brew install --cask blockblock"
app "KnockKnock.app"         "KnockKnock"       "brew install --cask knockknock"
app "OverSight.app"          "OverSight"        "brew install --cask oversight"
if pgrep -qf "littlesnitch.daemon"; then
  ok "Little Snitch daemon running (Alert Mode setup: see TODO.md)"
else
  warn "Little Snitch daemon not running — launch the app and enable it"
fi
# NextDNS: heuristic — pass if their app is installed or the resolver is theirs.
if [ -d "/Applications/NextDNS.app" ] \
   || scutil --dns 2>/dev/null | grep -qE "nameserver.*45\.90\.(28|30)\."; then
  ok "NextDNS in use"
else
  warn "NextDNS not detected (resolver is likely your router) — see TODO.md"
fi

# ---------- Dotfiles ----------------------------------------------------------
section "Dotfiles (symlinks into $DOTS)"
linkcheck() { # linkcheck <dest> <src>
  if [ "$(readlink "$1" 2>/dev/null)" = "$2" ]; then ok "$1"
  else bad "$1 not linked to $2 — re-run setup.sh"; fi
}
linkcheck "$HOME/.zshrc"                     "$DOTS/zshrc"
linkcheck "$HOME/.config/zsh/shortcuts.zsh"  "$DOTS/shortcuts.zsh"
linkcheck "$HOME/.zsh_plugins.txt"           "$DOTS/zsh_plugins.txt"
linkcheck "$HOME/.config/starship.toml"      "$DOTS/starship.toml"
linkcheck "$HOME/.config/ghostty/config"     "$DOTS/ghostty-config"
linkcheck "$HOME/.gitconfig"                 "$DOTS/gitconfig"

# ---------- Packages & runtimes ----------------------------------------------
section "Homebrew"
check "everything in Brewfile installed (brew bundle check)" \
  brew bundle check --file="$DIR/Brewfile"

section "Language runtimes (mise)"
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)" 2>/dev/null || true
  for tool in node python go cargo; do
    check "$tool on PATH" command -v "$tool"
  done
else
  bad "mise not installed"
fi

section "Nix"
check "nix on PATH" command -v nix

# ---------- Git & credentials -------------------------------------------------
section "Git & credentials"
check "gh authenticated" gh auth status
[ -n "$(git config --global user.email 2>/dev/null)" ] \
  && ok "git identity set ($(git config --global user.email))" \
  || bad "git identity missing — edit dotfiles/gitconfig"
case "$(git config --global gpg.ssh.program 2>/dev/null)" in
  *op-ssh-sign*) ok "commit signing via 1Password (op-ssh-sign)" ;;
  *) warn "op-ssh-sign not configured in gitconfig" ;;
esac

# ---------- Summary -----------------------------------------------------------
printf "\n\033[1m%d passed, %d warnings, %d failed\033[0m\n" "$PASS" "$WARN" "$FAIL"
if [ -f "$DIR/TODO.md" ] && grep -q "^- \[ \]" "$DIR/TODO.md"; then
  printf "Unchecked manual items remain in TODO.md:\n"
  grep "^- \[ \]" "$DIR/TODO.md" | sed 's/^- \[ \] /  • /' | cut -c1-100
fi
[ "$FAIL" -eq 0 ]
