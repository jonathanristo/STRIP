#!/usr/bin/env bash
# Layer 1 — static smoke tests: the script parses, the compose file is valid, and every service
# stripctl invokes actually exists in docker-compose.yml.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
cd "$REPO"

echo "── static smoke ──"

assert_ok "bash -n stripctl (parses clean)" bash -n stripctl

if have shellcheck; then
  # SC1090/1091: dynamic source; SC2016: single-quoted jq/awk programs are intentional
  if shellcheck -e SC1090,SC1091,SC2016 -S warning stripctl >/tmp/strip_shellcheck.txt 2>&1; then
    pass "shellcheck (no warnings/errors)"
  else
    fail "shellcheck" "$(head -20 /tmp/strip_shellcheck.txt)"
  fi
else
  skip "shellcheck" "not installed (brew install shellcheck)"
fi

if docker_ok; then
  assert_ok "docker compose config is valid" docker compose -f docker-compose.yml config -q
else
  skip "docker compose config" "docker not available"
fi

# Every service stripctl runs via crun/compose must be declared in docker-compose.yml.
services="$(docker compose -f docker-compose.yml config --services 2>/dev/null | sort -u)"
if [[ -z "$services" ]]; then
  # fall back to a yaml grep if compose isn't runnable
  services="$(awk '/^  [a-z0-9_-]+:/{gsub(/[: ]/,"");print}' docker-compose.yml 2>/dev/null | sort -u)"
fi
for svc in subfinder amass dnsx naabu nmap httpx katana nuclei testssl sslyze gowitness xmlparse; do
  if grep -qx "$svc" <<<"$services"; then pass "compose service present: $svc"
  else fail "compose service present: $svc" "not found in docker-compose.yml"; fi
done

# Every `crun <tool>` in stripctl should reference a real compose service (guards against typos).
while read -r tool; do
  [[ -z "$tool" ]] && continue
  if grep -qx "$tool" <<<"$services"; then pass "crun target is a real service: $tool"
  else fail "crun target is a real service: $tool" "no compose service '$tool'"; fi
done < <(grep -oE 'crun [a-z0-9_-]+' stripctl | awk '{print $2}' | sort -u)

summary "static"
