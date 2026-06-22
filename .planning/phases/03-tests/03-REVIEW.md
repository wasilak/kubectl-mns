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
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-06-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

The test suite and CI workflow are functional and reasonably isolated (PATH-based
kubectl stub, SHA-pinned actions, least-privilege `permissions: contents: read`).
However, the suite leaves the plugin's most complex parsing logic (`--context` /
`--kubeconfig`) entirely uncovered, does not assert the exit code when *all*
namespaces fail (which the current plugin implementation returns `0` for — a latent
bug), and the CI step that installs ripgrep skips `apt-get update`, which is a known
source of intermittent CI failures as the runner image ages. Several test
assertions are weaker or more fragile than they should be.

No critical defects that produce false-passing or false-failing tests were found, so
existing coverage is trustworthy as far as it goes — it simply does not go far
enough into the plugin's branching logic.

## Warnings

### WR-01: `--context` / `--kubeconfig` flag parsing is entirely untested

**File:** `test/kubectl-mns.bats` (entire file — no test covers this)
**Issue:** `kubectl-mns` has special handling for `--context` and `--kubeconfig`
(see plugin lines 37–39): the next arg is consumed as a value and forwarded in
`extra_kubectl_flags`, which are placed *before* the kubectl subcommand. This is
the most complex argument-parsing branch in the plugin (state machine via
`consume_next_as`, ordering constraint, and the trailing-value error at lines
52–55). None of it is exercised by the test suite.

Specifically untested:
- `kubectl-mns --context my-ctx -- get pods` (forwards `--context my-ctx` correctly)
- `kubectl-mns ns1 --kubeconfig ~/.kube/config -- get pods` (mixed ns + flag)
- `kubectl-mns --context` with no trailing value (plugin exits 1, lines 52–55)

This branch is exactly where regressions tend to land, and the suite gives it zero
guard.

**Fix:** Add tests, e.g.

```bash
# TESTS-08: --context is forwarded before the kubectl subcommand
@test "TESTS-08: --context FLAG VALUE is forwarded" {
  run "$PLUGIN" --context ctx-1 -- get pods
  [ "$status" -eq 0 ]
  rg -qF -- "--context ctx-1" "$STUB_CALL_LOG"
  # --context must precede the subcommand
  rg -q -- "^--context ctx-1 get pods" "$STUB_CALL_LOG"
  rg -qF -- "--namespace default" "$STUB_CALL_LOG"
}

# TESTS-09: --context with no value exits 1
@test "TESTS-09: --context with no value exits 1" {
  run "$PLUGIN" --context -- get pods
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: --context requires a value"* ]]
}
```

### WR-02: No test for the "all namespaces fail" exit code (plugin likely returns 0)

**File:** `test/kubectl-mns.bats` (missing test)
**Issue:** TESTS-07 only exercises a *partial* failure (ns1 fails, ns2 succeeds).
There is no test where *every* namespace fails. Tracing the plugin under
`set -eo pipefail`:

- `if ! data=$("${kubectl_cmd[@]}"); then printf 'Error...' >&2; continue; fi` — the
  `!`/`if` suppresses `set -e`, so a failed kubectl prints the error and continues.
- When the loop ends on a failing iteration, the last command executed inside the
  loop body is `printf 'Error: kubectl failed for namespace %s\n'` (exit 0), so the
  function returns `0` and the script exits `0` — *even though every namespace
  failed*.

This is very likely a plugin bug (a CLI that does nothing successfully because every
target failed should not exit 0). Because no test pins the all-fail exit code, the
bug is invisible to the suite. Tests should explicitly assert the desired behavior
so the plugin can be corrected against a contract.

**Fix:** Add a test that pins the contract (and, separately, fix the plugin to
return non-zero when all namespaces failed):

```bash
# TESTS-10: all namespaces failing should exit non-zero
@test "TESTS-10: all namespaces failing exits non-zero" {
  cat > "$STUB_DIR/kubectl" << 'STUBEOF'
#!/usr/bin/env bash
echo "$@" >> "$STUB_CALL_LOG"
exit 1
STUBEOF
  chmod +x "$STUB_DIR/kubectl"

  run "$PLUGIN" ns1 ns2 -- get pods
  [ "$status" -ne 0 ]
  rg -qF -- "--namespace ns1" "$STUB_CALL_LOG"
  rg -qF -- "--namespace ns2" "$STUB_CALL_LOG"
  [[ "$output" == *"Error"* ]]
}
```

### WR-03: CI installs ripgrep without `apt-get update` (flaky as runner image ages)

**File:** `.github/workflows/tests.yml:29`
**Issue:** The step runs `sudo apt-get install -y ripgrep` directly. ubuntu-latest
runner images ship a package index snapshot from image-build time; as that snapshot
ages, referenced `.deb` URLs get rotated out of the mirror and `apt-get install`
fails with `404  IPFS Not Found` / `Unable to fetch some archives`. This is a
well-known class of intermittent CI failure on GitHub-hosted runners. The fix is
standard: update the index first.

**Fix:**

```yaml
      - name: Install ripgrep
        run: |
          sudo apt-get update
          sudo apt-get install -y ripgrep
```

### WR-04: TESTS-07 assertions are too weak to lock the partial-failure contract

**File:** `test/kubectl-mns.bats:88-92`
**Issue:** The test only asserts: status 0, both namespaces appear in the log, and
the word `Error` appears in `$output`. It does **not** verify:
- that ns2's output (`=== namespace: ns2 ===` / `stub output`) is actually printed,
- that the ns1 header is *not* printed (since ns1 failed before any output),
- that the `Error` message is the *specific* plugin-owned
  `Error: kubectl failed for namespace ns1` rather than any stray "Error" string.

A future regression where the plugin swallowed ns2's successful output, or printed
ns1's header before failing, would pass this test silently.

**Fix:**

```bash
run "$PLUGIN" ns1 ns2 -- get pods
[ "$status" -eq 0 ]
rg -qF -- "--namespace ns1" "$STUB_CALL_LOG"
rg -qF -- "--namespace ns2" "$STUB_CALL_LOG"
[[ "$output" == *"Error: kubectl failed for namespace ns1"* ]]
[[ "$output" == *"=== namespace: ns2 ==="* ]]
[[ "$output" == *"stub output"* ]]
# ns1 failed → its header should NOT be printed
[[ "$output" != *"=== namespace: ns1 ==="* ]]
```

## Info

### IN-01: `TESTS-01` is a no-value sanity test

**File:** `test/kubectl-mns.bats:96-99`
**Issue:** `TESTS-01` only asserts the test file itself exists and is readable. This
checks the bats harness, not the plugin, and adds no real coverage. Every other test
already depends on the file being readable, so the assertion is redundant.

**Fix:** Remove `TESTS-01` (and drop the corresponding requirement ID from the
validation matrix) or repurpose it to assert something meaningful about the plugin
binary (e.g., that `kubectl-mns` is executable).

### IN-02: TESTS-04 uses an imprecise substring assertion for `-A`

**File:** `test/kubectl-mns.bats:53`
**Issue:** `! rg -qF -- " -A"` rejects *any* occurrence of the substring `" -A"`
(space, hyphen, capital A) anywhere in the log. This is fragile: if a future test
or kubectl arg legitimately contained `" -A"` (e.g., a value for some flag), this
would fail for the wrong reason. The cleaner contract is "the literal `-A` token is
not passed to kubectl", which is better checked against the per-call log line, not
the whole file as an undelimited substring.

**Fix:** Assert against the exact forwarded invocation:

```bash
# The forwarded args for the single ns should be exactly: get pods --namespace ns1
rg -qx -- "get pods --namespace ns1" "$STUB_CALL_LOG"
```

### IN-03: PATH accumulates across tests; teardown `rm -rf "$STUB_DIR"` is unsafe if `mktemp` fails

**File:** `test/kubectl-mns.bats:20,25-27`
**Issue:** `export PATH="$STUB_DIR:$PATH"` runs in every `setup()`, so PATH grows
by one entry per test. `teardown()` removes the directory but leaves the now-dangling
entry in `PATH`. Harmless for correctness (lookups fail), but noisy and a latent
trap if a test later relies on PATH hygiene. Separately, if `mktemp -d` failed,
`STUB_DIR` would be empty and `rm -rf ""` would error.

**Fix:** Guard teardown, and rely on bats' per-test sandboxing rather than
accumulating:

```bash
teardown() {
  [ -n "$STUB_DIR" ] && rm -rf "$STUB_DIR"
}
```

### IN-04: `--all-namespaces` / `-A` *before* `--` is untested (treated as a namespace)

**File:** `test/kubectl-mns.bats` (missing edge coverage)
**Issue:** The plugin only strips `--all-namespaces`/`-A` from args *after* `--`
(plugin line 45). If a user places them before `--`, they are captured into
`namespaces[]` (line 42) and forwarded as `--namespace --all-namespaces` — clearly
not intended. No test pins this behavior, so it is undefined whether the plugin
should reject or ignore such input. The current behavior is silently wrong.

**Fix:** Add an explicit edge test once the intended contract is decided, e.g.

```bash
# TESTS-11: -A before -- should not be forwarded as a namespace
@test "TESTS-11: -A before -- is treated as namespace (current behavior)" {
  run "$PLUGIN" -A -- get pods
  # Document current behavior; tighten once the contract is decided.
  rg -qF -- "--namespace -A" "$STUB_CALL_LOG" || true
}
```

---

_Reviewed: 2026-06-22T00:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_