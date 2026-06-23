# Milestones

## v1.0 Foundation & Quality — Shipped 2026-06-23

**Status:** SHIPPED
**Started:** 2026-06-21
**Completed:** 2026-06-22
**Archived:** 2026-06-23
**Phases:** 3 | **Plans:** 5 | **Tasks:** 11
**Timeline:** 4 days (2026-06-19 → 2026-06-22)
**Commit range:** b8e1546 → 8c7d62f (50 commits, 5225 insertions / 79 deletions across 35 files)
**Non-planning files modified:** 5 (`kubectl-mns`, `README.md`, `codacy.yml`, `tests.yml`, `kubectl-mns.bats`)
**Code:** plugin 88 LOC bash | test suite 142 LOC bats (8 tests, 0 failures)
**Git tag:** `v1.0`

### Delivered

A hardened, regression-protected kubectl-mns plugin with shell-safe execution, per-namespace error continuation, global-flag forwarding, and a territory-clean CI pipeline.

### Key accomplishments

1. **Shell hardening** — array-based kubectl exec (`"${kubectl_cmd[@]}"`), quoted array expansions, `-n "$data"` check; ShellCheck exits 0 with zero diagnostics (SAFETY-01..03, BUGFIX-02..04)
2. **Documentation & exit-code fixes** — README usage example corrected (no redundant `kubectl` after `--`); `usage()` typo `namespac-2` → `namespace-2`; usage sent to stderr; no-args exit code flipped to 1 (BUGFIX-01, BUGFIX-02..04)
3. **CI supply-chain hardening** — Codacy GitHub Action pinned from mutable `@master` to verified commit SHA `d433603627...` (corresponds to tag v4.4.7) (SECURITY-01)
4. **Plugin feature set** — per-namespace output labels (`=== namespace: <ns> ===`), continue-on-failure with live stderr passthrough, `--context` / `--kubeconfig` forwarding via `consume_next_as` state machine, post-loop guard for dangling flags (ERRORS-01, OUTPUT-01, ARGS-01, ARGS-02)
5. **Test suite & CI** — 8 bats tests via kubectl PATH stub (no live cluster needed), SHA-pinned GitHub Actions workflow running `bats test/kubectl-mns.bats` on every push and PR (TESTS-01..07)

### Archives

- `.planning/milestones/v1.0-ROADMAP.md`
- `.planning/milestones/v1.0-REQUIREMENTS.md`
- `.planning/milestones/v1.0-phases/` (3 phase directories)

### Known deferred items

None. No deferred items at close. Deferred requirements (parallel execution, release pipeline, RFC 1123 validation) are carry-forward candidates for v1.1, not unfinished work.

### Known gaps

None. All 19 requirements shipped and verified against project summaries.