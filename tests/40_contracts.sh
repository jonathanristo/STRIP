#!/usr/bin/env bash
# Layer 4 — tool contract tests. Prove the CURRENT container images actually accept the flags stripctl
# passes them (catches upstream image drift). No scans are run — only each tool's help output.
# Needs Docker; may pull images on first run.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
cd "$REPO"

echo "── tool contracts ──"
if ! docker_ok; then skip "contract tests" "docker not available"; summary "contracts"; exit $?; fi

helptext(){ # service helpargs...  -> tool's help text (stdout+stderr), never fails the caller
  local svc="$1"; shift
  docker compose -f docker-compose.yml run --rm -T "$svc" "$@" </dev/null 2>&1 || true
}

check(){ # service "helpargs" flag...
  local svc="$1" hf="$2"; shift 2
  local out; read -r -a _hf <<<"$hf"; out="$(helptext "$svc" "${_hf[@]}")"
  if [[ -z "$out" ]]; then skip "contract: $svc" "no help output (image unavailable?)"; return; fi
  local f
  for f in "$@"; do
    if grep -qF -- "$f" <<<"$out"; then pass "contract: $svc accepts $f"
    else fail "contract: $svc accepts $f" "not found in $svc help output"; fi
  done
}

# Each row lists the flags stripctl actually passes that tool. (goflags treats -x and --x the same, so
# stripctl's `--rate` is asserted via naabu's help form `-rate`.)
check subfinder -h        -dL -all -silent -o
check dnsx      -h        -l -r -a -aaaa -cname -json -silent -o -txt -caa
check naabu     -h        -list -top-ports -rate -silent -o
check nmap      -h        -6 -sV -p -oX -Pn -iL --version-light
check asnmap    -h        -d -silent -o
check httpx     -h        -l -rl -tls-grab -hash -json -o -status-code -title -tech-detect -server -content-type -content-length -location -favicon
check katana    -h        -list -d -jc -silent -o
check nuclei    -h        -severity -jsonl -l -o -stats -rl -c -ni
# stripctl also passes testssl --fast: it still works but is DEPRECATED and omitted from --help, so it
# cannot be asserted from help text. It is covered operationally (real runs), not here.
check testssl   --help    --jsonfile --file --warnings
check sslyze    --help    --targets_in --json_out
check gowitness "scan file --help"  -f --screenshot-path --write-jsonl --write-jsonl-file --threads --delay

summary "contracts"
