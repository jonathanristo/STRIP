#!/usr/bin/env bash
# Layer 2 — pure parser unit tests. Sources stripctl in STRIP_TEST_MODE (no side effects) and calls
# the sp_* functions directly. Fast, no Docker. These lock in the exact bugs we chased.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"
load_parsers

echo "── parsers ──"

# ── sp_split_hostports: last-colon split, IPv6-safe, [] stripped, non-numeric ports dropped ──
got="$(printf 'example.com:443\n192.0.2.10:8080\n[2001:db8::1]:8443\n2001:db8::1:443\nhost.io:22\nbad:port\n' | sp_split_hostports)"
want="$(printf 'example.com\t443\n192.0.2.10\t8080\n2001:db8::1\t8443\n2001:db8::1\t443\nhost.io\t22')"
assert_eq "sp_split_hostports: v4/v6/bracketed/hostname, drops non-numeric port" "$want" "$got"

# regression: bracketed IPv6 naabu row must normalize to the SAME host nmap emits (no dup service)
got="$(printf '[2001:db8::1]:443\n' | sp_split_hostports | cut -f1)"
assert_eq "sp_split_hostports: [2001:db8::1] -> 2001:db8::1 (matches nmap)" "2001:db8::1" "$got"

# ── sp_urls_from_hostports: IPv6 bracketing in URLs ──
got="$(printf 'example.com:443\n2001:db8::1:8443\n' | sp_urls_from_hostports)"
want="$(printf 'http://example.com:443\nhttps://example.com:443\nhttp://[2001:db8::1]:8443\nhttps://[2001:db8::1]:8443')"
assert_eq "sp_urls_from_hostports: brackets IPv6, http+https per host:port" "$want" "$got"

# ── sp_clean_resolvers: CRLF, inline comments, blank lines, whitespace ──
got="$(printf '1.1.1.1\r\n8.8.8.8 # google\n\n   \n# full-line comment\n9.9.9.9\n' | sp_clean_resolvers)"
want="$(printf '1.1.1.1\n8.8.8.8\n9.9.9.9')"
assert_eq "sp_clean_resolvers: strips CR/comments/blanks/whitespace" "$want" "$got"

# ── sp_nmap_hosts: IP literals to their family; hostnames to BOTH ──
got="$(printf 'host.io\n1.2.3.4\n2001:db8::1\n' | sp_nmap_hosts 4)"
assert_eq "sp_nmap_hosts 4: v4 literal + hostname (not v6)" "$(printf '1.2.3.4\nhost.io')" "$got"
got="$(printf 'host.io\n1.2.3.4\n2001:db8::1\n' | sp_nmap_hosts 6)"
assert_eq "sp_nmap_hosts 6: v6 literal + hostname (not v4)" "$(printf '2001:db8::1\nhost.io')" "$got"

# ── sp_nuclei_targets: one URL per host:port, prefer https, drop failed ──
got="$(cat <<'EOF' | sp_nuclei_targets
{"host":"h.io","port":"80","scheme":"http","url":"http://h.io:80","failed":false}
{"host":"h.io","port":"443","scheme":"https","url":"https://h.io:443","failed":false}
{"host":"h.io","port":"8443","scheme":"http","url":"http://h.io:8443","failed":false}
{"host":"h.io","port":"8443","scheme":"https","url":"https://h.io:8443","failed":false}
{"host":"h.io","port":"8080","scheme":"https","url":"https://h.io:8080","failed":true}
{"host":"h.io","port":"8080","scheme":"http","url":"http://h.io:8080","failed":false}
EOF
)"
want="$(printf 'http://h.io:80\nhttp://h.io:8080\nhttps://h.io:443\nhttps://h.io:8443')"
assert_eq "sp_nuclei_targets: dedup host:port, prefer https, drop failed" "$want" "$got"

# all httpx rows failed -> EMPTY target set (webscan must then skip nuclei, never fall back to urls.txt)
got="$(printf '{"host":"h.io","port":"443","scheme":"https","url":"https://h.io:443","failed":true}\n' | sp_nuclei_targets)"
assert_eq "sp_nuclei_targets: all-failed httpx yields empty set" "" "$got"

# ── sp_nuclei_target_list: validated set only — NEVER the raw urls.txt cross-product ──
d="$(mktemp -d)"
printf 'http://h.io:80\nhttp://h.io:443\nhttp://junk-host:9\n' > "$d/urls.txt"   # raw list that must be IGNORED
printf '{"host":"h.io","port":"443","scheme":"https","url":"https://h.io:443","failed":false}\n' > "$d/httpx.json"
assert_eq "sp_nuclei_target_list: validated only, ignores urls.txt" "https://h.io:443" "$(sp_nuclei_target_list "$d")"
printf '{"host":"h.io","port":"443","scheme":"https","url":"https://h.io:443","failed":true}\n' > "$d/httpx.json"
assert_eq "sp_nuclei_target_list: all-failed httpx → empty (not urls.txt)" "" "$(sp_nuclei_target_list "$d")"
rm -f "$d/httpx.json"
assert_eq "sp_nuclei_target_list: no httpx.json → empty (never urls.txt)" "" "$(sp_nuclei_target_list "$d")"
printf '{"host":"h.io","port":"443","scheme":"https","url":"https://h.io:443","failed":false}\n' > "$d/httpx.json"
printf 'https://h.io:443/admin\nhttps://h.io:443/login\n' > "$d/katana.txt"
assert_eq "sp_nuclei_target_list: includes katana crawl (sweep)" \
  "$(printf 'https://h.io:443\nhttps://h.io:443/admin\nhttps://h.io:443/login')" "$(sp_nuclei_target_list "$d")"
rm -rf "$d"

# ── sp_email_posture: absences → email_security findings; a fully-configured domain yields none ──
d="$(mktemp -d)"
printf 'good.com\nweak.com\nbad.com\n' > "$d/in_domains.txt"
cat > "$d/email_txt.json" <<'EOF'
{"host":"good.com","txt":["v=spf1 ~all"]}
{"host":"_dmarc.good.com","txt":["v=DMARC1; p=reject"]}
{"host":"_mta-sts.good.com","txt":["v=STSv1; id=1"]}
{"host":"weak.com","txt":["v=spf1 ~all"]}
{"host":"_dmarc.weak.com","txt":["v=DMARC1; p=none"]}
EOF
printf '{"host":"good.com","caa":["pki.goog"]}\n{"host":"weak.com","caa":["le.org"]}\n' > "$d/email_caa.json"
SCAN_TS="TS"
got="$(sp_email_posture "$d" | jq -r '.hostname_at_observation_time+"/"+.template_id' | sort | tr '\n' ' ')"
want="bad.com/email-caa-missing bad.com/email-dmarc-missing bad.com/email-mta-sts-missing bad.com/email-spf-missing weak.com/email-dmarc-p-none weak.com/email-mta-sts-missing "
assert_eq "sp_email_posture: flags absences, configured domain clean" "$want" "$got"
assert_eq "sp_email_posture: every finding is category email_security" "email_security" \
  "$(sp_email_posture "$d" | jq -rs 'map(.category)|unique|join(",")')"
rm -rf "$d"

# sp_email_posture: NO collection artifact (email_txt.json absent) → NO findings — "not assessed", not "all missing"
d="$(mktemp -d)"; printf 'x.com\n' > "$d/in_domains.txt"
assert_eq "sp_email_posture: missing artifact yields no findings (no false positives)" "" "$(SCAN_TS=TS sp_email_posture "$d")"
rm -rf "$d"

# sp_email_posture: MALFORMED artifact → not assessed (no findings), same as missing
d="$(mktemp -d)"; printf 'x.com\n' > "$d/in_domains.txt"; printf '{bad json' > "$d/email_txt.json"
assert_eq "sp_email_posture: malformed artifact yields no findings" "" "$(SCAN_TS=TS sp_email_posture "$d")"
rm -rf "$d"

# ── sp_takeover_findings: confirmed (nuclei match) vs potential (known-service CNAME); safe skipped ──
d="$(mktemp -d)"
cat > "$d/resolved.json" <<'EOF'
{"host":"dangling.x.com","a":[],"cname":["gone.s3.amazonaws.com"]}
{"host":"maybe.x.com","a":["1.1.1.1"],"cname":["app.herokuapp.com"]}
{"host":"safe.x.com","a":["1.1.1.1"],"cname":["real.cdn.example.net"]}
{"host":"plain.x.com","a":["1.1.1.1"],"cname":null}
EOF
printf '{"host":"dangling.x.com","template-id":"s3-takeover"}\n' > "$d/takeover.jsonl"
SCAN_TS="TS"
got="$(sp_takeover_findings "$d" | jq -r '.hostname_at_observation_time+"/"+.state+"/"+.severity' | sort | tr '\n' ' ')"
assert_eq "sp_takeover_findings: confirmed+potential, safe/no-cname skipped" \
  "dangling.x.com/confirmed/high maybe.x.com/potential/medium " "$got"
assert_eq "sp_takeover_findings: category is takeover" "takeover" \
  "$(sp_takeover_findings "$d" | jq -rs 'map(.category)|unique|join(",")')"
rm -rf "$d"

# sp_takeover_findings: URL-shaped nuclei .host still matches the bare hostname → confirmed, not potential
d="$(mktemp -d)"
printf '{"host":"dangle.x.com","a":[],"cname":["gone.s3.amazonaws.com"]}\n' > "$d/resolved.json"
printf '{"host":"https://dangle.x.com:443/p","template-id":"s3"}\n' > "$d/takeover.jsonl"
assert_eq "sp_takeover_findings: URL-shaped confirmed host normalizes to confirmed" "confirmed/high" \
  "$(SCAN_TS=TS sp_takeover_findings "$d" | jq -r '.state+"/"+.severity')"
rm -rf "$d"

# sp_takeover_findings: MALFORMED takeover.jsonl → confirmed safely empty; potential findings STILL emit
d="$(mktemp -d)"
printf '{"host":"maybe.x.com","a":["1.1.1.1"],"cname":["app.herokuapp.com"]}\n' > "$d/resolved.json"
printf '{bad json' > "$d/takeover.jsonl"
assert_eq "sp_takeover_findings: malformed takeover.jsonl still emits potentials" "potential/medium" \
  "$(SCAN_TS=TS sp_takeover_findings "$d" | jq -r '.state+"/"+.severity')"
rm -rf "$d"

# ── sp_seed_guard: refuse to expand with zero exclusions unless the whole ASN is acknowledged ──
assert_eq "sp_seed_guard: 0 exclusions, unacknowledged → refuse" "refuse" "$(sp_seed_guard 0 false)"
assert_eq "sp_seed_guard: 0 exclusions, acknowledged → expand"   "expand" "$(sp_seed_guard 0 true)"
assert_eq "sp_seed_guard: with exclusions → expand"              "expand" "$(sp_seed_guard 3 false)"

# ── sp_filter_cidrs: CONTAINMENT-aware — a broad exclusion drops CHILD CIDRs, not just exact matches ──
ex="$(mktemp)"; printf '10.0.0.0/8\n172.16.0.0/12\n' > "$ex"
assert_eq "sp_filter_cidrs: broad exclusion drops child CIDRs (v4 containment, v6 untouched)" \
  "192.0.2.0/24 198.51.100.0/24 2001:db8::/48 " \
  "$(printf '192.0.2.0/24\n10.1.2.0/24\n198.51.100.0/24\n172.16.5.0/24\n2001:db8::/48\n' | sp_filter_cidrs "$ex" | tr '\n' ' ')"
rm -f "$ex"

# ── latest_run_dir: sort by name (not mtime), accept zero-result runs, skip empty startup dir ──
# (save/restore globals instead of a subshell, so the assertion actually counts toward the total)
_sh="$STRIP_HOME"; _or="$OUTROOT"
root="$(mktemp -d)"; STRIP_HOME="$root"; OUTROOT="./out"; mkdir -p "$root/out"
mkdir -p "$root/out/20200101-000000"; echo x > "$root/out/20200101-000000/ports.naabu.txt"  # older, has output
mkdir -p "$root/out/20200103-000000"; echo d > "$root/out/20200103-000000/domains.txt"       # newer, zero-result but valid
mkdir -p "$root/out/20200105-000000"                                                          # newest, EMPTY (startup dir)
touch "$root/out/20200101-000000"   # bump the old dir's mtime — name-sort must still beat mtime-sort
assert_eq "latest_run_dir: newest by NAME, zero-result ok, skips empty" "20200103-000000" "$(basename "$(latest_run_dir)")"
rm -rf "$root"; STRIP_HOME="$_sh"; OUTROOT="$_or"

summary "parsers"
