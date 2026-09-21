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
# "Check for updates" is NOT read from the plist. macOS treats an ABSENT
# AutomaticCheckEnabled key as enabled, so `defaults read` returning nothing is
# the normal state on a healthy machine and su_key would report a false failure.
# `softwareupdate --schedule` is the supported reader and accounts for the
# default, MDM profiles, and per-host overrides alike.
case "$(softwareupdate --schedule 2>/dev/null)" in
  *"turned on"*) ok "check for updates" ;;
  *)             bad "check for updates — re-run security.sh" ;;
esac
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
app "BlockBlock Helper.app"  "BlockBlock"       "brew install --cask blockblock"
app "KnockKnock.app"         "KnockKnock"       "brew install --cask knockknock"
app "OverSight.app"          "OverSight"        "brew install --cask oversight"
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
linkcheck "$HOME/.zshenv"                    "$DOTS/zshenv"
linkcheck "$HOME/.zprofile"                  "$DOTS/zprofile"
linkcheck "$HOME/.zshrc"                     "$DOTS/zshrc"
linkcheck "$HOME/.config/zsh/shortcuts.zsh"  "$DOTS/shortcuts.zsh"
linkcheck "$HOME/.zsh_plugins.txt"           "$DOTS/zsh_plugins.txt"
linkcheck "$HOME/.config/zsh/completions/_shell-coach" "$DOTS/completions/_shell-coach"
linkcheck "$HOME/.local/bin/shell-coach"     "$DIR/bin/shell-coach"
linkcheck "$HOME/.local/bin/devtunnel"       "$DIR/bin/devtunnel"
linkcheck "$HOME/.local/bin/devtunnel-guard" "$DIR/bin/devtunnel-guard"
linkcheck "$HOME/.config/starship.toml"      "$DOTS/starship.toml"
linkcheck "$HOME/.config/ghostty/config"     "$DOTS/ghostty-config"
linkcheck "$HOME/.gitconfig"                 "$DOTS/gitconfig"
# Because ~/.zshrc IS a symlink into this repo, any installer that appends to it
# ("# bun completions", nvm, conda, the Rust/Deno installers…) writes straight
# into tracked source. That is usually harmless, but a tool run from a git
# worktree or an agent sandbox appends a path under /private/tmp or /var/folders
# that vanishes when the sandbox does — dead code, symlinked onto every machine
# this repo sets up, in a PUBLIC repo. Catch it here rather than at commit time.
if EPHEMERAL=$(grep -rlE '/private/tmp/|/var/folders/|/scratchpad/' "$DOTS" 2>/dev/null); then
  for f in $EPHEMERAL; do
    bad "$f references an ephemeral sandbox path — an installer appended to it; git diff and revert"
  done
else
  ok "no ephemeral sandbox paths leaked into dotfiles"
fi
# Same class as the sandbox paths above. git punishes it hardest: a signingkey
# under /Users/<someone> breaks every commit, and a value below the [include]
# overrides the personal file, so the victim cannot fix it on their side.
if LEAKED=$(grep -rlE '/Users/[^/]+/' "$DOTS" "$DIR/bin" 2>/dev/null); then
  for f in $LEAKED; do
    bad "$f hardcodes a path under a specific user's home — use \$HOME; git diff and fix"
  done
else
  ok "no hardcoded home directories in dotfiles or bin"
fi
check "zsh startup files parse" zsh -n \
  "$DOTS/zshenv" "$DOTS/zprofile" "$DOTS/zshrc" "$DOTS/shortcuts.zsh" \
  "$DOTS/completions/_shell-coach" "$DIR/bin/shell-coach" "$DIR/bin/devtunnel"
check "shell-coach starts" "$DIR/bin/shell-coach" --version
check "shell-coach behavior and privacy tests" "$DIR/tests/shell-coach_test.zsh"
check "devtunnel starts" "$DIR/bin/devtunnel" --version
check "devtunnel behavior tests" "$DIR/tests/devtunnel_test.zsh"

# ---------- Local dev tunnel --------------------------------------------------
section "Cloudflare tunnel (devtunnel)"
if command -v cloudflared >/dev/null 2>&1; then
  ok "cloudflared installed ($(cloudflared --version 2>/dev/null | head -1))"
  # cert.pem is the per-account origin certificate; without it a named tunnel
  # (the only kind with a fixed hostname) cannot be created or routed.
  if [ -f "$HOME/.cloudflared/cert.pem" ]; then ok "cloudflared authenticated"
  else warn "cloudflared not authenticated — run 'devtunnel login' before the first tunnel"; fi
  # Count via a glob array rather than `ls | wc -l`: no subshell, and an
  # unmatched glob stays literal, so test element 0 for existence.
  TUNNELS=("$HOME"/.cloudflared/dev-*.yml)
  if [ -e "${TUNNELS[0]}" ]; then
    ok "${#TUNNELS[@]} devtunnel hostname(s) configured — 'devtunnel ls'"
  else
    warn "no devtunnel hostnames yet — 'devtunnel up <host> <port>'"
  fi
else
  bad "cloudflared missing — brew bundle --file=$DIR/Brewfile"
fi

# Tailscale is the no-domain path to a stable public URL (devtunnel funnel).
if [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
  ok "Tailscale.app installed"
  # The CLI must be the app's own /usr/local/bin shim. A symlink into the bundle
  # from anywhere else dies on SIGTRAP (broken code signature), and zshenv's
  # PATH order would let such a symlink shadow the working shim.
  if [ -L "$HOME/.local/bin/tailscale" ]; then
    # ~ here is display text in a message to the reader, not a path to expand.
    # shellcheck disable=SC2088
    bad "~/.local/bin/tailscale is a symlink — it shadows the app shim and crashes; rm it"
  elif command -v tailscale >/dev/null 2>&1 && tailscale version >/dev/null 2>&1; then
    ok "tailscale CLI works ($(command -v tailscale))"
  else
    warn "tailscale CLI not usable — log into Tailscale.app once to install its shim"
  fi
  TS_STATE=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "unreachable"' 2>/dev/null)
  case "$TS_STATE" in
    Running)
      TS_URL="https://$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // "?"' | sed 's/\.$//')"
      ok "Tailscale connected as ${TS_URL#https://}"
      # The whole point of the funnel URL is that CI can hard-code it. If the
      # device is renamed or re-registered the name changes silently, so compare
      # against the pinned value and fail loudly rather than let CI 404.
      PIN="${XDG_CONFIG_HOME:-$HOME/.config}/devtunnel/funnel-url"
      if [ -s "$PIN" ]; then
        if [ "$(cat "$PIN")" = "$TS_URL" ]; then
          ok "funnel URL matches the pin ($TS_URL)"
        else
          bad "funnel URL CHANGED — pinned $(cat "$PIN"), now $TS_URL; update the CI secret then 'devtunnel funnel pin'"
        fi
      else
        warn "funnel URL not pinned — run 'devtunnel funnel pin' to catch future drift"
      fi
      ;;
    *) warn "Tailscale not connected (state: $TS_STATE) — open the app and log in" ;;
  esac
else
  warn "Tailscale.app missing — brew bundle --file=$DIR/Brewfile (needed for 'devtunnel funnel')"
fi

# ---------- Packages & runtimes ----------------------------------------------
section "Homebrew"
# Two different questions, two different severities. Plain `brew bundle check`
# fails on merely-OUTDATED packages as well as missing ones, which made a normal
# machine report a hard failure a day after setup — casks like ChatGPT ship
# updates constantly. --no-upgrade asks only "is anything actually missing".
if brew bundle check --file="$DIR/Brewfile" --no-upgrade >/dev/null 2>&1; then
  if brew bundle check --file="$DIR/Brewfile" >/dev/null 2>&1; then
    ok "everything in Brewfile installed and current"
  else
    warn "Brewfile packages installed but some are outdated — brew upgrade"
  fi
else
  bad "packages in Brewfile are MISSING — brew bundle install --file=$DIR/Brewfile"
fi

section "GNU gap fillers (macOS ships no timeout/tac/shuf/nproc/numfmt)"
for tool in timeout tac shuf nproc numfmt; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool available ($(command -v "$tool"))"
  else
    bad "$tool missing — brew install coreutils, then re-run setup.sh"
  fi
done

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
# Installed, not on-PATH: doctor is non-interactive bash and cannot inherit a
# PATH that did not exist when it started, so on the run that installs Nix a
# PATH-only test is a false failure. A new terminal sorts the PATH out.
if command -v nix >/dev/null 2>&1; then
  ok "nix on PATH ($(nix --version 2>/dev/null | head -1))"
elif [ -x /nix/var/nix/profiles/default/bin/nix ]; then
  ok "nix installed ($(/nix/var/nix/profiles/default/bin/nix --version 2>/dev/null | head -1)) — not on this shell's PATH yet; a new terminal picks it up"
else
  bad "nix not installed — re-run setup.sh"
fi

# ---------- Kubernetes / cloud auth -------------------------------------------
# kubectl auth plugins fail LATE and cryptically: the kubeconfig names an exec
# plugin, and a missing binary surfaces as "Unable to connect to the server:
# getting credentials: exec: executable ... not found" mid-incident. They are
# also easy to get wrong — homebrew-core's `kubelogin` installs
# `kubectl-oidc_login`, NOT `kubelogin` (that one is Azure's, in its own tap),
# so "brew says kubelogin is installed" and "kubelogin is on PATH" are
# different facts.
#
# Check the plugins THIS kubeconfig actually names rather than a fixed wish
# list: a laptop with only AKS clusters should not be nagged about GKE.
section "Kubernetes & cloud auth"
if command -v kubectl >/dev/null 2>&1; then
  ok "kubectl on PATH ($(command -v kubectl))"
  KCFG="${KUBECONFIG:-$HOME/.kube/config}"
  if [ ! -f "$KCFG" ]; then
    ok "no kubeconfig at $KCFG — nothing to check"
  else
    # `command:` is the binary kubectl forks; it follows `exec:` in each user.
    plugins="$(awk '/^ *exec:/{e=1} e && /^ *command:/{print $2; e=0}' "$KCFG" | sort -u)"
    if [ -z "$plugins" ]; then
      ok "kubeconfig uses no exec auth plugins"
    fi
    for bin in $plugins; do
      if command -v "$bin" >/dev/null 2>&1; then
        ok "auth plugin $bin available ($(command -v "$bin"))"
      else
        case "$bin" in
          kubelogin)   hint="brew install Azure/kubelogin/kubelogin (AKS/Entra — NOT core's kubelogin)" ;;
          kubectl-oidc_login) hint="brew install kubelogin (int128, generic OIDC)" ;;
          gke-gcloud-auth-plugin) hint="gcloud components install gke-gcloud-auth-plugin" ;;
          *)           hint="install it and re-run" ;;
        esac
        bad "auth plugin $bin MISSING but your kubeconfig requires it — $hint"
      fi
    done
  fi
else
  warn "kubectl not on PATH"
fi
# A hand-installed copy alongside the managed one is how you end up running a
# version brew will never update. Only flag a real duplicate.
for bin in kubectl kubelogin kubectl-oidc_login helm; do
  n="$(command -v -a "$bin" 2>/dev/null | sort -u | wc -l | tr -d ' ')"
  if [ "${n:-0}" -gt 1 ]; then
    warn "$bin resolves to $n copies on PATH — $(command -v -a "$bin" | tr '\n' ' ')"
  fi
done

# ---------- Git & credentials -------------------------------------------------
section "Git & credentials"
check "gh authenticated" gh auth status
if [ -n "$(git config --global --includes user.email 2>/dev/null)" ]; then
  ok "git identity set ($(git config --global --includes user.email))"
else
  bad "git identity missing — run: bash setup.sh --reconfigure"
fi
# Report what is set rather than pushing anyone towards 1Password, which nobody
# here uses. What matters is signing switched ON that cannot work.
SIGN_KEY="$(git config --global --includes user.signingkey 2>/dev/null || true)"
if [ "$(git config --global --includes commit.gpgsign 2>/dev/null)" != "true" ]; then
  ok "commit signing off (fine — Obin does not use 1Password)"
elif [ -z "$SIGN_KEY" ]; then
  bad "commit signing is ON with no signing key — every commit will fail; bash setup.sh --reconfigure"
elif case "$SIGN_KEY" in ssh-*) true ;; *) false ;; esac; then
  ok "commit signing on (inline public key)"
elif [ -r "${SIGN_KEY/#\~/$HOME}" ]; then
  ok "commit signing on ($SIGN_KEY)"
else
  bad "commit signing is ON but the key $SIGN_KEY does not exist — every commit will fail"
fi

# The key existing is only half of it: with gpg.ssh.program set, git hands every
# signature to that binary. 1Password signs through its agent socket, so
# op-ssh-sign fails when the agent is off — and names itself, not git, so it
# reads like an unrelated app problem. Probe the socket; signing something for
# real would pop biometrics on a read-only check.
if [ "$(git config --global --includes commit.gpgsign 2>/dev/null)" = "true" ]; then
  SIGN_PROG="$(git config --global --includes gpg.ssh.program 2>/dev/null || true)"
  if [ -z "$SIGN_PROG" ]; then
    :   # no external signer: git uses ssh-keygen, covered above
  elif [ ! -x "$SIGN_PROG" ]; then
    bad "commit signing calls $SIGN_PROG, which is not installed — every commit will fail"
  elif case "$SIGN_PROG" in *op-ssh-sign) true ;; *) false ;; esac; then
    if [ -n "$(find "$HOME/Library/Group Containers" -name agent.sock 2>/dev/null | head -1)" ]; then
      ok "commit signing via 1Password (agent socket present)"
    else
      bad "commit signing calls op-ssh-sign but 1Password's SSH agent is not running — every commit fails with 'Could not connect to socket'. Turn it on in 1Password > Developer, or drop the signer: git config --file ~/.config/git/identity --unset gpg.ssh.program"
    fi
  else
    ok "commit signing via $SIGN_PROG"
  fi
fi

# ---------- Summary -----------------------------------------------------------
printf "\n\033[1m%d passed, %d warnings, %d failed\033[0m\n" "$PASS" "$WARN" "$FAIL"
if [ -f "$DIR/TODO.md" ] && grep -q "^- \[ \]" "$DIR/TODO.md"; then
  printf "Unchecked manual items remain in TODO.md:\n"
  grep "^- \[ \]" "$DIR/TODO.md" | sed 's/^- \[ \] /  • /' | cut -c1-100
fi
[ "$FAIL" -eq 0 ]
