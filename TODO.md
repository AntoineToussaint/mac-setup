# TODO — manual follow-ups

Things `setup.sh` / `security.sh` can't automate. Check off as you go;
`bash doctor.sh` verifies everything that's machine-checkable.

## Security (see README → Security)

- [ ] **NextDNS** (do soon — low-effort, set-and-forget) — not set up (doctor
      shows DNS is still the router). Create a profile at <https://nextdns.io>,
      enable threat-intel feeds + newly-registered-domain blocking, then install
      their macOS app or add the DNS-over-HTTPS profile in System Settings →
      Network.
      Why this over an outbound firewall: blocks known-bad domains system-wide
      with no per-app babysitting. Caveats: account-based (NextDNS sees your DNS
      queries), free tier caps at 300k queries/mo (paid ≈ $20/yr), and it can't
      stop IP-literal or encrypted-SNI connections.
- [ ] **KnockKnock** — run it once (`/Applications/KnockKnock.app`) to audit
      everything currently persisting on the machine; investigate anything unsigned
      or unfamiliar.
- [ ] **YubiKey** — register the hardware key as 2FA on GitHub, Google, and cloud
      accounts (and a backup key stored elsewhere).

## Setup

- [ ] **Proxyman system proxy** — Proxyman (Setapp) sets a macOS system HTTP/HTTPS
      proxy on 127.0.0.1:9090 and its failing TLS tunnel breaks mise/curl/git
      HTTPS ("tunnel error"). Disabled for now via
      `networksetup -setwebproxystate "Wi-Fi" off` (+ `-setsecurewebproxystate`).
      If you want to keep using Proxyman: enable SSL proxying for github.com and
      trust its cert so the tunnel stops failing; otherwise quit Proxyman when
      not actively debugging (it restores the proxy off on clean exit).
- [ ] **Keep the tunnels running across reboots** — both public endpoints are
      live but depend on a foreground process plus `warden` on :18982:
        * <https://dev.codefly.build> — Cloudflare named tunnel (no auth)
        * <https://antoines-macbook-pro.tail07934c.ts.net> — Funnel (no auth)
      Tailscale restores its own Funnel config at boot; cloudflared does not.
      For durability run `sudo cloudflared service install` (installs a launch
      daemon), and make sure `warden` itself starts on boot — otherwise both
      URLs resolve and terminate TLS but return 502.
      Both are unauthenticated by choice. `devtunnel funnel <port> --guard`
      re-adds the shared-secret gate on the Tailscale side; Cloudflare Access
      (Zero Trust → Access → Applications) does the same for dev.codefly.build.
      Security note: a running tunnel publishes that local port to the whole
      internet. Put Cloudflare Access in front of it (Zero Trust → Access →
      Applications) for anything that isn't meant to be public.
- [ ] **Tailscale Funnel** — app installed and logged in as
      `antoines-macbook-pro.tail07934c.ts.net` (doctor confirms). Remaining:
      enable Funnel for the tailnet in the admin console (Access Controls →
      add the `funnel` nodeAttr). Running `devtunnel funnel 3000` prints the
      exact policy snippet to paste. Funnel is public and unauthenticated, so
      add a shared-secret check before pointing GitHub CI at it.
      Do NOT symlink the tailscale CLI into `~/.local/bin` — reaching the
      in-bundle binary through a symlink breaks its code signature (SIGTRAP),
      and zshenv's PATH order makes such a symlink shadow the working
      `/usr/local/bin/tailscale` shim the app installs. doctor checks for this.

## Done (verified by doctor)

- [x] **Ghostty** — installed, configured, and in active use.
- [x] **Setapp** — signed in; Swish/Rectangle, TablePlus, DevUtils, Paste, and
      CleanShot X are installed.
- [x] `gh auth login` — logged in as AntoineToussaint
- [x] gitconfig identity + 1Password commit signing (`op-ssh-sign`)
- [x] Firewall + stealth, auto-updates, npm `ignore-scripts`, Touch ID sudo
- [x] FileVault / SIP / Gatekeeper all on
