# Roadmap — kubectl-mns

## Milestones

- ✅ **v1.0 Foundation & Quality** — Phases 1-3 (shipped 2026-06-22, tagged v1.0 on 2026-06-23) → [Archive](milestones/v1.0-ROADMAP.md)
- 📋 **v1.1 _(planned)_** — next milestone; define with `/gsd-new-milestone`

## Phases

<details>
<summary>✅ v1.0 Foundation & Quality (Phases 1-3) — SHIPPED 2026-06-22</summary>

- [x] Phase 1: Hardening (3/3 plans) — completed 2026-06-21
- [x] Phase 2: Features (1/1 plan) — completed 2026-06-22
- [x] Phase 3: Tests (1/1 plan) — completed 2026-06-22

See `milestones/v1.0-ROADMAP.md` for the full archived roadmap.

</details>

### 📋 v1.1 (planned)

_(No phases yet — run `/gsd-new-milestone` to define the next milestone scope.)_

## Backlog

Unscoped ideas deferred from v1.0 (carry-forward candidates, not commitments):

- Parallel namespace execution — adds output ordering complexity; sequential is intentional for now
- Release pipeline / versioning (Hombrew tap, krew index, GitHub Releases with auto-generated notes)
- Client-side namespace name validation (RFC 1123) — kubectl validates server-side today
- Aggregate exit-code policy — exit non-zero when all namespaces fail (currently always exits 0)
- `--all-namespaces` as a first-class mode (today stripped from args, not a flag)
- Output formatting beyond namespace labels (JSON, table)

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Hardening | v1.0 | 3/3 | Complete | 2026-06-21 |
| 2. Features | v1.0 | 1/1 | Complete | 2026-06-22 |
| 3. Tests | v1.0 | 1/1 | Complete | 2026-06-22 |

---
_Last updated: 2026-06-23 — v1.0 milestone archived and tagged; awaiting next milestone definition._