#!/bin/zsh
# Behavioral tests for devtunnel.
#
# Cloudflare is stubbed: a fake `cloudflared` on PATH records its arguments and
# reports one pre-existing tunnel. Nothing here talks to the network or touches
# the real ~/.cloudflared.

emulate -L zsh
setopt ERR_EXIT PIPE_FAIL

readonly ROOT="${0:A:h:h}"
readonly TUNNEL="$ROOT/bin/devtunnel"

fail() {
  print -u2 -r -- "devtunnel test failed: $*"
  exit 1
}

[[ "$($TUNNEL --version)" == 'devtunnel 1.1.0' ]] || fail 'version output'

SANDBOX="$(mktemp -d -t devtunnel-test)"
typeset -a KILL_PIDS=()
cleanup() {
  (( ${#KILL_PIDS} )) && kill "${KILL_PIDS[@]}" 2>/dev/null
  command rm -rf -- "$SANDBOX"
}
trap cleanup EXIT INT TERM

mkdir -p "$SANDBOX/home/.cloudflared" "$SANDBOX/bin" "$SANDBOX/empty"
: > "$SANDBOX/home/.cloudflared/cert.pem"   # pretend `devtunnel login` ran

# Stub cloudflared: `tunnel list` reports dev-existing-example-com as already
# created plus anything `tunnel create` made during this run. Every other
# subcommand just logs its arguments and succeeds.
cat > "$SANDBOX/bin/cloudflared" <<'STUB'
#!/bin/zsh
print -r -- "cloudflared $*" >> "$STUB_LOG"
if [[ "$1" == tunnel && "$2" == create ]]; then
  print -r -- "$3" >> "$STUB_CREATED"
fi
if [[ "$1" == tunnel && "$2" == list && "$3" == --output ]]; then
  # An account with zero tunnels emits a bare `null`, which naive jq cannot
  # iterate. STUB_EMPTY reproduces that first-tunnel-ever case.
  if [[ -n "${STUB_EMPTY:-}" && ! -s "$STUB_CREATED" ]]; then
    print -r -- 'null'
    exit 0
  fi
  {
    # Real cloudflared marks a LIVE tunnel with the zero timestamp, not null —
    # the stub said null, which hid a filter bug that broke every real tunnel.
    print -rn -- '[{"id":"11111111-2222-3333-4444-555555555555","name":"dev-existing-example-com","deleted_at":"0001-01-01T00:00:00Z"}'
    integer n=0
    if [[ -f "$STUB_CREATED" ]]; then
      while IFS= read -r created; do
        n=$(( n + 1 ))
        print -rn -- ",{\"id\":\"00000000-0000-0000-0000-00000000000$n\",\"name\":\"$created\",\"deleted_at\":\"0001-01-01T00:00:00Z\"}"
      done < "$STUB_CREATED"
    fi
    # A genuinely deleted tunnel carries a real timestamp and must be ignored,
    # so a stale name never gets reused.
    print -rn -- ',{"id":"deadbeef-0000-0000-0000-000000000000","name":"dev-deleted-example-com","deleted_at":"2026-01-02T03:04:05Z"}'
    print -r -- ']'
  }
fi
exit 0
STUB
chmod +x "$SANDBOX/bin/cloudflared"

# Stub dig so `check` is tested offline: only zones listed in STUB_NS answer NS,
# which is exactly how a real delegation walk behaves.
cat > "$SANDBOX/bin/dig" <<'STUB'
#!/bin/zsh
zone="${@[-1]}"
case "$zone" in
  oncf.example)     print -r -- 'alina.ns.cloudflare.com.'; print -r -- 'kip.ns.cloudflare.com.' ;;
  elsewhere.example) print -r -- 'ns-1213.awsdns-23.org.' ;;
esac
exit 0
STUB
chmod +x "$SANDBOX/bin/dig"

export STUB_LOG="$SANDBOX/calls.log"
export STUB_CREATED="$SANDBOX/created.log"
# Point devtunnel's Tailscale.app fallback at nothing for the whole run. The
# stub on PATH is what should answer; without this, a machine with a real
# Tailscale.app could satisfy the fallback and exec an actual public Funnel.
export DEVTUNNEL_TS_APP_BIN="$SANDBOX/no-such-tailscale"
export HOME="$SANDBOX/home"
export PATH="$SANDBOX/bin:$PATH"

# --- hostname validation ------------------------------------------------------
for bad in '' 'localhost' 'bad..host.com' '-lead.example.com' 'trail-.example.com'; do
  if "$TUNNEL" up "$bad" 3000 >/dev/null 2>&1; then
    fail "accepted invalid hostname: '$bad'"
  fi
done
[[ ! -s "$STUB_LOG" ]] || fail 'invalid hostname reached cloudflared'

# --- target shorthand ---------------------------------------------------------
if "$TUNNEL" up dev.example.com 'ftp://nope' >/dev/null 2>&1; then
  fail 'accepted an unsupported target scheme'
fi

# --- up: creates a missing tunnel, routes DNS, writes ingress -----------------
: > "$STUB_LOG"
"$TUNNEL" up dev.example.com 3000 >/dev/null 2>&1

cfg="$HOME/.cloudflared/dev-dev-example-com.yml"
[[ -f "$cfg" ]] || fail 'up did not write a config file'
config="$(<"$cfg")"
[[ "$config" == *'hostname: dev.example.com'* ]]     || fail 'ingress hostname missing'
[[ "$config" == *'service: http://localhost:3000'* ]] || fail 'port shorthand not expanded'
[[ "$config" == *'service: http_status:404'* ]]      || fail 'catch-all ingress rule missing'
[[ "$config" != *'noTLSVerify'* ]]                   || fail 'http origin should not disable TLS verify'

calls="$(<"$STUB_LOG")"
[[ "$calls" == *'tunnel create dev-dev-example-com'* ]] || fail 'missing tunnel create'
# --overwrite-dns is what makes the fixed hostname reclaimable across re-runs.
[[ "$calls" == *'route dns --overwrite-dns dev-dev-example-com dev.example.com'* ]] \
  || fail 'missing DNS route with --overwrite-dns'
[[ "$calls" == *"run dev-dev-example-com"* ]] || fail 'tunnel was never run'

# --- up: reuses an existing tunnel instead of creating a duplicate -------------
: > "$STUB_LOG"
"$TUNNEL" up existing.example.com 8443/https >/dev/null 2>&1
calls="$(<"$STUB_LOG")"
[[ "$calls" != *'tunnel create'* ]] || fail 'recreated a tunnel that already exists'

config="$(<"$HOME/.cloudflared/dev-existing-example-com.yml")"
[[ "$config" == *'service: https://localhost:8443'* ]] || fail 'PORT/https not expanded'
[[ "$config" == *'noTLSVerify: true'* ]] || fail 'https origin needs noTLSVerify for dev certs'
[[ "$config" == *'tunnel: 11111111-2222-3333-4444-555555555555'* ]] \
  || fail 'config did not reuse the existing tunnel id'

# --- a deleted tunnel must not be reused ---------------------------------------
# Its name still appears in `tunnel list`, distinguished only by a real
# deleted_at timestamp. Reusing that id would point the config at a dead tunnel.
: > "$STUB_LOG"
"$TUNNEL" up deleted.example.com 3000 >/dev/null 2>&1
[[ "$(<"$STUB_LOG")" == *'tunnel create dev-deleted-example-com'* ]] \
  || fail 'reused a deleted tunnel instead of creating a fresh one'
[[ "$(<"$HOME/.cloudflared/dev-deleted-example-com.yml")" != *'deadbeef'* ]] \
  || fail 'config points at the deleted tunnel id'

# --- an account with no tunnels returns null, not [] ---------------------------
: > "$STUB_CREATED"
STUB_EMPTY=1 "$TUNNEL" up first.example.com 3000 >/dev/null 2>&1
[[ -f "$HOME/.cloudflared/dev-first-example-com.yml" ]] \
  || fail 'could not create the first tunnel when the account listed null'

# --- run: refuses a hostname that was never set up ----------------------------
if "$TUNNEL" run never-configured.example.com >/dev/null 2>&1; then
  fail 'ran a tunnel with no config'
fi

# --- ls: reports both configured hostnames and their targets ------------------
listing="$("$TUNNEL" ls 2>/dev/null)"
[[ "$listing" == *'dev.example.com'* && "$listing" == *'http://localhost:3000'* ]] \
  || fail 'ls did not report the configured hostname/target'
[[ "$listing" == *'existing.example.com'* ]] || fail 'ls missed the second hostname'

# --- rm: deletes the tunnel and its config ------------------------------------
: > "$STUB_LOG"
"$TUNNEL" rm existing.example.com >/dev/null 2>&1
[[ "$(<"$STUB_LOG")" == *'tunnel delete dev-existing-example-com'* ]] || fail 'rm did not delete the tunnel'
[[ ! -f "$HOME/.cloudflared/dev-existing-example-com.yml" ]] || fail 'rm left the config behind'

# --- login is required before anything can be created -------------------------
command rm -f -- "$HOME/.cloudflared/cert.pem"
if "$TUNNEL" up dev.example.com 3000 >/dev/null 2>&1; then
  fail 'created a tunnel without an origin certificate'
fi

# --- check: reports zone readiness without touching cloudflared ---------------
: > "$STUB_LOG"
check_ok="$("$TUNNEL" check dev.oncf.example 2>&1)" || fail 'check rejected a Cloudflare zone'
[[ "$check_ok" == *'zone: oncf.example'* ]]   || fail 'check did not resolve the zone apex'
[[ "$check_ok" == *'is on Cloudflare'* ]]     || fail 'check did not detect Cloudflare nameservers'
# The apex, not the full hostname, is what has to be delegated.
[[ "$check_ok" != *'zone: dev.oncf.example'* ]] || fail 'check treated the subdomain as the zone'

if "$TUNNEL" check dev.elsewhere.example >/dev/null 2>&1; then
  fail 'check passed a zone that is not on Cloudflare'
fi
check_no="$("$TUNNEL" check dev.elsewhere.example 2>&1 || true)"
[[ "$check_no" == *'NOT on Cloudflare yet'* ]] || fail 'check gave no actionable warning'
[[ "$check_no" == *'dash.cloudflare.com'* ]]   || fail 'check did not say how to fix it'

if "$TUNNEL" check bad..host.example >/dev/null 2>&1; then
  fail 'check accepted an invalid hostname'
fi
[[ ! -s "$STUB_LOG" ]] || fail 'check should not invoke cloudflared'

# --- funnel: stable ts.net URL, no DNS involved -------------------------------
# Stub tailscale: `status --json` reports a connected node, everything else logs.
# A function because the "not installed" case below deletes it, and every test
# after that point must get the stub back — otherwise they silently fall through
# to the real Tailscale on this machine and assert against live state.
write_ts_stub() {
  cat > "$SANDBOX/bin/tailscale" <<'STUB'
#!/bin/zsh
print -r -- "tailscale $*" >> "$STUB_LOG"
if [[ "$1" == status && "$2" == --json ]]; then
  print -r -- "{\"BackendState\":\"${STUB_TS_STATE:-Running}\",\"Self\":{\"DNSName\":\"mac.tail1a2b.ts.net.\"}}"
fi
exit 0
STUB
  chmod +x "$SANDBOX/bin/tailscale"
}
write_ts_stub

# `funnel url` must emit the bare URL — CI captures it with $(...).
url="$("$TUNNEL" funnel url 2>/dev/null)"
[[ "$url" == 'https://mac.tail1a2b.ts.net' ]] || fail "funnel url wrong: '$url'"

: > "$STUB_LOG"
"$TUNNEL" funnel 3000 >/dev/null 2>&1
# Must be "localhost:3000", never a bare "3000": tailscale expands a bare port to
# the IPv4 literal, which cannot reach a dev server bound to [::1] only.
[[ "$(<"$STUB_LOG")" == *'tailscale funnel localhost:3000'* ]] \
  || fail "funnel did not target localhost:3000 — got: $(<"$STUB_LOG")"

for bad_port in 0 70000 nonsense; do
  if "$TUNNEL" funnel "$bad_port" >/dev/null 2>&1; then
    fail "funnel accepted an invalid port: $bad_port"
  fi
done

# A logged-out node has no stable hostname yet; fail loudly instead of printing
# "https://" and letting CI point at nothing.
: > "$STUB_LOG"
if STUB_TS_STATE=NeedsLogin "$TUNNEL" funnel url >/dev/null 2>&1; then
  fail 'funnel url succeeded while Tailscale was logged out'
fi
logged_out="$(STUB_TS_STATE=NeedsLogin "$TUNNEL" funnel url 2>&1 || true)"
[[ "$logged_out" == *'not connected'* ]] || fail 'no clear logged-out message'

# "tailscale missing" must be proven with BOTH lookups neutered: an empty PATH
# *and* an app-bundle path that does not exist. Deleting only the stub would let
# a real Tailscale.app satisfy the fallback and exec a genuine public Funnel —
# which is exactly what happened before this guard existed.
command rm -f -- "$SANDBOX/bin/tailscale"
if PATH="$SANDBOX/empty" "$TUNNEL" funnel 3000 >/dev/null 2>&1; then
  fail 'funnel ran without tailscale installed'
fi
missing="$(PATH="$SANDBOX/empty" "$TUNNEL" funnel 3000 2>&1 || true)"
[[ "$missing" == *'tailscale not installed'* ]] || fail "wrong missing-tailscale error: $missing"
write_ts_stub   # everything below must talk to the stub, never the real tailnet

# --- pin: turns a silently changed URL into a visible failure -----------------
"$TUNNEL" funnel pin >/dev/null 2>&1 || fail 'funnel pin failed'
[[ "$(<"$HOME/.config/devtunnel/funnel-url")" == 'https://mac.tail1a2b.ts.net' ]] \
  || fail 'pin recorded the wrong URL'

# Matching pin: stdout stays bare, nothing on stderr.
drift_err="$("$TUNNEL" funnel url 2>&1 >/dev/null)"
[[ -z "$drift_err" ]] || fail "unexpected drift warning: $drift_err"

# Drifted pin: warn on stderr, but stdout must stay usable for $(...) capture.
print -r -- 'https://old-name.tail1a2b.ts.net' > "$HOME/.config/devtunnel/funnel-url"
drift_out="$("$TUNNEL" funnel url 2>/dev/null)"
drift_err="$("$TUNNEL" funnel url 2>&1 >/dev/null)"
[[ "$drift_out" == 'https://mac.tail1a2b.ts.net' ]] || fail 'drift broke stdout'
[[ "$drift_err" == *'URL CHANGED'* ]] || fail 'drift was not reported'
command rm -f -- "$HOME/.config/devtunnel/funnel-url"

# --- token: generated once, then stable and private ---------------------------
tok1="$("$TUNNEL" token 2>/dev/null)"
(( ${#tok1} == 64 )) || fail "token is not 64 chars: '$tok1'"
[[ "$tok1" != *[!0-9a-f]* ]] || fail "token is not pure hex: '$tok1'"
tok2="$("$TUNNEL" token 2>/dev/null)"
[[ "$tok1" == "$tok2" ]] || fail 'token changed between calls'
[[ "$(command stat -f '%Lp' "$HOME/.config/devtunnel/token")" == '600' ]] \
  || fail 'token file is not 0600'

# --- guard: the shared-secret gate in front of the dev server -----------------
GUARD="$ROOT/bin/devtunnel-guard"
[[ -x "$GUARD" ]] || fail 'devtunnel-guard is not executable'

# Ports are chosen at run time, not hard-coded: doctor.sh runs this suite and
# setup.sh gates on doctor, so a fixed port that happened to be busy would fail
# the whole setup for an unrelated reason.
free_port() {
  python3 -c 'import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()'
}
UPSTREAM_PORT="$(free_port)" || fail 'could not find a free port'
GUARD_PORT="$(free_port)" || fail 'could not find a free port'
[[ -n "$UPSTREAM_PORT" && -n "$GUARD_PORT" && "$UPSTREAM_PORT" != "$GUARD_PORT" ]] \
  || fail 'port allocation failed'

if "$GUARD" --listen "$GUARD_PORT" --upstream "$UPSTREAM_PORT" >/dev/null 2>&1; then
  fail 'guard ran with no DEVTUNNEL_TOKEN — that would expose the port unauthenticated'
fi
if DEVTUNNEL_TOKEN=x "$GUARD" --listen "$GUARD_PORT" --upstream "$GUARD_PORT" >/dev/null 2>&1; then
  fail 'guard accepted identical listen/upstream ports'
fi

python3 -m http.server "$UPSTREAM_PORT" --bind 127.0.0.1 --directory "$SANDBOX" >/dev/null 2>&1 &
KILL_PIDS+=($!)
DEVTUNNEL_TOKEN=t0ken "$GUARD" --listen "$GUARD_PORT" --upstream "$UPSTREAM_PORT" >/dev/null 2>&1 &
KILL_PIDS+=($!)

integer ready=0
for _ in {1..40}; do
  if curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$GUARD_PORT/" 2>/dev/null; then ready=1; break; fi
  sleep 0.25
done
(( ready )) || fail "guard did not come up on 127.0.0.1:$GUARD_PORT"

code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@"; }
[[ "$(code "http://127.0.0.1:$GUARD_PORT/")" == 401 ]] \
  || fail 'guard allowed a request with no token'
[[ "$(code -H 'X-Devtunnel-Token: wrong' "http://127.0.0.1:$GUARD_PORT/")" == 401 ]] \
  || fail 'guard allowed a request with the wrong token'
[[ "$(code -H 'X-Devtunnel-Token: t0ken' "http://127.0.0.1:$GUARD_PORT/")" == 200 ]] \
  || fail 'guard rejected the correct token'
# A 404 from the app must arrive as 404, not be masked as a gateway error.
[[ "$(code -H 'X-Devtunnel-Token: t0ken' "http://127.0.0.1:$GUARD_PORT/missing")" == 404 ]] \
  || fail 'guard did not pass through the upstream status'

# --- guard must reach an IPv6-loopback-only upstream --------------------------
# Many dev servers bind [::1] and nothing on 127.0.0.1. A guard that dials the
# IPv4 literal cannot reach them at all, so this is a real-world regression.
V6_PORT="$(free_port)" || fail 'could not find a free port'
V6_GUARD="$(free_port)" || fail 'could not find a free port'
python3 -c "
import http.server, socketserver
class S(socketserver.TCPServer):
    address_family = __import__('socket').AF_INET6
class H(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def do_GET(self):
        b = b'v6-ok'
        self.send_response(200); self.send_header('Content-Length', str(len(b)))
        self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
S(('::1', $V6_PORT), H).serve_forever()
" >/dev/null 2>&1 &
KILL_PIDS+=($!)
DEVTUNNEL_TOKEN=t0ken "$GUARD" --listen "$V6_GUARD" --upstream "$V6_PORT" >/dev/null 2>&1 &
KILL_PIDS+=($!)

ready=0
for _ in {1..40}; do
  if curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$V6_GUARD/" 2>/dev/null; then ready=1; break; fi
  sleep 0.25
done
(( ready )) || fail 'guard did not come up in front of the IPv6-only upstream'
v6_body="$(curl -s --max-time 5 -H 'X-Devtunnel-Token: t0ken' "http://127.0.0.1:$V6_GUARD/")"
[[ "$v6_body" == 'v6-ok' ]] \
  || fail "guard could not reach an IPv6-only upstream (got '$v6_body')"

print -- 'devtunnel tests passed'
