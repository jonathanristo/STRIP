#!/usr/bin/env bash
# Regenerate the golden merge baseline from the fixtures by running the REAL merge and normalizing the
# volatile fields (scan_id/observed_at). Run this ONLY after an intentional merge change, then eyeball
# `git diff`-style what changed before trusting it. Needs Docker for the dualstack_nmap fixture.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
cd "$REPO"

STREAMS=(dns hosts services web_assets tls findings)
for fx in basic_v4 ipv6_bracket dualstack_nmap empty; do
  [[ "$fx" == dualstack_nmap ]] && ! docker_ok && { echo "skip $fx (no docker)"; continue; }
  rd="$REPO/data/out/_regen_$fx"; rm -rf "$rd"; mkdir -p "$rd"; cp -R "$TESTS_DIR/fixtures/$fx/." "$rd/"
  ( cd "$REPO" && ./stripctl merge "$rd" ) >/dev/null 2>&1 || true
  mkdir -p "$TESTS_DIR/golden/$fx"
  for s in "${STREAMS[@]}"; do
    [[ -f "$rd/$s.ndjson" ]] && normalize_ndjson < "$rd/$s.ndjson" | sort > "$TESTS_DIR/golden/$fx/$s.ndjson"
  done
  rm -rf "$rd"
  echo "regenerated golden/$fx"
done
