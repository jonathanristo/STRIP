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
            → port scanning → web probing → screenshots → crawling (sweep)
            → vulnerability + TLS scanning → normalized reports
```

**Key Capabilities:**
- 🔍 Automated subdomain enumeration
- 🌐 DNS resolution and validation
- 🎯 Domain, IP, and CIDR range targets
- 🔓 Port and service discovery
- 🌍 HTTP/HTTPS service profiling
- 🕸️ Web crawling for surface expansion (weekly sweep)
- 📸 Screenshot capture / visual recon
- 🛡️ Template-based vulnerability scanning
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
  nuclei:
    severity_daily: "high,critical"
    severity_weekly: "medium,high,critical"
  katana:
    enable: true         # Web crawl during the weekly sweep (daily never crawls)
  tls:
    testssl: true        # TLS/SSL assessment of live HTTPS services

screenshots:
  enable: true           # Screenshot capture with gowitness
```

---

## Output Structure

```
data/out/20260125-143022/
├── domains.txt              # Input targets (domains / IPs / CIDRs)
├── subs.txt                 # Discovered subdomains (+ apex; + amass on weekly)
├── resolved.txt             # DNS resolution results
├── scan_targets.txt         # Combined port-scan targets (resolved hosts + IPs + CIDRs)
├── ports.naabu.txt          # Open ports (host:port)
├── nmap.xml                 # Service fingerprints (XML — parsed by merge; also for C2 import)
├── httpx.json               # HTTP service details
├── urls.txt                 # Probed URLs (port-accurate; expanded by katana on weekly)
├── screenshots/             # gowitness screenshots
├── gowitness.jsonl          # Screenshot manifest (url → image file)
├── katana.txt               # Crawled URLs (weekly sweep)
├── nuclei.jsonl             # Vulnerability findings
├── testssl.json             # TLS/SSL assessment
├── web_assets.ndjson        # Normalized web assets (incl. screenshot path)
├── web_assets.csv           # CSV export
├── findings.ndjson          # Normalized vulnerability findings
└── findings_summary.csv     # CSV export
```

---

## Tool Stack

STRIP leverages best-in-class open-source security tools:

| Phase | Tool | Purpose |
|-------|------|---------|
| **Discovery** | [subfinder](https://github.com/projectdiscovery/subfinder) | Subdomain enumeration (passive) |
| | [amass](https://github.com/owasp-amass/amass) | Subdomain enumeration (comprehensive) |
| | [dnsx](https://github.com/projectdiscovery/dnsx) | DNS resolution & validation |
| **Scanning** | [naabu](https://github.com/projectdiscovery/naabu) | Fast port scanning |
| | [nmap](https://nmap.org/) | Service fingerprinting |
| | [httpx](https://github.com/projectdiscovery/httpx) | HTTP probing & tech detection |
| **Assessment** | [nuclei](https://github.com/projectdiscovery/nuclei) | Vulnerability scanning (templates) |
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

1. **discover** - Subdomain enumeration → DNS resolution → port scanning → HTTP probing
2. **web-scan** - Nuclei templates (high/critical severity)
3. **tls** - testssl.sh assessment of live HTTPS services
4. **shots** - Screenshot capture (gowitness)
5. **merge** - Normalize all outputs to NDJSON/CSV

**Duration:** ~10-30 minutes (depending on target size)

### Weekly Scan (`stripctl run weekly`) — Phase 1 + Sweep

Everything in the daily scan, plus a deeper **sweep**:
- Amass (comprehensive subdomain discovery, unioned into one scan)
- Katana (web crawling → expands the URL surface Nuclei tests)
- Nuclei (medium/high/critical severity)

**Duration:** ~30-90 minutes

---

## Data Formats

### NDJSON (Newline-Delimited JSON)
Machine-readable, easy to parse and query:

```bash
# Find all critical vulnerabilities
jq 'select(.severity=="critical")' data/out/*/findings.ndjson

# List all web assets running WordPress
jq 'select(.tech[]=="wordpress")' data/out/*/web_assets.ndjson

# Count findings by severity
jq -r '.severity' data/out/*/findings.ndjson | sort | uniq -c
```

### CSV
Import into Excel, Google Sheets, or reporting tools:

```
findings_summary.csv    - Vulnerability summary
web_assets.csv          - Web services inventory
open_ports.csv          - Port scan results
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      stripctl (Bash)                        │
│              Orchestration & Workflow Engine                │
└─────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┼───────────┐
                │           │           │
        ┌───────▼──┐   ┌────▼────┐  ┌──▼──────┐
        │subfinder │   │  dnsx   │  │ naabu   │
        │  amass   │   │         │  │  nmap   │
        └───────┬──┘   └────┬────┘  └──┬──────┘
                │           │           │
                └───────────┼───────────┘
                            │
                    ┌───────▼────────┐
                    │     httpx      │
                    │   (probing)    │
                    └───────┬────────┘
                            │
                ┌───────────┼
                │           │      
        ┌───────▼──┐   ┌────▼────┐ 
        │  nuclei  │   │testssl  │ 
        └───────┬──┘   └────┬────┘ 
                │           │
                └───────────┼
                            │
                    ┌───────▼────────┐
                    │     merge      │
                    │  NDJSON + CSV  │
                    └────────────────┘
```

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

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

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

