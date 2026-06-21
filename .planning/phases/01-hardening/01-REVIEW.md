---
phase: 01-hardening
reviewed: 2026-06-21T00:00:00Z
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

# Phase 01: Code Review Report

**Reviewed:** 2026-06-21
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Three files were reviewed: the Codacy CI workflow, the README, and the core `kubectl-mns` shell script. The diff represents a hardening pass — usage messages redirected to stderr, array-based command construction replacing string concatenation, and proper quoting. These are genuine improvements. However, several correctness and security issues remain in the shell script, and one significant reliability gap exists in the CI workflow.

---

## Critical Issues

### CR-01: Command injection via `echo -e "$data"` with unquoted `-e` interpretation

**File:** `kubectl-mns:49`
**Issue:** `echo -e "$data"` interprets escape sequences inside kubectl output. If any pod name, annotation, or other cluster data contains a sequence such as `\n`, `\t`, or `\033[...m`, bash's built-in `echo -e` will silently transform it. More critically, on some systems `echo -e` is not POSIX; the behaviour differs between `/bin/echo`, the bash built-in, and `/bin/sh`. Because the shebang is `#!/usr/bin/env bash`, the built-in is used and `-e` is honoured, but the issue is that kubectl output is being fed through an interpreter rather than printed verbatim. Any ANSI escape codes embedded in pod names or container logs can corrupt terminal output or, in pipelines, alter downstream parsing. Replace with `printf '%s\n\n' "$data"` to print the content verbatim without interpretation.

**Fix:**
```bash
# Replace line 49:
-      echo -e "$data"
-      printf '\n'
+      printf '%s\n\n' "$data"
```

---

### CR-02: `--all-namespaces` is silently dropped without user notification

**File:** `kubectl-mns:30-32`
**Issue:** When a user passes `--all-namespaces` in the kubectl sub-command portion (after `--`), the flag is silently discarded with no warning. The user's intent is to apply the command to all namespaces, but the script will instead execute against only the explicitly listed namespaces, producing misleading output. This constitutes incorrect behaviour: the actual operation diverges from what the user requested without any indication.

```bash
if [ "--all-namespaces" != "$item" ]; then
  actual_kubectl_args+=("$item")
fi
```

The guard exists to prevent namespace conflicts, but swallowing the flag silently is a bug. The correct fix is to emit a warning to stderr and exit non-zero (or at minimum warn), so the user knows their flag was ignored.

**Fix:**
```bash
if [ "--all-namespaces" == "$item" ]; then
  echo "Warning: --all-namespaces is not supported and has been ignored. Use 'kubectl' directly for cluster-wide queries." >&2
  # optionally: exit 1
else
  actual_kubectl_args+=("$item")
fi
```

---

## Warnings

### WR-01: `set -eo pipefail` does not protect against `kubectl` failures inside the loop

**File:** `kubectl-mns:4, 47`
**Issue:** `set -eo pipefail` is set at the top of the script. However, inside the `for ns` loop (line 45–52), `data=$("${kubectl_cmd[@]}")` runs kubectl and if kubectl exits non-zero (e.g., namespace does not exist, insufficient RBAC permissions), the script will exit immediately due to `set -e` — but with no diagnostic message. A single bad namespace silently aborts all subsequent namespaces without explaining which namespace failed or why. The fix is to use explicit error handling around the kubectl call rather than relying on `set -e` to handle it silently.

**Fix:**
```bash
for ns in "${namespaces[@]}"; do
  local kubectl_cmd=("kubectl" "${actual_kubectl_args[@]}" --namespace "$ns")
  if ! data=$("${kubectl_cmd[@]}" 2>&1); then
    echo "Error: kubectl failed for namespace '$ns': $data" >&2
    continue   # or: exit 1, depending on desired behaviour
  fi
  if [[ -n "$data" ]]; then
    printf '%s\n\n' "$data"
  fi
done
```

---

### WR-02: `-h` / `--help` exit without code `0` vs. `1` inconsistency introduces ambiguity

**File:** `kubectl-mns:57-58`
**Issue:** The no-argument case (`-z "$1"`, line 56) now correctly exits with code `1`. But the `-h` and `--help` cases (lines 57–58) call `exit` with no argument, which means the exit code of the last command run (the `usage` function's last `echo`) becomes the script's exit code. In practice that will be `0`, but it is implicit and fragile. Calling `exit 0` explicitly makes intent clear and is consistent with the convention that help output is a normal (non-error) exit.

**Fix:**
```bash
if [ "-h" == "$1" ]; then usage && exit 0; fi
if [ "--help" == "$1" ]; then usage && exit 0; fi
```

---

### WR-03: CI workflow pins `actions/checkout` to a non-existent tag `v7`

**File:** `.github/workflows/codacy.yml:39`
**Issue:** `actions/checkout@v7` does not exist as of the knowledge cutoff. The current major release is `v4`. Referencing a non-existent tag means GitHub Actions will resolve it dynamically, which may fall back to `master`/`HEAD` of that action — undermining supply-chain security and potentially breaking the workflow if GitHub rejects the reference. The Codacy action (line 43) is correctly pinned to a full SHA (`d43360362776a6789b47b99ae8973510854e2d3d`); the checkout action should follow the same pattern or at minimum use a known-valid tag (`v4`).

**Fix:**
```yaml
- name: Checkout code
  uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

---

### WR-04: `github/codeql-action/upload-sarif@v3` is a mutable tag reference

**File:** `.github/workflows/codacy.yml:59`
**Issue:** `github/codeql-action/upload-sarif@v3` is pinned to a mutable major version tag, not a full commit SHA. This means any update to the `v3` tag (intentional or via supply-chain attack) changes what executes in CI without any diff in this file. This is inconsistent with how the Codacy action is pinned (full SHA). Both actions should use full SHAs for reproducible, auditable builds.

**Fix:**
```yaml
- name: Upload SARIF results file
  uses: github/codeql-action/upload-sarif@4fa2a7953630fd2f3fb380f21be14ede0169dd4f  # v3.25.15
```
(Verify the exact SHA from the GitHub releases page for the version in use.)

---

## Info

### IN-01: `--all-namespaces` is silently ignored but `-A` shorthand is not

**File:** `kubectl-mns:30-32`
**Issue:** The filter only strips the long form `--all-namespaces`. The equivalent short flag `-A` accepted by kubectl is not filtered. If a user passes `-A` after `--`, it will be forwarded to every per-namespace `kubectl` invocation, producing a conflict between `--namespace <ns>` and `-A` which may yield unexpected kubectl errors or unexpected output. This is a logic gap that should be addressed alongside CR-02.

**Fix:**
```bash
if [[ "$item" == "--all-namespaces" || "$item" == "-A" ]]; then
  echo "Warning: '$item' is not supported and has been ignored." >&2
else
  actual_kubectl_args+=("$item")
fi
```

---

### IN-02: README installation instructions point to raw `main` branch, not a versioned release

**File:** `README.md:24`
**Issue:** The installation step directs users to download `https://raw.githubusercontent.com/wasilak/kubectl-mns/main/kubectl-mns`. This always fetches the current HEAD of main, meaning users cannot pin to a stable version. If a breaking change is committed, all users who re-run the install command get it silently. For a tool distributed as a shell script, best practice is to point to a tagged release asset (e.g., via GitHub Releases), so users can verify what version they installed.

**Fix (documentation):** Update the download URL to use a versioned GitHub Release, e.g.:
```
https://github.com/wasilak/kubectl-mns/releases/download/v1.0.0/kubectl-mns
```
Or add a note to the README advising users to substitute the desired version tag in the URL.

---

_Reviewed: 2026-06-21_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
