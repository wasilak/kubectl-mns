---
phase: 02-features
reviewed: 2026-06-22T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - .github/workflows/codacy.yml
  - README.md
  - kubectl-mns
findings:
  critical: 2
  warning: 4
  info: 2
  total: 8
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-06-22
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Three files were reviewed: the main bash plugin script (`kubectl-mns`), the GitHub Actions workflow (`.github/workflows/codacy.yml`), and the `README.md` documentation. The bash script is generally well-written — it uses array-based command construction (no word-splitting injection risk), guards against `set -e` interaction in the kubectl loop, and handles the common case correctly. However, two blockers were found: a non-existent `actions/checkout` version that will break CI entirely, and a logic gap in flag parsing that silently misroutes `--context=value` / `--kubeconfig=value` into namespace names. Additionally, the script exits `0` even when all namespace calls fail, which breaks any caller relying on exit code for automation.

---

## Critical Issues

### CR-01: `actions/checkout@v7` does not exist — CI will fail at runtime

**File:** `.github/workflows/codacy.yml:39`
**Issue:** `actions/checkout@v7` is referenced, but as of August 2025 the latest stable version is `v4`. Version `v7` does not exist in the `actions/checkout` repository. GitHub Actions will fail to resolve the action and the entire Codacy scan job will error at the checkout step, meaning no security scanning runs at all.
**Fix:**
```yaml
- name: Checkout code
  uses: actions/checkout@v4
```
Or pin to a specific commit SHA for supply-chain security:
```yaml
- name: Checkout code
  uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

---

### CR-02: `--context=value` / `--kubeconfig=value` (equals-sign form) silently treated as namespace names

**File:** `kubectl-mns:36-41`
**Issue:** The pre-`--` flag parser only handles the space-separated form (`--context my-ctx`), using a `consume_next_as` state machine. If the user passes the common equals-sign form (`--context=my-ctx`), the case statement falls through to the `*)` branch at line 41 and appends the entire `--context=my-ctx` string to `namespaces[]`. This causes kubectl to be invoked with `--namespace "--context=my-ctx"` for each namespace in the list — a silent wrong-behavior failure with no diagnostic.

Example triggering the bug:
```sh
kubectl mns --context=my-ctx ns1 -- get pods
# kubectl gets called with: kubectl --namespace "--context=my-ctx" get pods --namespace ns1
# instead of:              kubectl --context=my-ctx get pods --namespace ns1
```
**Fix:** Extend the case statement to handle the `=`-delimited form:
```bash
case "$item" in
  --context|--kubeconfig)
    consume_next_as="$item"
    ;;
  --context=*|--kubeconfig=*)
    extra_kubectl_flags+=("$item")
    ;;
  *)
    namespaces+=("$item")
    ;;
esac
```

---

## Warnings

### WR-01: Script exits `0` even when all namespace kubectl calls fail

**File:** `kubectl-mns:67-70`
**Issue:** When `kubectl` fails for a namespace, the error is printed and the loop continues via `continue`. If every namespace fails, the script still exits with code `0` (no explicit non-zero exit, and `set -eo pipefail` does not apply because the `if !` construct suppresses `-e`). Any automation or CI step that runs `kubectl mns` and checks `$?` will see success even on total failure.
**Fix:** Track whether any namespace failed and exit non-zero at the end:
```bash
any_failed=0
for ns in "${namespaces[@]}"; do
  local kubectl_cmd=(...)
  if ! data=$("${kubectl_cmd[@]}"); then
    printf 'Error: kubectl failed for namespace %s\n' "$ns" >&2
    any_failed=1
    continue
  fi
  ...
done
return $any_failed
```

---

### WR-02: `set -u` (nounset) missing — unbound variable errors are silently ignored

**File:** `kubectl-mns:3`
**Issue:** The script uses `set -eo pipefail` but omits `set -u`. An unbound variable reference (e.g., a typo in a variable name) will expand to an empty string rather than triggering an error. For a plugin that constructs and executes kubectl commands, a typo in `extra_kubectl_flags` or `actual_kubectl_args` would silently produce a malformed command.
**Fix:**
```bash
set -euo pipefail
```

---

### WR-03: `max-allowed-issues: 2147483647` disables Codacy exit-code blocking entirely

**File:** `.github/workflows/codacy.yml:55`
**Issue:** Setting `max-allowed-issues` to `INT_MAX` means the Codacy CLI action never fails regardless of how many issues are found. While the comment explains this defers control to GitHub's SARIF-based code scanning, in practice SARIF results in GitHub Advanced Security are advisory unless branch protection rules are explicitly configured to block on code scanning alerts. This creates a scenario where Codacy runs but never blocks a merge on its own. At minimum this should be documented as a conscious decision; at most, a lower threshold should be set.
**Fix:** Either set a meaningful threshold or add a comment referencing the branch protection rule that enforces the SARIF results:
```yaml
# Branch protection rule "Code scanning results / Codacy" must be enabled
# to block PRs when SARIF results contain issues.
max-allowed-issues: 2147483647
```
Or enforce at the action level for high-severity findings:
```yaml
max-allowed-issues: 0  # Fail on any issue; adjust as needed
```

---

### WR-04: Inconsistent action pinning strategy in CI workflow

**File:** `.github/workflows/codacy.yml:39,43,59`
**Issue:** The Codacy action is pinned to a full commit SHA (`d43360362776a6789b47b99ae8973510854e2d3d`) for supply-chain security, but `actions/checkout` uses a mutable tag (`@v7`) and `github/codeql-action/upload-sarif` uses a mutable tag (`@v3`). A mutable tag can be force-pushed to point to a different (potentially malicious) commit. This inconsistency means the supply-chain protection is partial.
**Fix:** Pin all third-party actions to full commit SHAs:
```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
uses: github/codeql-action/upload-sarif@1b549b9259bda1cb5ddde3b41741a82a2d15a841  # v3.28.13
```

---

## Info

### IN-01: `usage()` inconsistency — `--help` in usage string but only `-h` / `--help` handled at top level

**File:** `kubectl-mns:11,80-81`
**Issue:** The usage output at line 11 shows `-h | --help`, which is correct. The top-level guards at lines 80-81 handle both correctly. However, if `--help` appears anywhere other than `$1` (e.g., `kubectl mns --help ns1`), it falls through to the argument parser and eventually into `namespaces[]` or `actual_kubectl_args[]`. This is an edge case, not a crash, but it may confuse users who habitually pass `--help` after other args.
**Fix:** No code change required for correctness; acceptable behavior. Optionally document in usage that `-h`/`--help` must be the first argument.

---

### IN-02: README installation URL references upstream repo — correct but fragile

**File:** `README.md:24`
**Issue:** The installation step instructs users to download from `https://raw.githubusercontent.com/wasilak/kubectl-mns/main/kubectl-mns`. This is consistent with the actual remote (`wasilak/kubectl-mns`). However, if the repository is ever renamed or transferred, this URL becomes stale without any visible indication. Using a release artifact URL (GitHub Releases) would be more stable.
**Fix:** Consider publishing versioned releases and pointing the README installation step to a release artifact rather than a raw `main` branch URL.

---

_Reviewed: 2026-06-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
