#!/bin/zsh
# Behavioral and privacy regression tests for shell-coach.

emulate -L zsh
setopt ERR_EXIT PIPE_FAIL

readonly ROOT="${0:A:h:h}"
readonly COACH="$ROOT/bin/shell-coach"

fail() {
  print -u2 -r -- "shell-coach test failed: $*"
  exit 1
}

[[ "$($COACH --version)" == 'shell-coach 0.2.0' ]] || fail 'version output'

rule_output="$({
  for repeat in 1 2 3; do
    print -r -- 'find . -name "*.go"'
    print -r -- 'grep -R TODO .'
    print -r -- 'cat README.md'
    print -r -- 'cd /workspace/company/private-project'
  done
  print -r -- 'git status'
  print -r -- 'git diff'
  print -r -- 'git log --oneline'
  print -r -- 'git branch'
  print -r -- 'git stash list'
  print -r -- 'kill -9 $(lsof -tiTCP:3000)'
} | "$COACH" --stdin --all --no-color)"

for expected in \
  'Reach for fd instead of find' \
  'Use rg for interactive text search' \
  'Use bat when reading files' \
  'Use lg for exploratory Git work' \
  'Use killport for local listeners' \
  'Let zoxide remember private-project'; do
  [[ "$rule_output" == *"$expected"* ]] || fail "missing recommendation: $expected"
done

for expected in \
  'Pattern: find . -name "*.go"' \
  'fd -e go' \
  'Keep find for portable scripts and complex predicates.' \
  'z private-project' \
  'zi      # fuzzy-pick any learned directory'; do
  [[ "$rule_output" == *"$expected"* ]] || fail "missing richer example: $expected"
done

workflow_output="$({
  for repeat in {1..12}; do print -r -- 'ls'; done
  for repeat in {1..10}; do print -r -- 'make test'; done
  for repeat in {1..9}; do
    print -r -- 'codex'
    print -r -- 'claude'
  done
} | "$COACH" --stdin --all --no-color)"

for expected in \
  'Pick the directory view that answers the question' \
  'll                         # details, hidden files, Git state' \
  'Turn repeated builds into a feedback loop' \
  'watchexec -- make test' \
  'Protect long AI sessions with tmux' \
  'tmux new -As mind' \
  'caffeinate -i codex'; do
  [[ "$workflow_output" == *"$expected"* ]] || fail "missing workflow coaching: $expected"
done

privacy_output="$({
  print -r -- 'curl -H "Authorization: Bearer supersecret" "https://api.example.com/users?token=hunter2"'
  print -r -- 'curl -X POST "http://localhost:3000/api/private?api_key=abc123"'
  for repeat in 1 2 3; do
    print -r -- 'cd /Users/antoine/projects/top-secret-acquisition'
  done
  print -r -- 'SECRET_TOKEN=abc123 ./private-deploy customer-name --password swordfish'
  print -r -- 'git clone git@github.com:private/customer-project.git secret-project'
} | "$COACH" --stdin --show-llm-prompt --no-color)"

prompt_only="${privacy_output#*Exact anonymized LM Studio prompt$'\n'}"
for forbidden in \
  supersecret hunter2 abc123 top-secret-acquisition private-deploy \
  customer-name swordfish customer-project secret-project /Users/antoine \
  api.example.com localhost; do
  [[ "$prompt_only" != *"$forbidden"* ]] || fail "LLM prompt leaked: $forbidden"
done

for expected in '3x cd' '2x curl' '1x git clone' \
  'ls already invokes eza; do not recommend replacing ls with eza.' \
  'one copy/paste-safe command'; do
  [[ "$prompt_only" == *"$expected"* ]] || fail "missing safe skeleton: $expected"
done

if "$COACH" --stdin --history-file nowhere </dev/null >/dev/null 2>&1; then
  fail 'accepted mutually exclusive input modes'
fi
if "$COACH" --stdin </dev/null >/dev/null 2>&1; then
  fail 'accepted empty history'
fi

print -- 'shell-coach tests passed'
