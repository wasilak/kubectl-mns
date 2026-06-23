---
phase: 01-hardening
plan: "02"
subsystem: docs
tags: [readme, bugfix, documentation]
dependency_graph:
  requires: []
  provides: [corrected-readme-usage]
  affects: []
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - README.md
decisions:
  - Remove redundant kubectl token after -- in usage example; plugin invokes kubectl internally so users must not repeat it
metrics:
  duration: "< 5 minutes"
  completed: "2026-06-21"
requirements:
  - BUGFIX-01
---

# Phase 1 Plan 02: Fix README Usage Example Summary

**One-liner:** Removed redundant `kubectl` token from README usage example — correct form is `kubectl mns ns1 ns2 ns3 -- get pods`.

## What Was Done

Fixed a one-word documentation error in README.md line 45. The usage example showed:

```sh
kubectl mns ns1 ns2 ns3 -- kubectl get pods
```

which incorrectly implied users must type `kubectl` twice. The plugin itself prepends `kubectl` when executing the command. The correct form is:

```sh
kubectl mns ns1 ns2 ns3 -- get pods
```

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Remove redundant kubectl from README usage example | 7b166bf | README.md |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

- `rg '-- kubectl get' README.md` → no matches (redundant kubectl removed)
- `rg '-- get pods' README.md` → 1 match (correct form present)
- Git diff shows exactly 1 line changed

## Known Stubs

None.

## Threat Flags

None — documentation-only change, no executable code or trust boundary involved.

## Self-Check: PASSED

- [x] README.md modified with correct content
- [x] Commit 7b166bf exists
- [x] No other files changed
