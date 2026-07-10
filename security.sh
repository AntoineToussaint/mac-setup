#!/usr/bin/env bash
# ~/mac-setup/security.sh — macOS security hardening. Re-runnable (idempotent).
# Needs sudo for the firewall / update / Touch ID steps — run it yourself in a
# terminal so you can enter your password.
set -euo pipefail

log() { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }

# Cache sudo once up front. All the privileged steps below are quick and
# consecutive, so one prompt covers them. (When run via setup.sh the credential
# is already warm, so this is a no-op there.) Never run this script with `sudo`.
sudo -v

# ---------- Baseline status (report only — fix in System Settings if off) ----
log "Baseline status"
fdesetup status        # FileVault: full-disk encryption — must be On
csrutil status         # System Integrity Protection — must be enabled
spctl --status         # Gatekeeper: code-signature checks — must be enabled

# ---------- Application firewall (inbound) -----------------------------------
log "Enabling application firewall + stealth mode (sudo)"
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# ---------- Automatic updates -------------------------------------------------
log "Enabling automatic macOS + security updates (sudo)"
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true  # App Store apps

# ---------- Supply chain: package-manager lifecycle scripts ------------------
# Malicious npm packages run code via install scripts — the #1 dev attack vector.
# pnpm >= 10 and bun already block dependency scripts by default; npm does not.
log "Disabling npm install scripts globally"
if command -v npm >/dev/null 2>&1; then
  npm config set ignore-scripts true
  echo "npm ignore-scripts=true (per-project opt-in: npm rebuild <pkg> --ignore-scripts=false after reviewing the script)"
else
  echo "npm not found — re-run after mise installs node"
fi

# ---------- Touch ID for sudo -------------------------------------------------
# Also a security win: you stop typing your login password into terminals.
log "Enabling Touch ID for sudo"
if [ ! -f /etc/pam.d/sudo_local ]; then
  sudo sh -c 'sed "s/^#auth/auth/" /etc/pam.d/sudo_local.template > /etc/pam.d/sudo_local'
  echo "Touch ID for sudo enabled"
else
  echo "already enabled"
fi

log "Done. Manual follow-ups (see README → Security):"
cat <<'EOF'
  1. Little Snitch: launch it, choose Alert Mode, approve as you go for a few days.
  2. NextDNS: create a profile at https://nextdns.io (enable threat-intel feeds,
     newly-registered-domain blocking), then install their macOS app or set the
     DNS-over-HTTPS profile in System Settings.
  3. KnockKnock: run once to audit everything currently persisting on the machine.
  4. Hardware security key (YubiKey): register on GitHub, Google, and cloud accounts.
EOF
