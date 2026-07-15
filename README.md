# STRIP

**S**urface **T**hreat **R**econnaissance & **I**dentification **P**latform

A lightweight, containerized security reconnaissance platform for automated external attack surface discovery and vulnerability assessment.

![S.T.R.I.P. main image ](assets/STRIP.png)

---

This project exists to demonstrate what disciplined, repeatable discovery looks like when treated as a system rather than a collection of tools. It is intentionally opinionated, intentionally incomplete by design, and intentionally boring.

---
## Project Background

STRIP is an open-source reconnaissance platform developed by [Jonathan Risto](https://www.linkedin.com/in/jonathanristo) as part of security research at [ZenzizenSec Inc.](https://zenzizensec.com)

**Related frameworks:** [VMMM v2](https://zenzizensec.com/vmmm) | [CTEMMM](https://zenzizensec.com/ctemmm)

This project provides practical tooling that complements vulnerability and exposure management maturity assessment frameworks.

---
## Overview

STRIP automates the discovery and assessment of internet-facing assets through a coordinated pipeline of industry-standard open-source security tools. It's designed for security teams, penetration testers, and bug bounty hunters who need fast, reliable visibility into external attack surfaces.

### What STRIP Does

```
targets.txt (domains / IPs / CIDRs) → subdomain discovery → DNS resolution
            → [opt-in ASN seed expansion] → port scanning → web probing (+ favicon hash)
            → screenshots → crawling (sweep) → vulnerability + TLS scanning
            → subdomain-takeover + email-posture checks → normalized reports
```

**Key Capabilities:**
- 🔍 Automated subdomain enumeration
- 🌐 DNS resolution and validation
- 🎯 Domain, IP, and CIDR range targets
- 🛰️ Opt-in ASN → CIDR seed expansion (asnmap, scope-controlled)
- 🔓 Port and service discovery
- 🌍 HTTP/HTTPS service profiling
- 🧬 Favicon hashing (cross-host correlation anchor)
- 🕸️ Web crawling for surface expansion (weekly sweep)
- 📸 Screenshot capture / visual recon
- 🛡️ Template-based vulnerability scanning
- 🎭 Subdomain takeover detection (confirmed / potential)
- ✉️ Email/domain security posture (SPF/DMARC/DKIM/BIMI/MTA-STS/CAA)
- 🔒 TLS/SSL configuration assessment
- 📊 Structured outputs (NDJSON, CSV)

---

## Quick Start

### Prerequisites
- Docker & Docker Compose (v2)
- `yq` (YAML processor) - [Installation guide](https://github.com/mikefarah/yq)
- `jq` (JSON processor) - Usually pre-installed on Linux/macOS

**Platform notes:**
- **Linux** — runs natively; `network_mode: host` gives real host networking (best performance). Install `yq`/`jq` via your package manager.
- **macOS** — Docker Desktop; works out of the box. amd64-only tool images (gowitness) run under emulation on Apple Silicon (screenshots still work, just slower).
- **Windows** — run inside **WSL2** (Docker Desktop for Windows already uses it); clone and run `stripctl` from the WSL2 shell. Native PowerShell is not supported.


### Installation

```bash
# Clone the repository
git clone https://github.com/jonathanristo/strip.git
cd strip

# Create required directories
mkdir -p data/{in,out,.config,.cache}

# Add target domains (one per line)
cat > data/in/domains.txt <<EOF
example.com
test.com
EOF

# Run your first scan
./stripctl run daily
```
---

**Linux, macOS, and Windows (WSL2) users:** The default configuration works out of the box.

---
### First Run
```bash
# Daily scan (High/Critical findings only)
./stripctl run daily

# Results will be in:
./data/out/[timestamp]/
```

That's it. STRIP works out of the box.

---

## Usage

### Basic Commands

```bash
# Full daily workflow (recommended)
./stripctl run daily

# Full weekly workflow (deeper scanning)
./stripctl run weekly

# Individual phases
./stripctl setup                 # First-time Nuclei template setup (auto-checked on runs)
./stripctl discover              # Subdomain → DNS → port → HTTP discovery
./stripctl merge                 # Normalize outputs to NDJSON/CSV
```

### Configuration

Edit `strip.yaml` to customize:

```yaml
scan:
  naabu:
    top_ports: "1000"    # Number of ports to scan
    rate: 5000           # Packets per second
  httpx:
    rate_limit: 400      # Requests per second
  nuclei:
    severity_daily: "high,critical"
    severity_weekly: "medium,high,critical"
  katana:
    enable: true         # Web crawl during the weekly sweep (daily never crawls)
  tls:
    testssl: true        # TLS/SSL assessment of live HTTPS services
    sslyze: false        # Raw sidecar only — writes sslyze.json but is NOT normalized into the contract
  email:
    enable: true         # SPF/DMARC/DKIM/BIMI/MTA-STS/CAA posture (dnsx TXT/CAA; DNSSEC/DANE not covered)
  takeover:
    enable: true         # Subdomain takeover via nuclei takeover templates over CNAME'd hosts

seed_expansion:
  enable: false          # OPT-IN: expand scope to the org's ASN CIDRs (asnmap). Changes WHAT is scanned
  exclusions: []         # CIDRs excluded BEFORE scanning
  acknowledge_full_asn: false   # allow expansion with an empty exclusion list. asnmap needs PDCP_API_KEY

screenshots:
  enable: true           # Screenshot capture with gowitness
```

---

## Output Structure

```
data/out/20260709-143205/
│   # ── raw tool output ──
├── domains.txt              # Input targets (domains / IPs / CIDRs)
├── resolved.json            # DNS resolution incl. CNAME chains (dnsx -json)
├── email_txt.json           # SPF/DMARC/DKIM/BIMI/MTA-STS records (dnsx -txt)
├── email_caa.json           # CAA records (dnsx -caa)
├── asnmap.cidrs.txt         # ASN CIDRs (asnmap; opt-in seed expansion)
├── scan_targets.txt         # Combined port-scan targets
├── ports.naabu.txt          # Open ports (naabu)
├── nmap.xml / nmap6.xml     # Service fingerprints, IPv4 / IPv6 (nmap -sV -Pn on discovered ports; C2 import)
├── httpx.json               # HTTP probe details (incl. TLS grab + favicon hash)
├── nuclei.jsonl             # Raw vulnerability findings
├── takeover.jsonl           # Raw subdomain-takeover matches (nuclei takeover pass)
├── testssl.json             # Raw TLS assessment
├── screenshots/             # gowitness screenshots
│   # ── normalized output (stable NDJSON contract; one JSON object per line) ──
├── hosts.ndjson             # One record per observed IP
├── services.ndjson          # One record per (host, port, protocol) — naabu + nmap merged
├── web_assets.ndjson        # One record per HTTP(S) endpoint (incl. favicon_hash)
├── tls.ndjson               # One record per TLS certificate (SHA-256 fingerprint)
├── dns.ndjson               # One record per DNS observation (A/AAAA/CNAME/TXT/CAA)
├── findings.ndjson          # One record per finding (nuclei + testssl + email posture + takeover)
├── run_manifest.json        # Run provenance: operator, authorization, timings, counts, seed-expansion
└── *.csv                    # Lossy human-readable summaries (hosts, open_ports, web_assets, tls, findings)
```

---

## Tool Stack

STRIP leverages best-in-class open-source security tools:

| Phase | Tool | Purpose |
|-------|------|---------|
| **Discovery** | [subfinder](https://github.com/projectdiscovery/subfinder) | Subdomain enumeration (passive) |
| | [amass](https://github.com/owasp-amass/amass) | Subdomain enumeration (comprehensive) |
| | [dnsx](https://github.com/projectdiscovery/dnsx) | DNS resolution, validation & email-posture records |
| | [asnmap](https://github.com/projectdiscovery/asnmap) | ASN → CIDR seed expansion (opt-in; needs `PDCP_API_KEY`) |
| **Scanning** | [naabu](https://github.com/projectdiscovery/naabu) | Fast port scanning |
| | [nmap](https://nmap.org/) | Service fingerprinting (discovered ports, `-Pn`, IPv4 + IPv6) |
| | [httpx](https://github.com/projectdiscovery/httpx) | HTTP probing, tech detection & favicon hashing |
| **Assessment** | [nuclei](https://github.com/projectdiscovery/nuclei) | Vulnerability scanning + subdomain-takeover templates |
| | [testssl.sh](https://testssl.sh/) | TLS/SSL security assessment |
| **Recon** | [katana](https://github.com/projectdiscovery/katana) | Web crawling / surface expansion (weekly sweep) |
| | [gowitness](https://github.com/sensepost/gowitness) | Screenshot capture / visual recon |

---

## Advanced Configuration

### Improve Subdomain Discovery (Optional)

STRIP works without API keys, but adding free API keys significantly improves subdomain discovery results.

**Without keys:** ~40-60% coverage (passive sources only)  
**With keys:** ~90%+ coverage (10+ data sources)

#### Get Free API Keys (5 minutes)

1. **VirusTotal** (500 requests/day): https://www.virustotal.com/gui/sign-up
2. **Censys** (250 queries/month): https://censys.io/register  
3. **SecurityTrails** (50 queries/month): https://securitytrails.com/app/signup

#### Configure API Keys

```bash
# Create config file
mkdir -p data/.config/subfinder
cat > data/.config/subfinder/provider-config.yaml <<EOF
virustotal:
  - "YOUR_VIRUSTOTAL_API_KEY"
censys:
  - "YOUR_CENSYS_API_ID"
  - "YOUR_CENSYS_SECRET"
securitytrails:
  - "YOUR_SECURITYTRAILS_API_KEY"
EOF
```

See [docs/API_KEYS.md](docs/API_KEYS.md) for detailed setup instructions.

### Seed Expansion Key (Optional)

Opt-in ASN → CIDR seed expansion (`seed_expansion.enable: true`) uses **asnmap**, which needs a free
[ProjectDiscovery Cloud](https://cloud.projectdiscovery.io) key. Provide it via the environment (it is
passed through to the asnmap container):

```bash
export PDCP_API_KEY="your-pdcp-key"
```

Seed expansion **refuses to run without an exclusion list** unless you also set
`seed_expansion.acknowledge_full_asn: true` — it changes *what* gets scanned, so scope control is a
prerequisite, not an option. Exclusions are enforced by **CIDR containment** (a broad exclusion such as
`10.0.0.0/8` also drops the child ranges asnmap returns), which needs `python3` on the host; if `python3`
is absent while exclusions are set, expansion refuses rather than under-enforce the guardrail.

---

## Use Cases

### Continuous Attack Surface Monitoring
```bash
# Daily cron job
0 2 * * * /opt/strip/stripctl run daily

# Weekly deep scan
0 3 * * 0 /opt/strip/stripctl run weekly
```

### Pre-Engagement Reconnaissance
```bash
# Gather intelligence before penetration test
./stripctl run daily
# Review findings in data/out/[timestamp]/findings_summary.csv
```

### Bug Bounty Hunting
```bash
# Monitor multiple programs
cat >> data/in/domains.txt <<EOF
bugcrowd-target.com
hackerone-target.com
EOF

./stripctl run daily
```

### Red Team Operations
```bash
# Comprehensive enumeration
./stripctl run weekly
# Import data/out/[timestamp]/nmap.xml into your C2
```

---

## Workflow Details

### Daily Scan (`stripctl run daily`) — Phase 1

1. **discover** — subdomain enumeration → DNS resolution (+ CNAME) → naabu port scan → nmap `-sV -Pn` on the **discovered** ports (IPv4 + IPv6) → httpx probing (incl. favicon)
2. **web-scan** — Nuclei (high/critical) against the **httpx-validated** live URLs (not the raw port cross-product)
3. **tls** — testssl.sh assessment of live HTTPS services
4. **shots** — Screenshot capture (gowitness)
5. **email** — SPF/DMARC/DKIM/BIMI/MTA-STS/CAA posture (records → `dns.ndjson`, gaps → `findings.ndjson`)
6. **takeover** — Subdomain-takeover detection over CNAME'd hosts (confirmed / potential)
7. **merge** — Normalize all outputs to NDJSON/CSV

> **Opt-in seed expansion:** with `seed_expansion.enable`, asnmap expands scope to the org's ASN CIDRs before scanning — scope-controlled (refuses without an exclusion list unless `acknowledge_full_asn`) and needs `PDCP_API_KEY`.

**Duration:** ~10-30 minutes (depending on target size)

### Weekly Scan (`stripctl run weekly`) — Phase 1 + Sweep

Everything in the daily scan, plus a deeper **sweep**:
- Amass (comprehensive subdomain discovery, unioned into one scan)
- Katana (web crawling → expands the validated URL set Nuclei tests)
- Nuclei (medium/high/critical severity)

**Duration:** ~30-90 minutes

---

## Data Formats

### NDJSON (Newline-Delimited JSON)
Machine-readable, easy to parse and query:

```bash
# Critical findings
jq 'select(.severity=="critical")' data/out/*/findings.ndjson

# Findings that carry a CVE
jq 'select(.cve_id != null) | {cve_id, severity, url}' data/out/*/findings.ndjson

# Subdomain takeovers (confirmed or potential)
jq 'select(.category=="takeover") | {host: .hostname_at_observation_time, state, severity}' data/out/*/findings.ndjson

# Email-security gaps (missing SPF/DMARC/MTA-STS/CAA, DMARC p=none)
jq 'select(.category=="email_security") | {host: .hostname_at_observation_time, .template_id}' data/out/*/findings.ndjson

# Web assets running a given technology (tech is an array of objects)
jq 'select(.tech[]?.name | ascii_downcase | test("wordpress"))' data/out/*/web_assets.ndjson

# Favicon hashes (cross-host correlation anchor)
jq -r 'select(.favicon_hash != null) | [.hostname_at_observation_time // .ip_at_observation_time, .favicon_hash] | @tsv' data/out/*/web_assets.ndjson

# TLS certificate fingerprints (cross-host correlation anchor)
jq -r '[.hostname_at_observation_time // .ip_at_observation_time, .fingerprint_sha256] | @tsv' data/out/*/tls.ndjson

# Count findings by severity
jq -r '.severity' data/out/*/findings.ndjson | sort | uniq -c
```

Every record is self-describing (`source_module`, `source_tool`, `scan_id`, `observed_at`) and
immutable. An empty stream is written as a single sentinel line (a record with a `message` key) —
skip those when parsing.

### CSV
Lossy human summaries (NDJSON is the authoritative format):

```
hosts.csv            - Live hosts
open_ports.csv       - Services (host, port, service, product, version)
web_assets.csv       - Web endpoints
tls.csv              - Certificates
findings_summary.csv - Findings
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       stripctl (Bash)                        │
│               Orchestration & Workflow Engine                │
└─────────────────────────────────────────────────────────────┘
                            │
       ┌───────────┬────────┼────────┬────────────┐
       │           │        │        │            │
  ┌────▼─────┐ ┌───▼────┐ ┌─▼──────┐ ┌▼──────────┐
  │subfinder │ │  dnsx  │ │ naabu  │ │  asnmap   │
  │  amass   │ │(resolve│ │  nmap  │ │ ASN→CIDR  │
  │          │ │+email) │ │        │ │ (opt-in)  │
  └────┬─────┘ └───┬────┘ └───┬────┘ └───────────┘
       │           │          │
       └───────────┴────┬─────┘
                        │
                ┌───────▼────────┐
                │     httpx      │
                │ (probe + favi) │
                └───────┬────────┘
                        │
        ┌───────────┬───┴───┬────────────┐
        │           │       │            │
   ┌────▼────┐ ┌────▼────┐ ┌▼───────┐ ┌──▼─────────┐
   │ nuclei  │ │ testssl │ │ katana │ │ gowitness  │
   │ (vulns) │ │  (TLS)  │ │(crawl) │ │ (screens)  │
   └────┬────┘ └────┬────┘ └───┬────┘ └──────┬─────┘
        │           │          │             │
        └───────────┴─────┬────┴─────────────┘
                          │
                  ┌───────▼────────┐
                  │     merge      │
                  │  NDJSON + CSV  │
                  └────────────────┘
```

> Phase 1 (`run daily`) flows discovery → httpx → nuclei → testssl → gowitness → **email posture** →
> **takeover** → merge. **asnmap** seed expansion is opt-in and feeds scan scope before naabu. The weekly
> sweep (`run weekly`) adds **amass** and **katana** (crawl → expands the validated URL set nuclei tests).

**Design Principles:**
- **Containerized** - Every tool runs in isolation
- **Stateless** - No persistent services (except OpenVAS if added later)
- **Timestamped** - Each run creates a new output directory
- **Fail-safe** - Individual tool failures don't crash the pipeline
- **Modular** - Run phases independently or as a complete workflow

---

## Comparison to Alternatives

| Feature | STRIP | Recon-ng | Amass Alone | Metasploit | Commercial Tools |
|---------|-------|----------|-------------|------------|------------------|
| **Setup Time** | < 5 min | ~15 min | < 5 min | ~30 min | Hours/Days |
| **Infrastructure** | Docker only | Python deps | Go binary | Complex | Cloud/VM |
| **Cost** | Free | Free | Free | Free | $$$$ |
| **Automation** | Full | Manual/scripted | Partial | Partial | Full |
| **Vulnerability Scanning** | ✓ (Nuclei) | ✗ | ✗ | ✓ | ✓ |
| **Visual Recon** | ✓ | ✗ | ✗ | ✗ | ✓ |
| **Domain / IP / CIDR input** | ✓ | Partial | Partial | ✓ | ✓ |
| **Learning Curve** | Low | Medium | Low | High | Medium |

---

## Troubleshooting

### "Permission denied" errors
```bash
# Fix Docker socket permissions
sudo usermod -aG docker $USER
# Log out and back in
```

### Port scanning not working
```bash
# Requires elevated privileges
# Option 1: Run stripctl with sudo
sudo ./stripctl run daily

# Option 2: Grant CAP_NET_RAW
sudo setcap cap_net_raw+ep /usr/bin/docker
```

### No subdomains found
```bash
# Check if domains.txt is formatted correctly (one domain per line)
cat data/in/domains.txt

# Run subfinder manually to debug
docker compose run --rm subfinder -d example.com -all
```

### "yq: command not found"
```bash
# Install yq
# macOS
brew install yq

# Linux
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq
```
### Gowitness is slow on Apple Silicon

The gowitness image is amd64-only, so on Apple Silicon (M-series) it runs under emulation —
handled automatically by the `platform: linux/amd64` pin in `docker-compose.yml`. Screenshots
still work, just slower. On amd64 Linux/Windows it runs natively.

---

## Roadmap

- [ ] OpenVAS/Greenbone integration (full vulnerability management)
- [ ] Web UI for viewing results
- [ ] Slack/email notifications
- [ ] Differential scanning (track changes over time)
- [ ] Report generation (PDF/HTML)
- [ ] API for integration with ticketing systems
- [ ] Support for authenticated scanning
- [ ] Kubernetes deployment option

---

## Testing

STRIP ships a layered regression suite under [`tests/`](tests/) — plain `bash` plus the tools STRIP
already needs (`jq`, `docker`); no extra framework to install. Run it under **bash** (the suite sources
`stripctl`, which relies on bash features `BASH_REMATCH`/arrays):

```bash
tests/run.sh                      # static + parsers + golden merge + tool contracts
tests/run.sh parsers              # a single layer, by name filter
STRIP_INTEGRATION=1 tests/run.sh  # also run the opt-in network integration layer
```

| Layer | Needs | Proves |
|-------|-------|--------|
| **Static** | — (docker/shellcheck optional) | `bash -n`, `docker compose config`, every tool invoked maps to a real compose service |
| **Parsers** | — | host:port parsing (IPv4 / IPv6 / bracketed), URL building, resolver cleanup, nmap family split, nuclei target selection, run-dir selection |
| **Golden merge** | docker (nmap fixture only) | real `merge` output vs a locked baseline for all six streams + `run_manifest.json`, across IPv4 / IPv6-literal / dual-stack / empty-run fixtures |
| **Contracts** | docker | the current tool images accept the exact flags STRIP passes them |
| **Integration** | docker + network, opt-in | live dnsx custom-resolver resolve + error capture |

After an intentional change to `merge`, refresh the golden baseline with `tests/regen_golden.sh` and
review the diff. See [`tests/README.md`](tests/README.md) for fixture details.

---

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

**Before submitting**, please verify:

- `bash -n stripctl` parses clean and `docker compose config -q` validates.
- `merge` output still conforms to **`sensor-output/1.0`** — the six NDJSON streams plus
  `run_manifest.json`, `null` (not `""`) for absent scalars, one `services` row per host/port/protocol.
- Parsing changes preserve behavior across IPv4, IPv6 (literal **and** bracketed), and hostname targets.

Then run the regression suite — `tests/run.sh` (see [Testing](#testing) above).

**Areas where we'd love help:**
- Additional tool integrations
- Report generation templates
- Documentation improvements
- Bug fixes and performance optimization

---

## Security Considerations

### Responsible Use
- **Legal**: Only scan assets you own or have explicit permission to test
- **Ethical**: Follow responsible disclosure practices
- **Rate Limiting**: Be respectful of target infrastructure
- **Data Handling**: Outputs may contain sensitive information - handle appropriately

### Operational Security
- Store credentials securely (use `.gitignore` for `data/creds/`)
- Rotate API keys regularly
- Review findings before sharing with third parties
- Consider using a VPN or dedicated scanning infrastructure

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Acknowledgments

STRIP stands on the shoulders of giants. Huge thanks to:

- [ProjectDiscovery](https://github.com/projectdiscovery) - subfinder, nuclei, httpx, naabu, dnsx, katana
- [OWASP Amass](https://github.com/owasp-amass/amass) - Comprehensive subdomain discovery
- [testssl.sh](https://github.com/drwetter/testssl.sh) - TLS/SSL testing
- [gowitness](https://github.com/sensepost/gowitness) - Screenshot capture

And the entire open-source security community.

---

## Support

* **Issues**: [GitHub Issues](https://github.com/jonathanristo/strip/issues)
* **Discussions**: [GitHub Discussions](https://github.com/jonathanristo/strip/discussions)
* **Documentation**: [Wiki](https://github.com/jonathanristo/strip/wiki)

---

**Maintained by:** [Jonathan Risto](https://www.linkedin.com/in/jonathanristo) | [ZenzizenSec Inc.](https://zenzizensec.com)

---

**Built for the security community**

