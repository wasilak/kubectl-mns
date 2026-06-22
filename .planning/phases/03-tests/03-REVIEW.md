---
phase: 03-tests
reviewed: 2026-06-22T00:00:00Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - test/kubectl-mns.bats
  - .github/workflows/tests.yml
findings:
  critical: 0
  warning: 0
  info: 4
  total: 4
status: clean
---

# Phase 03: Code Review Report

**Reviewed:** 2026-06-22
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

Reviewed the bats-core test suite (`test/kubectl-mns.bats`) and the GitHub Actions workflow (`.github/workflows/tests.yml`). The test coverage is functionally sound and the CI pipeline is minimal but correct. Three quality defects need attention before this ships: a duplicate test ID that breaks traceability, a fragile subprocess invocation pattern used in three tests that will silently break if the environment is not exported correctly, and grep usage that violates project tooling conventions. No security vulnerabilities or data loss risks were found.

---

## Warnings

### WR-01: Duplicate test ID `TESTS-06` breaks traceability

**File:** `test/kubectl-mns.bats:70-75`
**Issue:** Both the `-h` test (line 63) and the `--help` test (line 71) carry the ID `TESTS-06`. Test IDs are the traceability link between requirements and tests. A duplicate ID means one of these tests can never be uniquely referenced in a report, a CI run, or a requirements matrix. The requirement should have a single ID covering both flags, or the second flag gets its own ID (e.g., `TESTS-06b` or `TESTS-08`).
**Fix:** Either merge them into one parametrized test or assign the `--help` variant a distinct ID:
```bash
# Option A: single test, both flags
@test "TESTS-06: -h and --help print usage and exit 0" {
  run "$PLUGIN" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]

  run "$PLUGIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# Option B: give --help its own ID
# TESTS-06: --help prints usage and exits 0
@test "TESTS-06: --help prints usage and exits 0" { ... }
```

---

### WR-02: Fragile `bash -c '"$PLUGIN" ...'` invocation pattern

**File:** `test/kubectl-mns.bats:58,65,91`
**Issue:** Three tests use `run bash -c '"$PLUGIN" <args> 2>&1'` to invoke the plugin. This relies on `$PLUGIN` being exported into the subshell's environment (which `setup()` does via `export PLUGIN`). The inner `bash -c` string receives `"$PLUGIN"` as a literal — the variable is resolved by the *inner* shell at runtime, not the outer shell at `run` time. This is correct today, but it is non-obvious and fragile in two ways:

1. If a future refactor of `setup()` removes the `export` keyword (e.g., changes `export PLUGIN` to `PLUGIN=...`), these three tests silently fail with "command not found" or an empty-path error rather than a clear assertion failure.
2. The `2>&1` redirect is redundant: bats `run` already captures both stdout and stderr of the command it executes.

**Fix:** Invoke the plugin directly. The `2>&1` redirect can be dropped because bats `run` captures stderr in `$output` by default:
```bash
# Before (fragile):
run bash -c '"$PLUGIN" -- 2>&1'

# After (direct, clear):
run "$PLUGIN" --
```
This applies to all three occurrences: lines 58, 65, and 91.

---

### WR-03: `grep` used directly — violates project tooling conventions

**File:** `test/kubectl-mns.bats:33,42,43,52,53,93,94`
**Issue:** CLAUDE.md mandates `rg` (ripgrep) everywhere grep is used. The test file uses `grep -q` in seven places. While grep is universally available on the CI runner (`ubuntu-latest`) so this will not break tests, it violates the project's enforced tooling standard and sets an inconsistent precedent for test maintenance.
**Fix:** Replace all `grep -q` occurrences with `rg -q`:
```bash
# Before:
grep -q -- "--namespace default" "$STUB_CALL_LOG"

# After:
rg -qF -- "--namespace default" "$STUB_CALL_LOG"
```
Use `-F` (fixed-string) with `rg` since all patterns here are literals, not regexes — this also makes intent clearer and avoids accidental regex metacharacter interpretation.

Note: The `bats-action` in the workflow installs bats but does not install ripgrep. Verify `ubuntu-latest` has `rg` available, or add an install step:
```yaml
- name: Install ripgrep
  run: sudo apt-get install -y ripgrep
```

---

## Info

### IN-01: TESTS-01 (self-referential sanity test) provides near-zero value

**File:** `test/kubectl-mns.bats:99-102`
**Issue:** `TESTS-01` checks that the bats test file itself exists and is readable. This condition is guaranteed by bats executing the file at all — if the file were missing or unreadable, bats would have already failed with an OS-level error before reaching any test. The test cannot fail in any realistic scenario and occupies a requirement slot (TESTS-01) that could map to a more meaningful check (e.g., verify the plugin file exists and is executable).
**Fix:** Replace with a meaningful smoke test or delete it. A more useful TESTS-01 would be:
```bash
@test "TESTS-01: plugin file exists and is executable" {
  [ -f "$PLUGIN" ]
  [ -x "$PLUGIN" ]
}
```

---

### IN-02: Test ordering does not match ID ordering

**File:** `test/kubectl-mns.bats:29-102`
**Issue:** Tests are defined in the order TESTS-02, TESTS-03, TESTS-04, TESTS-05, TESTS-06, TESTS-06, TESTS-07, TESTS-01. The TESTS-01 sanity check appears last despite having the lowest numeric ID. Bats executes tests in file order, so reports will show results out of numeric sequence. This is cosmetic but makes requirement traceability harder to follow in CI output.
**Fix:** Move TESTS-01 to the top of the file, immediately after `teardown()`.

---

### IN-03: No timeout on CI test step

**File:** `.github/workflows/tests.yml:29`
**Issue:** The `Run tests` step has no `timeout-minutes` setting. A hung test (e.g., a kubectl stub that blocks on stdin) would consume the full job timeout (6 hours by default on GitHub Actions), burning runner minutes and delaying feedback.
**Fix:**
```yaml
- name: Run tests
  timeout-minutes: 5
  run: bats test/kubectl-mns.bats
```

---

### IN-04: CI triggers only on `main` — feature branches get no coverage

**File:** `.github/workflows/tests.yml:3-7`
**Issue:** The workflow runs only on `push` to `main` and `pull_request` targeting `main`. Any branch pushed without a PR (e.g., exploratory work, draft branches) receives no CI feedback. Tests are cheap and fast — there is no cost reason to restrict them.
**Fix:** Add a push trigger for all branches, or explicitly trigger on any push:
```yaml
on:
  push:
  pull_request:
    branches: ["main"]
```
Or keep branch filtering but expand it:
```yaml
on:
  push:
    branches: ["**"]
  pull_request:
    branches: ["main"]
```

---

_Reviewed: 2026-06-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
