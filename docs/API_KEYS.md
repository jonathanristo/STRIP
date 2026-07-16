# API Keys Setup

STRIP works out of the box **without any API keys**, using passive sources that don't
require authentication. Adding free API keys significantly expands subdomain discovery
coverage.

| Configuration | Approx. coverage | Sources |
|---------------|------------------|---------|
| No keys       | ~40–60%          | Passive, unauthenticated only |
| Free keys     | ~90%+            | 10+ authenticated data sources |

Keys are consumed by **[subfinder](https://github.com/projectdiscovery/subfinder)** during
the `discover` phase. They are read from a provider config file that is **git-ignored**, so
your real keys never get committed.

---

## Where keys live

```
data/.config/subfinder/provider-config.yaml
```

This path is mounted into the subfinder container via `XDG_CONFIG_HOME=/data/.config`
(see `docker-compose.yml`). A template ships in the repo:

```
data/.config/subfinder/provider-config.yaml.example
```

Create your real config by copying the example:

```bash
mkdir -p data/.config/subfinder
cp data/.config/subfinder/provider-config.yaml.example \
   data/.config/subfinder/provider-config.yaml
```

> **Security:** `provider-config.yaml` (the real one) is listed in `.gitignore`, while
> `provider-config.yaml.example` is explicitly kept. Never put real keys in the `.example`
> file. See the `# Subfinder API keys` block in [`.gitignore`](../.gitignore).

---

## File format

Each provider is a YAML key whose value is a **list of keys**. Empty list = provider
disabled. Fill in only the ones you have:

```yaml
virustotal:
  - "YOUR_VIRUSTOTAL_API_KEY"
securitytrails:
  - "YOUR_SECURITYTRAILS_API_KEY"
shodan:
  - "YOUR_SHODAN_API_KEY"
```

### Providers that need two values

Some sources (e.g. **censys**) require an ID **and** a secret. subfinder expects these as a
single `id:secret` entry:

```yaml
censys:
  - "YOUR_CENSYS_API_ID:YOUR_CENSYS_SECRET"
```

> ⚠️ Format note: older subfinder versions accepted the two values as separate list items.
> Current subfinder expects the colon-joined `id:secret` form shown above. If a provider
> silently returns nothing, verify the format against
> [subfinder's provider-config docs](https://github.com/projectdiscovery/subfinder#post-installation-instructions).

You can supply **multiple keys per provider** to spread out rate limits — subfinder rotates
through them:

```yaml
virustotal:
  - "KEY_ONE"
  - "KEY_TWO"
```

---

## Recommended free keys (5 minutes)

These three give the best coverage-per-effort and have free tiers:

| Provider | Free tier | Sign up |
|----------|-----------|---------|
| **VirusTotal** | 500 requests/day | https://www.virustotal.com/gui/sign-up |
| **Censys** | 250 queries/month | https://censys.io/register |
| **SecurityTrails** | 50 queries/month | https://securitytrails.com/app/signup |

Example combined config:

```yaml
virustotal:
  - "vt_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
censys:
  - "censys_id_xxxx:censys_secret_xxxx"
securitytrails:
  - "st_xxxxxxxxxxxxxxxxxxxx"
```

---

## All supported providers

subfinder supports every provider listed in the shipped
[`provider-config.yaml.example`](../data/.config/subfinder/provider-config.yaml.example).
Many have free tiers worth adding:

```
bevigil      bufferover   builtwith    c99          censys
certspotter  chaos        chinaz       digitalyama  dnsdb
dnsdumpster  dnsrepo      facebook     fofa         fullhunt
github       hunter       intelx       leakix       netlas
pugrecon     quake        redhuntlabs  robtex       rsecloud
securitytrails  shodan    threatbook   virustotal   whoisxmlapi
zoomeyeapi
```

For per-provider signup links and current rate limits, see
[subfinder's source list](https://github.com/projectdiscovery/subfinder#sources).

---

## ProjectDiscovery Cloud key — asnmap / seed expansion (optional)

The **opt-in** ASN → CIDR seed-expansion feature (`seed_expansion.enable: true` in `strip.yaml`) uses
**[asnmap](https://github.com/projectdiscovery/asnmap)**, which requires a free
[ProjectDiscovery Cloud](https://cloud.projectdiscovery.io) (PDCP) API key. Unlike the subfinder
provider keys above, asnmap reads its key from an **environment variable**, not the provider-config file:

```bash
export PDCP_API_KEY="your-pdcp-key"
./stripctl run daily
```

`docker-compose.yml` passes `PDCP_API_KEY` through to the asnmap container. It is the same *class* of key
as the subfinder ones — a read-only credential to a public data provider, not access to a target — so it
is allowed on the sensor but must never be committed.

Without the key, asnmap exits immediately (STRIP feeds it `</dev/null`, so it does not hang), seed
expansion logs a clear message, and the rest of the scan proceeds normally.

> Seed expansion changes **what** gets scanned, so it is guarded: it refuses to expand without a
> `seed_expansion.exclusions` list (unless `acknowledge_full_asn: true`), and enforces exclusions by CIDR
> containment via `python3`. See the *Seed Expansion Key* section of the README.

---

## Verify your keys work

Run subfinder directly against a known domain and confirm authenticated sources fire:

```bash
# -v prints which sources returned results
docker compose run --rm subfinder -d example.com -all -v
```

If a provider's key is invalid, subfinder logs a warning for that source and continues —
it never aborts the run. So a bad key degrades coverage silently; check the `-v` output
to confirm each source is actually returning data.

---

## Troubleshooting

**No subdomains from an authenticated source**
- Confirm the key is in `provider-config.yaml`, **not** the `.example` file.
- Re-check the format — especially `id:secret` for two-value providers like censys.
- Some free tiers are monthly-capped; you may have exhausted the quota.

**"provider config not found"**
- Ensure the file is at `data/.config/subfinder/provider-config.yaml` (note the leading
  dot in `.config`), since the container reads `XDG_CONFIG_HOME=/data/.config`.

**Keys accidentally staged for commit**
```bash
git status --porcelain data/.config/subfinder/provider-config.yaml
# should print NOTHING — the real file is git-ignored.
```
