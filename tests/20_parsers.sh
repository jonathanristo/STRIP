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
