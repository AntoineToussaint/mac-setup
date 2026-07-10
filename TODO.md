# TODO — manual follow-ups

Things `setup.sh` / `security.sh` can't automate. Check off as you go;
`bash doctor.sh` verifies everything that's machine-checkable.

## Security (see README → Security)

- [ ] **Little Snitch** — installed and running, but needs configuring: open it,
      choose **Alert Mode**, approve connections as you go for a few days, then
      switch to rules. (Silent Mode "allow" defeats the point.)
- [ ] **NextDNS** — not set up (doctor shows DNS is still the router).
      Create a profile at <https://nextdns.io>, enable threat-intel feeds +
      newly-registered-domain blocking, then install their macOS app or add the
      DNS-over-HTTPS profile in System Settings → Network.
- [ ] **KnockKnock** — run it once (`/Applications/KnockKnock.app`) to audit
      everything currently persisting on the machine; investigate anything unsigned
      or unfamiliar.
- [ ] **YubiKey** — register the hardware key as 2FA on GitHub, Google, and cloud
      accounts (and a backup key stored elsewhere).

## Setup

- [ ] **Ghostty** — set as default terminal (Ghostty → Settings, or just use it).
- [ ] **Setapp** — sign in and install: a window manager (Swish / Rectangle Pro /
      Mosaic), TablePlus, DevUtils, Paste, CleanShot X.

## Done (verified by doctor)

- [x] `gh auth login` — logged in as AntoineToussaint
- [x] gitconfig identity + 1Password commit signing (`op-ssh-sign`)
- [x] Firewall + stealth, auto-updates, npm `ignore-scripts`, Touch ID sudo
- [x] FileVault / SIP / Gatekeeper all on
