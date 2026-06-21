# Technology Stack

_Generated: 2026-06-21_

## Summary

`kubectl-mns` is a single-file Bash shell script with no build system, no package manager, and no compiled artifacts. Its only runtime dependency is `kubectl` being present in the system PATH. CI is handled by GitHub Actions with Codacy providing static analysis and security scanning.

## Languages & Runtime

**Primary:**
- Bash — entire implementation lives in `/kubectl-mns` (68 lines)
  - Shebang: `#!/usr/bin/env bash` (portable; resolves bash from PATH, not hardcoded to `/bin/bash`)
  - Shell options: `set -eo pipefail` (exit on error, treat pipe failures as errors)
  - Uses bash arrays (`namespaces=()`, `actual_kubectl_args=()`), `[[ ]]` double-bracket conditionals, and `echo -e` for escape sequences — requires **Bash 3.2+** (compatible with macOS default bash)

**No secondary languages.** No Python, Go, or other scripting involved.

## External Tool Dependencies

| Tool | Required? | Purpose |
|------|-----------|---------|
| `kubectl` | **Yes — hard runtime dependency** | Executes all Kubernetes commands; must be on `$PATH` |
| `bash` | **Yes** | Script interpreter; resolved via `env bash` |

No other CLI tools are invoked. No `jq`, `curl`, `awk`, `sed`, or similar utilities used in the script body.

## Installation Mechanism

No package manager, no installer script, no Makefile. Installation is fully manual:

1. Download raw script from GitHub: `https://raw.githubusercontent.com/wasilak/kubectl-mns/main/kubectl-mns`
2. `chmod +x kubectl-mns`
3. Move to a directory in `$PATH` (e.g., `/usr/local/bin/`)

kubectl plugin discovery relies on the `kubectl-<name>` binary naming convention — no registration or manifest file needed.

## Build System

**None.** No Makefile, no build scripts, no compilation step. The script is deployed as-is.

## CI/CD Tooling

**GitHub Actions** (`.github/workflows/`)

| Workflow | File | Trigger |
|----------|------|---------|
| Codacy Security Scan | `.github/workflows/codacy.yml` | push/PR to `main`, weekly cron (Wed 13:44 UTC) |
| Close Inactive Issues | `.github/workflows/stale.yml` | daily cron (01:30 UTC) |

**Actions used:**
- `actions/checkout@v7` — repository checkout
- `codacy/codacy-analysis-cli-action@master` — static analysis + security scan, outputs SARIF
- `github/codeql-action/upload-sarif@v3` — uploads SARIF results to GitHub Advanced Security
- `actions/stale@v9` — stale issue/PR management

## Dependency Management

**Renovate** (`renovate.json`) manages GitHub Actions action version updates:
- Extends `config:recommended`
- `automerge: true` for dependency PRs
- `separateMajorMinor: true`
- Has a `gomod` package rule (likely a copy-paste artifact — no Go code exists in this repo)
- Labels applied: `renovate::dependencies`, plus dynamic labels for category, updateType, datasource, manager, and vulnerability severity

## Static Analysis / Security

- **Codacy** — cloud-based static analysis service; badge present in `README.md`
  - Project URL: `https://app.codacy.com/gh/wasilak/kubectl-mns/dashboard`
  - Runs on every push/PR to `main` and on a weekly schedule
  - Results uploaded to GitHub Advanced Security as SARIF
  - `max-allowed-issues: 2147483647` — configured to never block PRs on issue count (GitHub side controls rejection)

## Gaps & Unknowns

- No `shellcheck` integration detected in CI (Codacy may run it internally as one of its tools, but it is not explicitly configured)
- The `gomod` package rule in `renovate.json` has no corresponding Go code — likely a copy-paste from another project template
- No versioning scheme or release tagging mechanism found (no `CHANGELOG`, no release workflow, no `VERSION` file)
- No test suite of any kind (unit tests, integration tests, or bats/shellspec tests)
- Codacy project token is commented out in the workflow — relies on Codacy's default configuration detection
