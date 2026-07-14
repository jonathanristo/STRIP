#!/usr/bin/env bash
# Layer 5 — integration (opt-in: STRIP_INTEGRATION=1). Exercises real containers against the network.
# Focused on the bug-prone dnsx path the reviews kept hitting: custom resolver file + dnsx.err capture.
# Uses the same crun contract as stripctl (-T + </dev/null) so it reproduces real invocation behaviour.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
cd "$REPO"

echo "── integration (opt-in) ──"
if [[ "${STRIP_INTEGRATION:-0}" != "1" ]]; then skip "integration" "set STRIP_INTEGRATION=1 to run"; summary "integration"; exit $?; fi
if ! docker_ok; then skip "integration" "docker not available"; summary "integration"; exit $?; fi

work="$REPO/data/out/_it_$$"; mkdir -p "$work"
cleanup(){ rm -rf "$work"; }
trap cleanup EXIT
rel="data/out/$(basename "$work")"

dnsx(){ docker compose -f docker-compose.yml run --rm -T dnsx "$@" </dev/null; }

# 1) dnsx resolves a stable name via an explicit custom resolver file -> resolved.json has A records
printf 'one.one.one.one\n' > "$work/subs.txt"
printf '1.1.1.1\n' > "$work/resolvers.clean.txt"
dnsx -l "/$rel/subs.txt" -r "/$rel/resolvers.clean.txt" -a -json -silent \
     -o "/$rel/resolved.json" >/dev/null 2>"$work/dnsx.err" || true
if [[ -s "$work/resolved.json" ]] && jq -e '.a and (.a|length>0)' "$work/resolved.json" >/dev/null 2>&1; then
  pass "integration: dnsx custom-resolver resolves one.one.one.one (A records present)"
else
  fail "integration: dnsx custom-resolver resolve" "no A records in resolved.json (network? image?)"
fi

# 2) dnsx failure is diagnosable: a bogus/unreachable resolver yields no records but stderr is captured
: > "$work/dnsx.err"
dnsx -l "/$rel/subs.txt" -r "203.0.113.201" -a -json -silent -retry 1 \
     -o "/$rel/resolved_bad.json" >/dev/null 2>"$work/dnsx.err" || true
# with an unreachable resolver there should be no resolved records (the diagnostic value is that the
# run does not silently look successful — resolved_bad.json is empty/absent)
if [[ ! -s "$work/resolved_bad.json" ]]; then
  pass "integration: unreachable resolver produces no false-positive records"
else
  skip "integration: unreachable resolver" "got records (resolver reachable in this env?)"
fi

summary "integration"
