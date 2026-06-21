# Roadmap — Milestone v1.0 Foundation & Quality

_Created: 2026-06-21_

## Summary

3 phases | 19 requirements | All covered ✓

| # | Phase | Goal | Requirements | Criteria |
|---|-------|------|--------------|----------|
| 1 | Hardening | Fix shell safety, bugs, and CI security | SAFETY-01..03, BUGFIX-01..04, SECURITY-01 | 4 |
| 2 | Features | Add per-namespace error handling, output labels, and arg forwarding | ERRORS-01, OUTPUT-01, ARGS-01..02 | 4 |
| 3 | Tests | Cover all behaviors with a bats-core suite | TESTS-01..07 | 3 |

## Phase Details

### Phase 1: Hardening
**Goal:** The plugin is shell-safe, bug-free, and the CI pipeline is secured against supply-chain risk.
**Requirements:** SAFETY-01, SAFETY-02, SAFETY-03, BUGFIX-01, BUGFIX-02, BUGFIX-03, BUGFIX-04, SECURITY-01
**Success criteria:**
1. Running `kubectl-mns` with no arguments exits with code 1 and prints usage to stderr (not stdout).
2. Running `kubectl-mns ns1 -- get pods` with a namespace containing a space or special character does not cause word-splitting or unexpected behavior.
3. The `usage()` output shows `namespace-2` (not `namespac-2`) and the README example omits the redundant `kubectl` after `--`.
4. The Codacy workflow file references the action by commit SHA, not `@master`.
**Plans:** 3 plans

Plans:
- [ ] 01-01-PLAN.md — Plugin hardening: array quoting, array exec, -n check, stderr, typo, exit 1 (SAFETY-01..03, BUGFIX-02..04)
- [ ] 01-02-PLAN.md — README fix: remove redundant kubectl after -- (BUGFIX-01)
- [ ] 01-03-PLAN.md — CI security: pin Codacy action to commit SHA (SECURITY-01)

### Phase 2: Features
**Goal:** The plugin labels each namespace's output block, continues past per-namespace failures, and forwards `--context` / `--kubeconfig` to every kubectl call.
**Requirements:** ERRORS-01, OUTPUT-01, ARGS-01, ARGS-02
**Success criteria:**
1. Running `kubectl-mns ns1 ns2 -- get pods` prints `=== namespace: ns1 ===` and `=== namespace: ns2 ===` before each block of output.
2. When one namespace returns a non-zero exit code, the script prints an error to stderr for that namespace and continues to the next one.
3. Running `kubectl-mns --context my-ctx ns1 -- get pods` forwards `--context my-ctx` to every kubectl invocation.
4. Running `kubectl-mns --kubeconfig /path/to/config ns1 -- get pods` forwards `--kubeconfig /path/to/config` to every kubectl invocation.
**Plans:** TBD

### Phase 3: Tests
**Goal:** A bats-core suite at `test/kubectl-mns.bats` exercises all plugin behaviors and protects against regressions.
**Requirements:** TESTS-01, TESTS-02, TESTS-03, TESTS-04, TESTS-05, TESTS-06, TESTS-07
**Success criteria:**
1. `bats test/kubectl-mns.bats` runs without error and all tests pass.
2. The suite covers: default namespace fallback, multi-namespace iteration, `--all-namespaces` stripping, empty-args exit 1, `-h`/`--help` exit 0, and per-namespace failure continuation.
3. Tests use a kubectl stub on PATH so the suite runs in any environment without a live cluster.
**Plans:** TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Hardening | 0/3 | Not started | — |
| 2. Features | 0/1 | Not started | — |
| 3. Tests | 0/1 | Not started | — |
