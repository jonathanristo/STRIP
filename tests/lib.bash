# tests/lib.bash — shared helpers for the STRIP test suite.
# Source this from a bash test script (the suite is bash-only: stripctl is #!/usr/bin/env bash and
# relies on BASH_REMATCH / arrays that zsh does not populate the same way).

# repo root = parent of tests/
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$TESTS_DIR/.." && pwd)"
STRIPCTL="$REPO/stripctl"

if [[ -t 1 ]]; then C_G=$'\033[32m'; C_R=$'\033[31m'; C_Y=$'\033[33m'; C_B=$'\033[1m'; C_0=$'\033[0m'
else C_G=; C_R=; C_Y=; C_B=; C_0=; fi

TESTS_RUN=0; TESTS_PASS=0; TESTS_FAIL=0; TESTS_SKIP=0

pass(){ TESTS_RUN=$((TESTS_RUN+1)); TESTS_PASS=$((TESTS_PASS+1)); printf '  %sok%s   %s\n' "$C_G" "$C_0" "$1"; }
fail(){ TESTS_RUN=$((TESTS_RUN+1)); TESTS_FAIL=$((TESTS_FAIL+1)); printf '  %sFAIL%s %s\n' "$C_R" "$C_0" "$1"
        [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }
skip(){ TESTS_RUN=$((TESTS_RUN+1)); TESTS_SKIP=$((TESTS_SKIP+1)); printf '  %sskip%s %s%s\n' "$C_Y" "$C_0" "$1" "${2:+ — $2}"; }

assert_eq(){ # desc expected actual
  if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1" "expected [$2] got [$3]"; fi
}
assert_contains(){ # desc haystack needle
  case "$2" in *"$3"*) pass "$1";; *) fail "$1" "[$2] missing [$3]";; esac
}
assert_ok(){ local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d" "cmd failed: $*"; fi; }
assert_fail(){ local d="$1"; shift; if "$@" >/dev/null 2>&1; then fail "$d" "cmd unexpectedly succeeded: $*"; else pass "$d"; fi; }

summary(){ # label
  echo
  printf '%s%s%s: %d run — %s%d passed%s, %s%d failed%s, %d skipped\n' \
    "$C_B" "${1:-tests}" "$C_0" "$TESTS_RUN" "$C_G" "$TESTS_PASS" "$C_0" "$C_R" "$TESTS_FAIL" "$C_0" "$TESTS_SKIP"
  [[ $TESTS_FAIL -eq 0 ]]
}

have(){ command -v "$1" >/dev/null 2>&1; }
docker_ok(){ have docker && docker info >/dev/null 2>&1; }

# Load the pure parser functions from stripctl without side effects (no run dir, no dispatch).
load_parsers(){ STRIP_TEST_MODE=1 source "$STRIPCTL"; set +eo pipefail 2>/dev/null || true; }

# Normalize a stream of NDJSON so golden comparisons ignore volatile fields (scan_id/observed_at are
# a single per-run timestamp; everything else is deterministic from the fixture inputs).
normalize_ndjson(){
  jq -c '
    if type=="object" then
      (if has("scan_id")    then .scan_id="TS"    else . end)
    | (if has("observed_at") then .observed_at="TS" else . end)
    else . end'
}
