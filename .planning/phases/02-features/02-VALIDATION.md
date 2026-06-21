---
phase: 2
slug: features
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-21
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bats-core (Phase 3 installs); shellcheck available now |
| **Config file** | none — Wave 0 not applicable (shellcheck is pre-installed) |
| **Quick run command** | `shellcheck kubectl-mns` |
| **Full suite command** | `shellcheck kubectl-mns && bash -c 'source ./test-helpers.sh 2>/dev/null; echo OK'` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `shellcheck kubectl-mns`
- **After every plan wave:** Run `shellcheck kubectl-mns`
- **Before `/gsd:verify-work`:** Full shellcheck must be clean + manual smoke tests pass
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 2-01-01 | 01 | 1 | OUTPUT-01 | — | N/A | manual | `shellcheck kubectl-mns` | ✅ | ⬜ pending |
| 2-01-02 | 01 | 1 | ERRORS-01 | — | non-zero exit per-namespace must not abort loop | manual | `shellcheck kubectl-mns` | ✅ | ⬜ pending |
| 2-01-03 | 01 | 1 | ARGS-01 | — | N/A | manual | `shellcheck kubectl-mns` | ✅ | ⬜ pending |
| 2-01-04 | 01 | 1 | ARGS-02 | — | N/A | manual | `shellcheck kubectl-mns` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing `kubectl-mns` file is the only artifact. No framework install needed for shellcheck.

*Existing infrastructure covers all phase requirements (shellcheck is pre-installed).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `=== namespace: ns1 ===` label printed before each block | OUTPUT-01 | bats not installed until Phase 3 | Run `kubectl-mns ns1 ns2 -- get pods` with kubectl stub; grep output for `=== namespace:` |
| Non-zero kubectl exit continues loop | ERRORS-01 | bats not installed until Phase 3 | Run with a stub that returns 1 for ns2; verify ns1 output still appears and error goes to stderr |
| `--context my-ctx` forwarded to kubectl | ARGS-01 | bats not installed until Phase 3 | Run `kubectl-mns --context my-ctx ns1 -- get pods`; verify kubectl receives `--context my-ctx` |
| `--kubeconfig /path` forwarded to kubectl | ARGS-02 | bats not installed until Phase 3 | Run `kubectl-mns --kubeconfig /path ns1 -- get pods`; verify kubectl receives `--kubeconfig /path` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-21
