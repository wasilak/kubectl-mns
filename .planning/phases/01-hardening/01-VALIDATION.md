---
phase: 1
slug: hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-21
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | shellcheck 0.11.0 + bash smoke tests (no test framework — bats is Phase 3) |
| **Config file** | none |
| **Quick run command** | `shellcheck kubectl-mns` |
| **Full suite command** | `shellcheck kubectl-mns && bash kubectl-mns; echo "exit: $?"` |
| **Estimated runtime** | ~2 seconds |

---

## Sampling Rate

- **After every task commit:** Run `shellcheck kubectl-mns`
- **After every plan wave:** Run full phase gate (see below)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~2 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | SAFETY-01 | T-1-01 | Array expansions quoted — word splitting prevented | static | `shellcheck kubectl-mns` exits 0 | ✅ | ⬜ pending |
| 01-01-02 | 01 | 1 | SAFETY-02 | T-1-01 | kubectl invoked via array — immune to glob/word-split | static | `shellcheck kubectl-mns` exits 0 | ✅ | ⬜ pending |
| 01-01-03 | 01 | 1 | SAFETY-03 | — | `-n "$data"` used — canonical and shellcheck-clean | static | `shellcheck kubectl-mns` exits 0 | ✅ | ⬜ pending |
| 01-01-04 | 01 | 1 | BUGFIX-02 | — | `namespace-2` typo fixed | manual | `grep "namespac-2" kubectl-mns` → no output | ✅ | ⬜ pending |
| 01-01-05 | 01 | 1 | BUGFIX-03 | — | usage() goes to stderr | smoke | `bash kubectl-mns 2>/dev/null` → no stdout | ✅ | ⬜ pending |
| 01-01-06 | 01 | 1 | BUGFIX-04 | — | No-args exit code is 1 | smoke | `bash kubectl-mns >/dev/null 2>&1; echo $?` → 1 | ✅ | ⬜ pending |
| 01-01-07 | 01 | 1 | BUGFIX-01 | — | README example omits redundant `kubectl` | manual | `grep "-- kubectl get" README.md` → no output | ✅ | ⬜ pending |
| 01-01-08 | 01 | 1 | SECURITY-01 | T-1-02 | Codacy action pinned to SHA, not @master | grep | `grep "@master" .github/workflows/codacy.yml` → no output | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements — no new test framework or stubs are needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README example omits redundant `kubectl` | BUGFIX-01 | String match sufficient | `grep "-- kubectl get" README.md` returns 0 matches |
| Typo corrected in usage() | BUGFIX-02 | String match sufficient | `grep "namespac-2" kubectl-mns` returns 0 matches |

---

## Full Phase Gate

Run before closing Phase 1:
```bash
shellcheck kubectl-mns
grep "namespac-2" kubectl-mns        # expect no output
grep "@master" .github/workflows/codacy.yml  # expect no output
bash kubectl-mns >/dev/null 2>&1; echo "exit: $?"    # expect: exit: 1
bash kubectl-mns 2>/dev/null         # expect: no stdout output
grep "-- kubectl get" README.md      # expect no output
```

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
