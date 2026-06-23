# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Foundation & Quality

**Shipped:** 2026-06-22
**Archived / Tagged:** 2026-06-23
**Phases:** 3 | **Plans:** 5 | **Commits:** ~46 (excluding planning-only `docs/...`)

### What Was Built
- **Phase 1 — Hardening (3 plans):** Array-based kubectl exec, quoted array expansions, `-n "$data"` check, `usage()` stderr redirect, `namespace-2` typo fix, no-args exit 1, Codacy action SHA-pinned to `d433603627...` (v4.4.7)
- **Phase 2 — Features (1 plan):** Per-namespace output labels, continue-on-failure with live stderr passthrough, `--context` / `--kubeconfig` forwarding via `consume_next_as` state machine, post-loop dangling-flag guard
- **Phase 3 — Tests (1 plan):** 8 bats tests via kubectl PATH stub (no live cluster), SHA-pinned GitHub Actions CI workflow running `bats test/kubectl-mns.bats` on push and PR

### What Worked
- **Cross-AI review before Phase 2 plan froze** caught two real bugs: label placement (was printing label even on failed call) and stderr conflation (`2>&1` swallowed kubectl warnings). Both were repaired pre-execution, saving a rework cycle.
- **Code review pass after each phase** (REVIEW.md files) found and closed all warnings; Phase 3 alone closed 4 IN-* issues + 3 WR-* warnings before tagging complete.
- **SDK-driven milestone archival** (`gsd-sdk query milestone.complete`) handled directory creation, REQUIREMENTS.md/ROADMAP.md snapshot, MILESTONES.md seed entry, and STATE.md update in one call — minimal manual bookkeeping.
- **Small, atomic commit cadence**: each task = one commit with conventional-commit scope (`fix(01-01)`, `feat(02-01)`, `feat(03-01)`). Bisectable history, clean rollback surface.
- **PATH stub for kubectl** kept the bats suite hermetic — no cluster dependency, runs in CI in seconds.

### What Was Inefficient
- **REQUIREMENTS.md traceability table was never updated during phase transitions** — it stayed "Pending" for all 19 rows for the entire milestone. PROJECT.md's Validated section became the de-facto authority, but the traceability table was a paper trail until archived. The transition flow should update REQUIREMENTS.md in lockstep with PROJECT.md.
- **ROADMAP.md progress table row for Phase 3 stayed "0/1 Not started"** even after the SUMMARY.md was written and the phase was marked complete. The transition flow didn't write the per-phase completion row, and it propagated as stale data into the archive. Minor, but it required manual correction at milestone close.
- **One plan's acceptance criterion had an off-by-one count bug** ("6 echo lines" vs the actual 7 in `usage()`) — caught in the SUMMARY deviation log, but the plan-review pass before execution should have caught it. Adds friction but harmless.
- **bats `--list` flag check** in the Phase 3 plan acceptance criteria doesn't exist in bats-core 1.13.0 on macOS. The plan was aspirational; the test suite ran fine. Still, the criteria-as-spec contract slipped here.

### Patterns Established
- **`consume_next_as` state machine** for two-token flag parsing: declare empty `consume_next_as=""`, route matched flag → set it, loop top routes the *next* token to the accumulator, post-loop guard catches dangling state. Reusable for any future two-token global flag (`--as`, `--user`, `--server`).
- **Post-success-side-effect pattern**: print labels / emit metrics only after the operation succeeds, so failures don't leave dangling headers. Generalize across any per-item output loop.
- **SHA-pinned CI**: every `uses:` line in `.github/workflows/*-*.yml` carries a full SHA + inline `# vX.Y.Z` version comment. Make this a lint rule for v1.1.
- **Per-test kubectl stub via `setup()` / `teardown()`** with `STUB_CALL_LOG` exported to children. Pattern translates to any tool that calls a binary — stub the binary, log invocations, assert on the log.

### Key Lessons
1. **Update REQUIREMENTS.md in lockstep with PROJECT.md during transitions.** A traceability table that says "Pending" for shipped work is a lie — it erodes trust in the planning artifacts and forced a manual repair at archive time.
2. **Cross-AI review is cheap and catches real bugs** — Phase 2 had two design bugs in the original plan that didn't survive an external model's read. Run review before freezing a plan, not after.
3. **Acceptance criteria should match what's actually callable**, not aspirational bats flags. The `bats --list` item wasted 5 minutes of "why doesn't this exist?" before being declared a non-issue.
4. **Per-phase code review (REVIEW.md → fix commits) finds issues automated testing won't** — 4 IN-* issues and 3 WR-* warnings in Phase 3 alone were quality nitpicks with no test failure attached. Keep the human review step.
5. **SDK-driven archival handles the mechanical work**; AI handles the judgment work (ROADMAP grouping, PROJECT evolution, extracting accomplishments from summaries). Don't try to delegate the judgment parts.

### Cost Observations
- **Model mix:** not directly tracked this milestone — execution used Sonnet-equivalent models for plan/execute, with cross-AI review dispatched externally (Phase 2 plan revised via Hermes/Codex). No Opus/Haiku usage recorded.
- **Sessions:** ~4 working sessions across 4 calendar days (2026-06-19 → 2026-06-22)
- **Notable:** All three phases used "code review → fix loop" cycles rather than executing to done in one pass. Phase 3 alone had two fix-loop rounds (REVIEW found issues → fixed → REVIEW-FIX confirmed clean). Worth the cost — no regressions introduced.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~4 | 3 | First milestone — established baseline of cross-AI plan review, per-phase code review, SDK-driven archival |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | 8 bats | N/A (bash plugin, no coverage tooling) | 1 runtime (bats-core 1.13.0, dev-only) |

### Top Lessons (Verified Across Milestones)

1. _(Single milestone so far — v1.0 lessons above carry forward for verification.)_
2. _(Adding more milestones here will surface cross-milestone patterns.)_