---
phase: 02-features
plan: 01
subsystem: kubectl-mns
tags: [bash, kubectl-plugin, error-handling, flag-forwarding, output-labels]
dependency_graph:
  requires: [01-hardening/01-01]
  provides: [ERRORS-01, OUTPUT-01, ARGS-01, ARGS-02]
  affects: [kubectl-mns]
tech_stack:
  added: []
  patterns:
    - consume_next_as state variable for two-token flag parsing
    - extra_kubectl_flags array prepended before subcommand args
    - error-continuation with if ! data=$(...) and continue (no 2>&1)
    - post-success label placement (label after successful data capture)
    - post-loop consume_next_as guard for dangling flags
key_files:
  created: []
  modified:
    - kubectl-mns
decisions:
  - Label placement after successful kubectl call prevents dangling label with no data
  - No 2>&1 on kubectl call so stderr (warnings, deprecations) passes through live
  - All-fail exits 0; aggregate exit-code policy deferred to future phase
  - Post-loop guard catches dangling --context/--kubeconfig without value
metrics:
  duration: "2m"
  completed: "2026-06-22T14:54:27Z"
  tasks_completed: 2
  files_modified: 1
---

# Phase 02 Plan 01: Feature Implementation Summary

**One-liner:** Flag forwarding (`--context`, `--kubeconfig`), per-namespace output labels, live-stderr error continuation, and post-loop consume guard via `consume_next_as` and `extra_kubectl_flags` in `run_kubectl()`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend run_kubectl() with flag forwarding, post-success label, live-stderr error continuation | 2f572bf | kubectl-mns |
| 2 | Smoke-test eight behaviors with a kubectl stub | (verification only — no files committed) | — |

## What Was Built

Extended `run_kubectl()` in `kubectl-mns` with ten targeted changes per the revised plan (incorporating cross-AI review feedback):

1. Added `consume_next_as=""` state variable for two-token flag parsing
2. Added `extra_kubectl_flags=()` array for accumulating global kubectl flags
3. Inserted consume-block at top of `for item in "$@"` loop (before `--` sentinel)
4. Replaced `namespaces+=("$item")` with `case` routing `--context|--kubeconfig` to `consume_next_as`
5. Extended post-`--` filter to strip `-A` (short form) alongside `--all-namespaces`
6. Added post-loop guard: `if [[ -n "$consume_next_as" ]]; then ... exit 1; fi`
7. Prepended `extra_kubectl_flags` before `actual_kubectl_args` in `kubectl_cmd` array
8. Replaced `data=$("${kubectl_cmd[@]}")` with `if ! data=$(...); then ... continue; fi` — no `2>&1`
9. Moved namespace label `printf` to post-success path (after error check, not before)
10. Replaced `echo -e "$data"; printf '\n'` with `printf '%s\n\n' "$data"`

## Smoke Tests (Task 2)

All eight tests passed:

| Test | Scenario | Result |
|------|----------|--------|
| A | OUTPUT-01: both namespaces succeed, labels appear | PASS |
| B | ERRORS-01: ns2 fails — label suppressed, error on stderr, exit 0 | PASS |
| C | ARGS-01: --context my-ctx forwarded to every kubectl invocation | PASS |
| D | ARGS-02: --kubeconfig /tmp/cfg forwarded to kubectl | PASS |
| E | Flag ordering: --context and --kubeconfig appear before subcommand verb | PASS |
| F | Empty-data-on-success: label printed, no data block, exit 0 | PASS |
| G | All-fail: 3 error lines on stderr, stdout empty, exit 0 | PASS |
| H | Missing flag value: --context with no arg → error + exit 1 | PASS |

## Deviations from Plan

None — plan executed exactly as written. The plan already incorporated cross-AI review revisions (label placement fix, stderr conflation fix, post-loop guard).

## Threat Surface

Threat model mitigations verified:
- T-02-01/T-02-02: `--context` and `--kubeconfig` values stored in bash array elements — no string interpolation, shellcheck clean
- T-02-07: Post-loop guard (`requires a value`) implemented and verified via Test H

No new trust surface introduced beyond what the threat model covers.

## Self-Check

### Files exist:
- `kubectl-mns`: exists and modified
- `.planning/phases/02-features/02-01-SUMMARY.md`: this file

### Commits exist:
- 2f572bf: feat(02-01): add flag forwarding, post-success label, live-stderr error continuation

### Acceptance criteria verified:
- `shellcheck kubectl-mns` exits 0
- `bash -n kubectl-mns` exits 0
- `consume_next_as=""` present (count: 2 — declaration + guard)
- `extra_kubectl_flags=()` present (count: 1)
- `=== namespace:` appears exactly once in a printf call
- `if ! data=$(` present
- No `2>&1` in file
- `extra_kubectl_flags` precedes `actual_kubectl_args` in kubectl_cmd array
- `--context|--kubeconfig` case branch present
- `"-A"` in post-`--` filter
- `requires a value` present
- No `echo -e` in file
- Label placement: `if ! data=$(` on lower line than `printf '=== namespace:'`

## Self-Check: PASSED
