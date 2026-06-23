# kubectl-mns

## What This Is

A kubectl plugin that runs any kubectl command across multiple namespaces in a single invocation. Users specify a list of namespaces and a kubectl command separated by `--`; the plugin executes the command in each namespace, labels each output block, continues past per-namespace failures with live stderr passthrough, and forwards global flags (`--context`, `--kubeconfig`) to every invocation. Single bash script installed on `$PATH` as `kubectl-mns`.

## Core Value

Run one kubectl command across many namespaces without typing it multiple times — the output is clearly labeled per namespace so users can immediately see where results come from.

## Current State

**Shipped:** v1.0 Foundation & Quality (tagged `v1.0` on 2026-06-23)

**Codebase:** single-file bash plugin (~88 LOC), no build system, no runtime dependencies beyond bash and kubectl. Test suite: 8 bats tests (142 LOC), zero failures, runs via kubectl PATH stub (no live cluster needed).

**CI:** GitHub Actions workflows — Codacy static analysis (SHA-pinned), bats test suite on every push and PR (SHA-pinned). Renovate configured (gomod preset is no-op — no Go code).

**Quality gates:** ShellCheck exits 0 with zero diagnostics. `bash -n kubectl-mns` clean. All 19 v1.0 requirements verified against phase summaries.

## Requirements

### Validated

All v1.0 requirements shipped and verified. See `milestones/v1.0-REQUIREMENTS.md` for the archived requirements with full traceability.

- ✓ SAFETY-01..03: Array quoting, array-based exec, `-n` check — v1.0
- ✓ BUGFIX-01..04: README usage example, usage() typo, stderr usage, no-args exit 1 — v1.0
- ✓ SECURITY-01: Codacy action SHA-pinned — v1.0
- ✓ ERRORS-01: Per-namespace continue-on-failure with stderr passthrough — v1.0
- ✓ OUTPUT-01: Namespace labels `=== namespace: <ns> ===` — v1.0
- ✓ ARGS-01/02: `--context` / `--kubeconfig` forwarding — v1.0
- ✓ TESTS-01..07: bats-core suite with 8 tests covering default namespace, multi-namespace iteration, `--all-namespaces` stripping, empty-args error, help flags, error continuation — v1.0

### Active

_(No active requirements — next milestone not yet defined. Run `/gsd-new-milestone`.)_

### Out of Scope

- Parallel namespace execution — adds output ordering complexity; sequential is intentional for now
- `--all-namespaces` mode (stripped from args today, not added as a flag) — not requested
- Output formatting beyond namespace labels (JSON, table) — not requested
- Kubeconfig context listing / auto-discovery — out of scope

## Next Milestone Goals

**v1.1** — not yet scoped. Carry-forward candidates from v1.0 backlog:

- Release pipeline / versioning (Hombrew tap, krew index, GitHub Releases)
- Client-side namespace name validation (RFC 1123)
- Aggregate exit-code policy (exit non-zero when all namespaces fail)
- `--all-namespaces` as a first-class mode

Define scope with `/gsd-new-milestone`.

## Context

- Single-file bash plugin (~88 LOC), no build system, no dependencies beyond bash and kubectl
- GitHub Actions: Codacy static analysis (SHA-pinned), bats test suite CI (SHA-pinned), stale issue bot
- Renovate configured but `gomod` preset has no effect (no Go code)
- Issue #9 (shell safety, opened by external contributor) — resolved in v1.0
- Codebase map available at `.planning/codebase/`

## Constraints

- **Compatibility**: Must work with `bash` (not `zsh`-specific features); `#!/usr/bin/env bash` is the target
- **Single file**: Keep the plugin as a single executable script — no lib/ or helper scripts
- **kubectl convention**: Script must be named `kubectl-mns` with no extension and be on `$PATH`

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Array-based exec over string concatenation | Eliminates word-splitting bug; args with spaces work correctly | ✓ Implemented in Phase 01 — ShellCheck clean |
| Continue-on-failure per namespace | Partial results are more useful than aborting on first RBAC error | ✓ Implemented in Phase 02 — verified via smoke tests |
| bats-core for tests | Standard bash testing tool; supports mocking kubectl via PATH stub | ✓ Implemented in Phase 03 — 8 tests, 0 failures |
| Native bats assertions (no bats-assert) | 7 tests are simple enough; fewer dependencies | ✓ Working — keeps CI minimal |
| Post-success label placement | Print `=== namespace: <ns> ===` only after successful kubectl call — prevents dangling label with no data | ✓ Good — surfaced during cross-AI review, fixed before commit |
| Live stderr passthrough (no `2>&1`) | kubectl warnings/deprecations reach the user immediately, not buffered | ✓ Good — preserves kubectl UX |
| Post-loop consume_next_as guard | Catch dangling `--context` / `--kubeconfig` without a value | ✓ Good — closes FLAG-VALUE threat T-02-07 |
| All-fail exits 0 (deferred) | Aggregate exit-code policy deferred to future phase | — Pending — candidate for v1.1 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

<details>
<summary>v1.0 milestone plan (archived)</summary>

**Goal:** Fix all known bugs, improve plugin UX, and add test coverage to protect against regressions.

**Target features:**
- Shell safety fixes (issue #9): quoted arrays, array-based exec
- Bug fixes: README typo, usage() stderr, exit codes
- CI security: pin Codacy action to commit SHA
- Per-namespace error handling with continue-on-failure
- Namespace labels in output (`=== namespace: ns ===`)
- `--context` / `--kubeconfig` forwarding
- bats-core test suite

</details>

---
*Last updated: 2026-06-23 after v1.0 milestone — shipped and tagged `v1.0`*