#!/usr/bin/env bash
# Layer 3 — golden merge tests (highest value). For each fixture: copy raw tool files into a run dir,
# run the REAL `stripctl merge <dir>`, then compare the 6 normalized NDJSON streams to a golden
# baseline. Also asserts merge emits ALL six streams (regression guard for the domains-only
# set -e/pipefail abort that used to leave only dns.ndjson).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
cd "$REPO"

echo "── golden merge ──"

STREAMS=(dns hosts services web_assets tls findings)
needs_docker(){ [[ "$1" == "dualstack_nmap" ]]; }   # only the nmap fixture invokes the xmlparse container

RD=""; MERGE_RC=0
merge_fixture(){ # $1 fixture name -> sets globals RD (run dir) and MERGE_RC (merge exit status)
  RD="$REPO/data/out/_test_$1"
  rm -rf "$RD"; mkdir -p "$RD"; cp -R "$TESTS_DIR/fixtures/$1/." "$RD/"
  ( cd "$REPO" && ./stripctl merge "$RD" ) >/dev/null 2>&1; MERGE_RC=$?
}

for fx in basic_v4 ipv6_bracket dualstack_nmap empty; do
  if needs_docker "$fx" && ! docker_ok; then skip "golden: $fx" "needs docker (nmap xmlparse)"; continue; fi
  merge_fixture "$fx"

  # the merge command itself must SUCCEED — a merge that writes matching streams then dies in manifest
  # would otherwise slip past the stream diffs
  assert_eq "golden: $fx — merge exits 0" "0" "$MERGE_RC"

  # every stream must exist AND be non-empty (data or sentinel)
  missing=""; for s in "${STREAMS[@]}"; do [[ -s "$RD/$s.ndjson" ]] || missing+="$s "; done
  assert_eq "golden: $fx — merge emitted all 6 streams" "" "$missing"

  # run_manifest.json shape (fields are volatile, so assert structure not exact content)
  if jq -e '.source_module=="STRIP" and (.scan_id|type=="string") and (.spec_version=="sensor-output/1.0")
            and (.streams_emitted|type=="array") and (.record_counts|type=="object")' \
       "$RD/run_manifest.json" >/dev/null 2>&1; then
    pass "golden: $fx — run_manifest.json has the required shape"
  else
    fail "golden: $fx — run_manifest.json shape" "missing/invalid required keys in run_manifest.json"
  fi

  for s in "${STREAMS[@]}"; do
    got="$(normalize_ndjson < "$RD/$s.ndjson" 2>/dev/null | sort)"
    want="$(cat "$TESTS_DIR/golden/$fx/$s.ndjson" 2>/dev/null)"
    assert_eq "golden: $fx/$s.ndjson matches baseline" "$want" "$got"
  done
  rm -rf "$RD"
done

# scan_id stability (round-3 fix): a timestamp-named run dir yields a scan_id DERIVED from the dir
# name, and re-merging the same dir is idempotent — not a fresh merge-time id each time.
tsdir="$REPO/data/out/20200102-030405"; rm -rf "$tsdir"; mkdir -p "$tsdir"; cp -R "$TESTS_DIR/fixtures/basic_v4/." "$tsdir/"
( cd "$REPO" && ./stripctl merge "$tsdir" ) >/dev/null 2>&1 || true
sid1="$(jq -r '.scan_id' "$tsdir/services.ndjson" 2>/dev/null | head -1)"
( cd "$REPO" && ./stripctl merge "$tsdir" ) >/dev/null 2>&1 || true
sid2="$(jq -r '.scan_id' "$tsdir/services.ndjson" 2>/dev/null | head -1)"
assert_eq "scan_id: derived from run-dir name (20200102-030405)" "2020-01-02T03:04:05Z" "$sid1"
assert_eq "scan_id: stable across a re-merge of the same dir" "$sid1" "$sid2"
rm -rf "$tsdir"

echo
echo "  (to refresh the baseline after an intentional merge change: tests/regen_golden.sh)"
summary "golden"
