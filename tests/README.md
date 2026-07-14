# STRIP test suite

A layered safety net for `stripctl` — parsing/merge correctness plus proof that the containerized
tools are invoked with flags/files they actually accept.

Zero external dependencies for the core layers: plain `bash` + the tools STRIP already needs (`jq`,
`docker`). `shellcheck` is used if present, skipped if not. **Run under bash, not zsh** — the suite
sources `stripctl`, which relies on `BASH_REMATCH`/arrays.

## Run

```bash
tests/run.sh                    # static + parsers + golden + contracts
tests/run.sh parsers            # just the parser layer (name filter)
tests/run.sh golden
STRIP_INTEGRATION=1 tests/run.sh   # add the opt-in network integration layer
bash tests/20_parsers.sh        # a single layer directly
```

## Layers

| File | Layer | Needs | What it proves |
|------|-------|-------|----------------|
| `10_static.sh` | Static smoke | — (docker/shellcheck optional) | `bash -n`, `docker compose config`, every `crun <tool>` maps to a real compose service |
| `20_parsers.sh` | Parser units | — | `sp_*` functions: host:port split (IPv6/brackets), URL bracketing, resolver cleanup, nmap family split, nuclei target dedup, `latest_run_dir` selection |
| `30_merge_golden.sh` | Golden merge | docker (nmap fixture only) | real `stripctl merge <fixture>` output vs a locked baseline for all 6 streams; asserts merge emits **all** streams |
| `40_contracts.sh` | Tool contracts | docker | each current image's `--help` advertises the flags stripctl passes it (`dnsx -aaaa`, `naabu -rate`, `httpx -rl/-tls-grab/output flags`, `nmap -6/-Pn/-p`, `nuclei -rl/-c/-ni`, `sslyze --targets_in`, …). One exception: testssl's deprecated `--fast` is omitted from `--help`, so it's covered operationally, not asserted here. |
| `50_integration.sh` | Integration | docker + network, `STRIP_INTEGRATION=1` | dnsx custom-resolver resolve + `dnsx.err` capture on failure |

## How it hooks into stripctl

- Parser tests source `stripctl` with `STRIP_TEST_MODE=1`, which skips the run-dir creation and CLI
  dispatch, exposing the pure `sp_*` functions with no side effects.
- Golden tests use `stripctl merge <run-dir>` (the standalone-merge path) against fixture run dirs
  copied under `data/out/` so the containerized `xmlparse` mount can see them.

## Fixtures & golden

`fixtures/<name>/` holds synthetic raw tool outputs (a fake completed run). `golden/<name>/` holds the
expected normalized NDJSON (scan_id/observed_at nulled to `TS`). Current fixtures:

- `basic_v4` — dual A/AAAA host, naabu+httpx+nuclei+testssl+gowitness; exercises dns/hosts/services/
  web_assets/tls (fingerprint-gated)/findings + screenshot map. Domains-only (no `in_ips.txt`).
- `ipv6_bracket` — `[2001:db8::1]:443` vs bare form + AAAA-only hostname; proves bracket normalization
  and that an AAAA-only host maps to the AAAA, never the hostname string.
- `dualstack_nmap` — hostname + `nmap.xml` and `nmap6.xml`; proves v4 **and** v6 service rows both keep
  the hostname (needs docker for xmlparse).
- `empty` — a valid zero-result run; every stream must be the sentinel.

After an **intentional** merge change, refresh the baseline and review it:

```bash
tests/regen_golden.sh
```

## Notes

- The golden layer once caught a real bug: a `set -e`/`pipefail` abort in `merge` that left
  domains-only runs with only `dns.ndjson`. That is now a standing regression check.
- Contract tests may pull images on first run.
