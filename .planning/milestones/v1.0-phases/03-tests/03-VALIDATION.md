---
phase: 3
slug: tests
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-22
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bats-core 1.x |
| **Config file** | `test/kubectl-mns.bats` (created in Wave 1) |
| **Quick run command** | `bats test/kubectl-mns.bats` |
| **Full suite command** | `bats test/kubectl-mns.bats` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bats test/kubectl-mns.bats`
- **After every plan wave:** Run `bats test/kubectl-mns.bats`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 1 | TESTS-01..07 | — | N/A | bats | `bats test/kubectl-mns.bats` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 2 | TESTS-01..07 | — | N/A | bats | `bats test/kubectl-mns.bats` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `brew install bats-core` (or equivalent) available on executor PATH
- [ ] `test/` directory created

*Alternatively: bats installed in CI via `bats-core/bats-action@4.0.0`*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CI workflow executes on push | — | Requires a git push to trigger | Push branch and verify `Actions > tests` passes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
