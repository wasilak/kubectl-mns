# Phase 3: Tests - Research

**Researched:** 2026-06-22
**Domain:** bats-core bash test suite, kubectl stubbing, CI integration
**Confidence:** HIGH

---

## Summary

Phase 3 adds a `test/kubectl-mns.bats` suite using bats-core. The plugin is a single ~80-line bash
script (no build system, no external deps beyond bash and kubectl). The test goal is behavioral
coverage of all 7 TESTS-* requirements using a kubectl stub on PATH — no live cluster needed.

bats-core is the standard tool for testing bash scripts. Its `run` helper captures stdout, exit
status, and provides `$output`/`$lines[]`/`$status` for assertions. A PATH-stub pattern (create
a fake `kubectl` in a temp dir, prepend that dir to `$PATH`) is the idiomatic way to mock
external commands; it is documented in the official bats tutorial and widely used in the
kubernetes tooling community.

The suite will be self-contained: bats installed via Homebrew locally and via the official
`bats-core/bats-action` in GitHub Actions. No git submodule or npm dependency is needed for this
single-script project — Homebrew + CI action is the lightest path.

**Primary recommendation:** Write `test/kubectl-mns.bats` using vanilla bats (no bats-assert
needed for this simple script), with a per-test kubectl stub created in `setup()` and cleaned up
in `teardown()`. Install via `brew install bats-core` locally; add a `tests.yml` GitHub Actions
workflow using `bats-core/bats-action@4.0.0`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| kubectl invocation (real) | CLI plugin | — | Script wraps kubectl; stubs replace it in tests |
| kubectl stubbing | Test layer (PATH) | — | PATH override isolates tests from live cluster |
| Argument parsing assertions | Test layer | — | bats `run` captures args forwarded to stub |
| Exit code assertions | Test layer | — | `$status` from `run` |
| Output assertions | Test layer | — | `$output` / `$lines[]` from `run` |
| CI execution | GitHub Actions | Local (brew) | Both use same `bats` binary, same command |

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TESTS-01 | bats-core test suite exists at `test/kubectl-mns.bats` | File created in this phase; bats-core is the decided framework |
| TESTS-02 | No namespace given → defaults to `default` | Stub records calls; assert stub called with `--namespace default` |
| TESTS-03 | Multiple namespaces → one kubectl call per namespace | Stub writes each invocation to a log; assert line count and per-ns args |
| TESTS-04 | `--all-namespaces` stripped from forwarded args | Stub captures args; assert `--all-namespaces` absent in recorded call |
| TESTS-05 | Empty kubectl args → exits 1 and prints usage | `run` the plugin with no `--` section; assert `$status -eq 1`, usage in `$output` |
| TESTS-06 | `-h` / `--help` → prints usage and exits 0 | `run plugin -h`; assert `$status -eq 0`, usage in `$output` |
| TESTS-07 | Namespace failure continues to next namespace | Stub exits 1 for first ns; assert both namespaces were attempted and error on stderr |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| bats-core | 1.13.0 | Test runner for bash scripts | Official fork of sstephenson/bats; MIT; 80k+ installs/yr on Homebrew; only serious bash test runner |

[VERIFIED: npm registry] — `npm view bats version` returns `1.13.0`, published 2025-11-07.
[CITED: https://bats-core.readthedocs.io] — official documentation.
[CITED: https://api.github.com/repos/bats-core/bats-core/releases/latest] — v1.13.0, 2025-11-07.

### Supporting (optional — not required for this phase)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bats-assert | 2.1.0 | Richer assertion helpers (`assert_output`, `assert_success`) | Useful for large suites; unnecessary for 7 tests with native `[ ]` assertions |
| bats-support | 0.3.0 | Required by bats-assert | Only needed if bats-assert is added |

**Decision for this phase:** Use native bats assertions (`[ "$status" -eq 0 ]`, `[[ "$output" == *"text"* ]]`).
No bats-assert needed. Fewer dependencies = simpler setup.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bats-core | shunit2 | shunit2 is older, less ergonomic, no `run` helper — bats is the clear standard |
| bats-core | pytest (via pexpect) | Overkill for a bash-only script; introduces Python dependency |
| PATH stub | bats-mock (buildkite-plugins) | Adds a git submodule for 1 extra feature; PATH stub is simpler and sufficient |

**Installation (local):**
```bash
brew install bats-core
```

**Run:**
```bash
bats test/kubectl-mns.bats
```

---

## Package Legitimacy Audit

> bats-core is installed via Homebrew and GitHub Actions action — not npm install into the project.
> No packages are added to a package.json or requirements.txt. Legitimacy gate below is for the
> npm package that backs `bats` for reference (it mirrors the same codebase).

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| bats (npm) | npm | ~11 yrs (2015) | Active | github.com/bats-core/bats-core | [ASSUMED — slopcheck unavailable] | Approved (well-known project) |
| bats-core (brew) | Homebrew | ~7 yrs | 80k/yr installs | github.com/bats-core/bats-core | [ASSUMED] | Approved |
| bats-core/bats-action@4.0.0 | GitHub Marketplace | Released 2026-02-08 | Official bats org | github.com/bats-core/bats-action | [ASSUMED] | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*slopcheck was unavailable at research time. All three are the official bats-core project,
confirmed via GitHub API and npm registry. Treat as [ASSUMED] per policy.*

---

## Architecture Patterns

### System Architecture Diagram

```
bats test runner
    │
    ├── setup() per test
    │     └── create stub kubectl in $STUB_DIR
    │         prepend $STUB_DIR to $PATH
    │
    ├── @test block
    │     └── run ./kubectl-mns [args]
    │           │
    │           └── plugin sources bash, calls "kubectl ..."
    │                 └── resolves to $STUB_DIR/kubectl  (not real kubectl)
    │                       └── writes call log to $STUB_CALL_LOG
    │                           returns canned output/exit code
    │
    ├── assertions
    │     ├── check $status
    │     ├── check $output / $lines[]
    │     └── check $STUB_CALL_LOG contents
    │
    └── teardown() per test
          └── rm -rf $STUB_DIR
```

### Recommended Project Structure

```
test/
└── kubectl-mns.bats     # all 7 test cases in one file
kubectl-mns              # the script under test (repo root)
```

No `test/libs/` or `test/test_helper/` needed — the suite is simple enough for one file.

### Pattern 1: kubectl PATH Stub

**What:** Create a minimal shell script named `kubectl` in a temp dir, prepend that dir to `$PATH`.
Every `kubectl ...` call inside the plugin invokes the stub instead of the real binary.

**When to use:** Any test that invokes the plugin. This is the only stubbing method needed.

**Example:**
```bash
# Source: https://bats-core.readthedocs.io/en/stable/writing-tests.html

setup() {
  STUB_DIR="$(mktemp -d)"
  STUB_CALL_LOG="$STUB_DIR/kubectl.log"

  cat > "$STUB_DIR/kubectl" << 'EOF'
#!/usr/bin/env bash
echo "$@" >> "$STUB_CALL_LOG"
echo "stub output for $*"
exit 0
EOF
  chmod +x "$STUB_DIR/kubectl"
  export PATH="$STUB_DIR:$PATH"
  export STUB_CALL_LOG
}

teardown() {
  rm -rf "$STUB_DIR"
}
```

**Key insight:** The stub must export `STUB_CALL_LOG` so the inner subprocess (the plugin) can
write to it. The plugin is run via `run ./kubectl-mns ...`, which inherits the environment.

### Pattern 2: Failure stub for TESTS-07

**What:** A stub that exits non-zero for specific namespace arguments, to test error-continuation.

```bash
cat > "$STUB_DIR/kubectl" << 'EOF'
#!/usr/bin/env bash
echo "$@" >> "$STUB_CALL_LOG"
# fail for the first namespace (ns1), succeed for the second (ns2)
if [[ "$*" == *"--namespace ns1"* ]]; then
  exit 1
fi
echo "output for $*"
exit 0
EOF
```

### Pattern 3: Asserting forwarded args

**What:** Inspect `$STUB_CALL_LOG` to verify args the plugin passed to kubectl.

```bash
@test "multi-namespace: one kubectl call per namespace" {
  run ./kubectl-mns ns1 ns2 -- get pods
  [ "$status" -eq 0 ]
  # log has two lines — one per namespace
  call_count=$(wc -l < "$STUB_CALL_LOG")
  [ "$call_count" -eq 2 ]
  # first call targets ns1
  grep -q -- "--namespace ns1" "$STUB_CALL_LOG"
  grep -q -- "--namespace ns2" "$STUB_CALL_LOG"
}
```

### Pattern 4: Plugin path resolution

**What:** Tests need a reliable path to `kubectl-mns` regardless of working directory.

```bash
setup() {
  # DIR resolves to the test/ directory; script is one level up
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PLUGIN="$DIR/../kubectl-mns"
  # ... stub setup ...
}
```

Then in each test: `run "$PLUGIN" ns1 -- get pods`

### Pattern 5: usage() output check

**What:** The plugin sends usage to stderr. bats `run` by default captures stdout only into
`$output`. Use `run --separate-stderr` (bats >= 1.5) or redirect stderr to stdout in the
invocation.

```bash
# Option A — redirect stderr to stdout inside run (works with all bats versions)
run bash -c '"$PLUGIN" -h 2>&1'   # via exported PLUGIN

# Option B — bats >= 1.5 separate stderr
run --separate-stderr "$PLUGIN" -h
[ "$status" -eq 0 ]
grep -q "Usage" <<< "$stderr"

# Option C — simplest: since set -e is off in test context, use:
run "$PLUGIN" -h
# output may be empty (stderr not captured) — assert status only if output not needed
```

**Recommended:** Option A (redirect `2>&1` via `bash -c`) — most portable, no bats version
dependency, and the usage text is simple enough that checking one keyword (`Usage`) is sufficient.

**Alternative for stderr-emitting tests:** bats 1.7+ `run --keep-empty-lines --separate-stderr`.
Since Homebrew ships 1.13.0, this is available — but it's an optional enhancement.

### Anti-Patterns to Avoid

- **Using a real kubectl:** Tests break outside clusters. Always stub.
- **Hardcoding absolute paths** to the plugin in test file: breaks on other machines. Use `$BATS_TEST_FILENAME`-relative paths.
- **Testing stderr content with plain `run`:** bats captures stdout only by default — use `2>&1` redirect for stderr content checks.
- **One stub per test file (not per test):** Using `setup_file` for the stub means tests share state; a per-test stub in `setup()` is safer and idiomatic.
- **Forgetting `chmod +x`** on the stub: the plugin invokes kubectl as a command, not `bash kubectl` — it must be executable.
- **Not exporting `STUB_CALL_LOG`:** Child processes (the plugin) won't see the variable without `export`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test runner with pass/fail tracking | Custom test harness | bats-core | Subprocess isolation, TAP output, CI integration built in |
| Mock registry | Custom mock framework | Simple PATH stub | For one binary (kubectl), a stub script is sufficient and has no dependencies |
| Arg capture | Custom arg parser in test | Log-to-file in stub + grep | Simple, readable, zero dependencies |

**Key insight:** This is an ~80-line bash script with 7 behaviors. Over-engineering the test
infrastructure (bats-mock, bats-detik, complex fixtures) would make the tests harder to
understand than the script itself. Simplest approach wins.

---

## Common Pitfalls

### Pitfall 1: stderr not captured by `run`

**What goes wrong:** Tests for `-h`/`--help` or error paths assert on `$output` but get empty
string — the plugin writes to stderr, which `run` does not capture into `$output` by default.

**Why it happens:** bats `run` only captures stdout. The plugin uses `echo ... >&2` for usage
and error messages.

**How to avoid:** Use `run bash -c '"$PLUGIN" -h 2>&1'` for tests that need to inspect stderr
content, OR use `run --separate-stderr` (bats >= 1.5) and check `$stderr`.

**Warning signs:** Test for `-h` passes status check but fails on `$output` content assertion.

### Pitfall 2: PATH not reset between tests

**What goes wrong:** If `STUB_DIR` is created in `setup_file` (once for all tests), tests that
modify the stub affect each other. A failure-stub bleeds into the next test.

**Why it happens:** Shared mutable state across tests.

**How to avoid:** Create and destroy the stub directory in `setup()`/`teardown()` (per-test),
not `setup_file()`/`teardown_file()`.

**Warning signs:** Tests pass in isolation but fail when run together.

### Pitfall 3: Plugin exits non-zero and bats fails the test before assertions

**What goes wrong:** When testing TESTS-05 (empty args → exit 1), `run` is used correctly
but the tester forgets `run` does NOT propagate exit codes — the `@test` block itself does
not fail from a non-zero exit inside `run`. This is actually the correct behavior, but forgetting
it causes confusion when debugging.

**Why it happens:** Misunderstanding of `run` semantics.

**How to avoid:** Always use `run` when calling the plugin. Never call `./kubectl-mns args`
directly inside a test block unless you want the test to fail on non-zero exit.

### Pitfall 4: `set -e` in the plugin causes early exit during testing

**What goes wrong:** The plugin has `set -eo pipefail`. bats isolates each `@test` as a
subprocess and `run` captures the result — this is fine. But calling the plugin directly
(not via `run`) inside test setup code can cause unexpected test failures.

**Why it happens:** `set -e` propagates through source if the script is sourced rather than run.

**How to avoid:** Always invoke the plugin as a subprocess via `run "$PLUGIN" ...`, never via
`source` or `.`.

### Pitfall 5: STUB_CALL_LOG path not exported

**What goes wrong:** The stub script writes to `$STUB_CALL_LOG`, but the log file stays empty
because the variable was set but not exported — child processes don't see it.

**Why it happens:** Bash variable scope: `VAR=...` without `export` is not inherited by subprocesses.

**How to avoid:** Always `export STUB_CALL_LOG` in `setup()`.

---

## Code Examples

### Full test file skeleton

```bash
#!/usr/bin/env bats
# Source: bats-core tutorial https://bats-core.readthedocs.io/en/stable/tutorial.html

setup() {
  # Resolve plugin path relative to this test file
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PLUGIN="$DIR/../kubectl-mns"

  # Create kubectl stub
  STUB_DIR="$(mktemp -d)"
  STUB_CALL_LOG="$STUB_DIR/kubectl.log"

  cat > "$STUB_DIR/kubectl" << 'EOF'
#!/usr/bin/env bash
echo "$@" >> "$STUB_CALL_LOG"
echo "stub output"
exit 0
EOF
  chmod +x "$STUB_DIR/kubectl"
  export PATH="$STUB_DIR:$PATH"
  export STUB_CALL_LOG
  export PLUGIN
}

teardown() {
  rm -rf "$STUB_DIR"
}

# TESTS-05: empty kubectl args → exit 1
@test "no kubectl args: exits 1 and prints usage" {
  run bash -c '"$PLUGIN" -- 2>&1'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage"* ]]
}

# TESTS-06: -h → exit 0
@test "-h: prints usage and exits 0" {
  run bash -c '"$PLUGIN" -h 2>&1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# TESTS-06: --help → exit 0
@test "--help: prints usage and exits 0" {
  run bash -c '"$PLUGIN" --help 2>&1'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

# TESTS-02: no namespace → defaults to "default"
@test "no namespace: defaults to 'default'" {
  run "$PLUGIN" -- get pods
  [ "$status" -eq 0 ]
  grep -q -- "--namespace default" "$STUB_CALL_LOG"
}

# TESTS-03: multiple namespaces → one call per namespace
@test "multiple namespaces: one kubectl call per namespace" {
  run "$PLUGIN" ns1 ns2 -- get pods
  [ "$status" -eq 0 ]
  call_count=$(wc -l < "$STUB_CALL_LOG")
  [ "$call_count" -eq 2 ]
  grep -q -- "--namespace ns1" "$STUB_CALL_LOG"
  grep -q -- "--namespace ns2" "$STUB_CALL_LOG"
}

# TESTS-04: --all-namespaces stripped
@test "--all-namespaces stripped from forwarded args" {
  run "$PLUGIN" ns1 -- get pods --all-namespaces
  [ "$status" -eq 0 ]
  ! grep -q -- "--all-namespaces" "$STUB_CALL_LOG"
}

# TESTS-07: per-namespace failure continues
@test "namespace failure: continues to next namespace" {
  # Override stub to fail for ns1
  cat > "$STUB_DIR/kubectl" << 'STUBEOF'
#!/usr/bin/env bash
echo "$@" >> "$STUB_CALL_LOG"
if [[ "$*" == *"--namespace ns1"* ]]; then
  exit 1
fi
echo "stub output"
exit 0
STUBEOF
  chmod +x "$STUB_DIR/kubectl"

  run bash -c '"$PLUGIN" ns1 ns2 -- get pods 2>&1'
  # Script exits 0 despite partial failure
  [ "$status" -eq 0 ]
  # Both namespaces were attempted
  grep -q -- "--namespace ns1" "$STUB_CALL_LOG"
  grep -q -- "--namespace ns2" "$STUB_CALL_LOG"
  # Error reported
  [[ "$output" == *"Error"* ]]
}
```

### GitHub Actions workflow

```yaml
# .github/workflows/tests.yml
name: Tests

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

permissions:
  contents: read

jobs:
  bats:
    name: bats test suite
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Bats
        id: setup-bats
        uses: bats-core/bats-action@4.0.0
        with:
          support-install: false
          assert-install: false
          detik-install: false
          file-install: false

      - name: Run tests
        run: bats test/kubectl-mns.bats
```

Note: `bats-core/bats-action@4.0.0` — use a pinned tag (SHA pinning is preferable for supply-chain
security, consistent with the project's existing Codacy action pinning).

For stronger supply-chain pinning, resolve the SHA for tag `4.0.0`:
```
# Run once to get SHA: git ls-remote https://github.com/bats-core/bats-action refs/tags/4.0.0
uses: bats-core/bats-action@<SHA>  # 4.0.0
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| sstephenson/bats (archived) | bats-core/bats-core | ~2018 | Same `@test` syntax; bats-core is maintained fork |
| Manual bats install script | `bats-core/bats-action` for CI | ~2022 | Single action line; auto-caches bats binary |
| Separate stderr with redirect | `run --separate-stderr` | bats 1.5 (2021) | Cleaner; optional since redirects still work |

**Deprecated/outdated:**
- `sstephenson/bats`: archived, unmaintained — use `bats-core/bats-core` instead.
- `mig4/setup-bats` GitHub action: unofficial; prefer the official `bats-core/bats-action`.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | bats npm package (`bats` 1.13.0 on npm) mirrors bats-core/bats-core | Package Legitimacy Audit | Low — package name/org match; not used in this phase |
| A2 | `bats-core/bats-action@4.0.0` works on ubuntu-latest runners as of Jun 2026 | Code Examples | Low — action released Feb 2026; very recent |
| A3 | No bats-assert is needed for 7 simple assertions | Standard Stack | Low — native `[ ]` and `[[ ]]` are sufficient; easy to add later |

---

## Open Questions (RESOLVED)

1. **SHA pinning for bats-action**
   - What we know: The project pins other actions by commit SHA (Codacy action). The tests.yml should be consistent.
   - What's unclear: The SHA for `bats-core/bats-action@4.0.0` was not fetched (would require a git ls-remote call).
   - Recommendation: Planner should add a task to resolve the SHA at plan time via `git ls-remote https://github.com/bats-core/bats-action refs/tags/4.0.0` and pin the action.
   - **RESOLVED:** Plan Task 2 pins `bats-core/bats-action` to SHA `5b1e60c2ee94cb1b44a616ea4b1f466f9d6e38ef` (v4.0.0) and `actions/checkout` to SHA `34e114876b0b11c390a56381ad16ebd13914f8d5`.

2. **`-A` flag stripping (TESTS-04 variant)**
   - What we know: The plugin strips both `--all-namespaces` and `-A`. The requirement says `--all-namespaces`.
   - What's unclear: Should TESTS-04 cover `-A` as well, or only `--all-namespaces`?
   - Recommendation: Cover both flags in one test for completeness. The planner can add a second assertion in the same `@test` block.
   - **RESOLVED:** TESTS-04 @test block asserts both `--all-namespaces` and `-A` are absent from the stub call log.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bats-core | Run tests locally | ✗ | — | `brew install bats-core` (one command) |
| bash | Plugin under test | ✓ (macOS system bash) | 3.2 (macOS) | — |
| mktemp | Stub setup | ✓ | macOS built-in | — |
| grep | Stub call log assertions | ✓ | macOS built-in | rg (already available per project config) |

**Missing dependencies with no fallback:**
- bats-core: not installed, must be installed before running tests. One-liner: `brew install bats-core`.

**Missing dependencies with fallback:**
- none

---

## Validation Architecture

> `workflow.nyquist_validation` is absent from `.planning/config.json` — treating as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bats-core 1.13.0 |
| Config file | none — bats discovers `*.bats` files by argument |
| Quick run command | `bats test/kubectl-mns.bats` |
| Full suite command | `bats test/kubectl-mns.bats` (single file for this phase) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TESTS-01 | Suite file exists at `test/kubectl-mns.bats` | structural | `ls test/kubectl-mns.bats` | ❌ Wave 0 |
| TESTS-02 | No namespace → `--namespace default` | unit | `bats test/kubectl-mns.bats` | ❌ Wave 0 |
| TESTS-03 | Multi-namespace → one call per ns | unit | `bats test/kubectl-mns.bats` | ❌ Wave 0 |
| TESTS-04 | `--all-namespaces`/`-A` stripped | unit | `bats test/kubectl-mns.bats` | ❌ Wave 0 |
| TESTS-05 | Empty args → exit 1 + usage | unit | `bats test/kubectl-mns.bats` | ❌ Wave 0 |
| TESTS-06 | `-h`/`--help` → exit 0 + usage | unit | `bats test/kubectl-mns.bats` | ❌ Wave 0 |
| TESTS-07 | Namespace failure → continue | unit | `bats test/kubectl-mns.bats` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `bats test/kubectl-mns.bats`
- **Per wave merge:** `bats test/kubectl-mns.bats`
- **Phase gate:** All 7 tests green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/kubectl-mns.bats` — the entire test file (this is what the phase creates)
- [ ] Install bats-core: `brew install bats-core`

---

## Security Domain

> `security_enforcement` not set in config — treating as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | Plugin validates in bash; tests verify the behavior but don't add new input paths |
| V6 Cryptography | no | — |

**Security note:** The test stub executes shell code written to `$STUB_DIR/kubectl`. This is
acceptable because the stub is created from repo-controlled content in a mktemp directory
that is cleaned up in `teardown()`. No user-supplied content reaches the stub file.

**CI workflow security:** The `tests.yml` action should pin `actions/checkout` to a SHA and
consider pinning `bats-core/bats-action` to a SHA (consistent with the project's existing
Codacy action pinning policy from SECURITY-01).

### Known Threat Patterns for bash test suite

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stub dir not cleaned up (tmp leak) | — | `teardown()` calls `rm -rf "$STUB_DIR"` |
| Unpinned CI action (supply chain) | Tampering | Pin `bats-core/bats-action` to commit SHA |

---

## Sources

### Primary (HIGH confidence)
- [bats-core official docs — writing tests](https://bats-core.readthedocs.io/en/stable/writing-tests.html)
- [bats-core official docs — tutorial](https://bats-core.readthedocs.io/en/stable/tutorial.html)
- [bats-core official docs — installation](https://bats-core.readthedocs.io/en/stable/installation.html)
- [bats-core official docs — usage](https://bats-core.readthedocs.io/en/stable/usage.html)
- [GitHub API — bats-core latest release](https://api.github.com/repos/bats-core/bats-core/releases/latest) — v1.13.0, 2025-11-07
- [GitHub API — bats-action latest release](https://api.github.com/repos/bats-core/bats-action/releases/latest) — v4.0.0, 2026-02-08
- [Homebrew — bats-core formula info](https://formulae.brew.sh/formula/bats-core) — stable 1.13.0
- [npm registry — bats package](https://www.npmjs.com/package/bats) — 1.13.0, published 2025-11-07

### Secondary (MEDIUM confidence)
- [GitHub Marketplace — Setup Bats and Bats libraries](https://github.com/marketplace/actions/setup-bats-and-bats-libraries) — action inputs/outputs verified
- [bats-core/bats-action GitHub](https://github.com/bats-core/bats-action) — official action source

### Tertiary (LOW confidence)
- WebSearch results for bats-mock, shunit2 alternatives — not recommended; sufficient context from official sources

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified via GitHub API, npm registry, Homebrew
- Architecture: HIGH — documented in official bats tutorial; PATH stub is the canonical pattern
- Test examples: HIGH — derived directly from the actual plugin source (read in full)
- CI workflow: HIGH — based on official bats-action docs with latest confirmed version
- Pitfalls: MEDIUM — derived from reading bats docs + known bash subprocess/stderr gotchas

**Research date:** 2026-06-22
**Valid until:** 2026-09-22 (bats-core is stable; action versions may drift sooner — pin SHA at plan time)
