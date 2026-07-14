#!/usr/bin/env bash
# STRIP test-suite runner. Runs every layer under bash (the suite is bash-only) and reports an
# overall pass/fail. Integration (layer 5) is opt-in via STRIP_INTEGRATION=1.
#
#   tests/run.sh            # static + parsers + golden + contracts
#   tests/run.sh parsers    # only layers whose name contains "parsers"
#   STRIP_INTEGRATION=1 tests/run.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

layers=(10_static 20_parsers 30_merge_golden 40_contracts 50_integration)
filter="${1:-}"
overall=0; ran=0

for l in "${layers[@]}"; do
  [[ "$l" == 50_integration && "${STRIP_INTEGRATION:-0}" != "1" && -z "$filter" ]] && continue
  [[ -n "$filter" && "$l" != *"$filter"* ]] && continue
  echo
  echo "══════════════════════════════════════════════════════════════"
  echo "  $l"
  echo "══════════════════════════════════════════════════════════════"
  bash "$HERE/$l.sh" || overall=1
  ran=$((ran+1))
done

echo
if [[ $ran -eq 0 ]]; then echo "no layers matched filter: $filter"; exit 2; fi
if [[ $overall -eq 0 ]]; then echo "════ ALL LAYERS PASSED ════"; else echo "════ SOME LAYERS FAILED ════"; fi
exit $overall
