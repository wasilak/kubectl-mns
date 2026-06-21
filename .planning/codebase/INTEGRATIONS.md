# External Integrations

_Generated: 2026-06-21_

## Summary

`kubectl-mns` integrates with exactly one runtime system — `kubectl` — via the kubectl plugin naming convention. All other integrations are CI/CD services (GitHub Actions, Codacy, Renovate) that operate on the repository itself, not on the plugin's runtime behavior.

## kubectl Plugin Integration

**Mechanism:** kubectl discovers plugins by scanning `$PATH` for executables named `kubectl-<plugin-name>`. Placing `kubectl-mns` in any `$PATH` directory makes it available as `kubectl mns`.

**No manifest or registration required.** This is the standard kubectl plugin mechanism (documented at https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/).

**Runtime invocation pattern:**
```
kubectl mns <ns1> [ns2 ...nsN] -- <kubectl-subcommand> [args...]
```

kubectl itself is then called internally by the plugin:
```bash
kubectl_command="kubectl $command_arg --namespace $ns"
data=$($kubectl_command)
```

The plugin shells out to `kubectl` synchronously for each namespace in sequence (not parallel). Output is printed only when non-empty, separated by a blank line between namespaces.

**Filtering behavior:** The `--all-namespaces` flag is explicitly stripped from the forwarded kubectl args (line 30 of `kubectl-mns`) to prevent conflicting namespace targeting.

**kubectl version requirements:** None specified. The plugin passes arguments directly to `kubectl` with no version detection or compatibility checks.

## GitHub Actions

**Repository:** `https://github.com/wasilak/kubectl-mns`

### Codacy Security Scan (`.github/workflows/codacy.yml`)

- **Trigger:** Push or PR to `main`; weekly schedule (Wednesday 13:44 UTC)
- **Runner:** `ubuntu-latest`
- **What it does:**
  1. Checks out code with `actions/checkout@v7`
  2. Runs `codacy/codacy-analysis-cli-action@master` — performs static analysis and security scanning, emits `results.sarif`
  3. Uploads SARIF to GitHub Advanced Security via `github/codeql-action/upload-sarif@v3`
- **Permissions required:** `contents: read`, `security-events: write`, `actions: read`
- **PR blocking:** Disabled at the Codacy level (`max-allowed-issues: 2147483647`). GitHub Advanced Security controls any actual gating.

### Stale Issue/PR Management (`.github/workflows/stale.yml`)

- **Trigger:** Daily cron at 01:30 UTC
- **Runner:** `ubuntu-latest`
- **What it does:** Uses `actions/stale@v9` to automatically label and close inactive issues and PRs
  - Issues: stale after 30 days, closed after 14 more days
  - PRs: stale after 60 days, closed after 14 more days
- **Permissions required:** `issues: write`, `pull-requests: write`
- **Auth:** Uses `${{ secrets.GITHUB_TOKEN }}` (automatic, no additional secrets needed)

## Renovate (Dependency Automation)

**Config:** `renovate.json` at repo root

**What Renovate manages:** GitHub Actions action versions (e.g., `actions/checkout`, `actions/stale`, `codacy/codacy-analysis-cli-action`, `github/codeql-action`)

**Behavior:**
- `automerge: true` — dependency update PRs are merged automatically without human approval
- `separateMajorMinor: true` — major version bumps get separate PRs from minor/patch bumps
- `pinDigests: false` — action versions are NOT pinned to commit SHAs (uses version tags only)
- Labels applied to PRs: `renovate::dependencies` plus dynamic labels for update type, datasource, manager, and vulnerability severity

**Note:** A `gomod` package rule is configured but has no effect — there is no Go code in this repository.

## Codacy (External Code Quality Service)

- **Service URL:** `https://app.codacy.com/gh/wasilak/kubectl-mns/dashboard`
- **Integration point:** GitHub Actions workflow (`codacy.yml`)
- **Auth:** No project token configured (uses Codacy's default/auto-detection mode — project token line is commented out)
- **Output:** SARIF file uploaded to GitHub Advanced Security; grade badge displayed in `README.md`

## Kubernetes Cluster

The plugin itself is not integrated with any specific cluster — it delegates entirely to the user's local `kubectl` configuration (kubeconfig). No cluster-specific URLs, credentials, or API endpoints are embedded in the plugin.

## No Other External Services

The following are explicitly **not present**:
- No Helm chart or Krew index registration
- No Docker image or container registry
- No artifact storage (GitHub Releases, S3, etc.)
- No telemetry, metrics, or logging services
- No webhook endpoints (incoming or outgoing)
- No authentication providers
- No secrets beyond `GITHUB_TOKEN` (auto-provided by GitHub Actions)

## Gaps & Unknowns

- The plugin is not registered with the [Krew plugin index](https://krew.sigs.k8s.io/) — discovery is entirely manual (download + PATH placement)
- No release automation exists; there is no mechanism to cut versioned releases or publish artifacts
- Codacy analysis runs without an explicit project token — if Codacy's auto-detection changes behavior, the scan could silently degrade
- `codacy/codacy-analysis-cli-action@master` pins to a moving `master` branch ref rather than a fixed tag/SHA, which is a supply chain risk
