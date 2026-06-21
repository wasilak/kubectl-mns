# kubectl-mns

## What This Is

A kubectl plugin that runs any kubectl command across multiple namespaces in a single invocation. Users specify a list of namespaces and a kubectl command separated by `--`; the plugin executes the command in each namespace and prints the results sequentially. It is a single bash script installed on `$PATH` as `kubectl-mns`.

## Core Value

Run one kubectl command across many namespaces without typing it multiple times — the output is clearly labeled per namespace so users can immediately see where results come from.

## Current Milestone: v1.0 Foundation & Quality

**Goal:** Fix all known bugs, improve plugin UX, and add test coverage to protect against regressions.

**Target features:**
- Shell safety fixes (issue #9): quoted arrays, array-based exec
- Bug fixes: README typo, usage() stderr, exit codes
- CI security: pin Codacy action to commit SHA
- Per-namespace error handling with continue-on-failure
- Namespace labels in output (`=== namespace: ns ===`)
- `--context` / `--kubeconfig` forwarding
- bats-core test suite

## Requirements

### Validated

*Validated in Phase 01 (hardening):*
- [x] Array expansions are quoted: `"${namespaces[@]}"`, `"${actual_kubectl_args[@]}"`
- [x] kubectl is invoked via array, not string concatenation
- [x] `$data` check uses `-n "$data"` instead of `! -z $data`
- [x] README usage example does not include redundant `kubectl` after `--`
- [x] `usage()` typo fixed: `namespace-2` (was `namespac-2`)
- [x] `usage()` output goes to stderr
- [x] Exit code is 1 when invoked with no args (was 0)
- [x] Codacy GitHub Action is pinned to a commit SHA

### Active
- [ ] Per-namespace failure is caught: script continues, error reported to stderr
- [ ] Namespace label printed before each output block: `=== namespace: <ns> ===`
- [ ] `--context <ctx>` accepted before `--` and forwarded to kubectl
- [ ] `--kubeconfig <path>` accepted before `--` and forwarded to kubectl
- [ ] bats-core test suite covers: namespace defaulting, arg parsing, `--all-namespaces` stripping, error cases

### Out of Scope

- Parallel namespace execution — adds output ordering complexity; sequential is intentional for now
- Release pipeline / versioning — out of scope for v1.0; can be addressed in v1.1
- Input validation regex on namespace names — kubectl validates server-side; adding client-side validation is redundant for now

## Context

- Single-file bash plugin (68 lines), no build system, no dependencies beyond bash and kubectl
- GitHub Actions: Codacy static analysis, stale issue bot
- Renovate configured but `gomod` preset has no effect (no Go code)
- Issue #9 (shell safety) opened by external contributor — valid, all points confirmed
- Codebase map available at `.planning/codebase/`

## Constraints

- **Compatibility**: Must work with `bash` (not `zsh`-specific features); `#!/usr/bin/env bash` is the target
- **Single file**: Keep the plugin as a single executable script — no lib/ or helper scripts
- **kubectl convention**: Script must be named `kubectl-mns` with no extension and be on `$PATH`

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Array-based exec over string concatenation | Eliminates word-splitting bug; args with spaces work correctly | Implemented in Phase 01 |
| Continue-on-failure per namespace | Partial results are more useful than aborting on first RBAC error | — Pending (Phase 02) |
| bats-core for tests | Standard bash testing tool; supports mocking kubectl via PATH stub | — Pending (Phase 03) |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-21 — Phase 01 (hardening) complete*
