# Requirements — Milestone v1.0 Foundation & Quality

_Created: 2026-06-21_

## SAFETY — Shell Safety

- [ ] **SAFETY-01**: Plugin quotes all array expansions (`"${namespaces[@]}"`, `"${actual_kubectl_args[@]}"`)
- [ ] **SAFETY-02**: kubectl is invoked via bash array, not string concatenation
- [ ] **SAFETY-03**: Data presence check uses `-n "$data"` instead of `! -z $data`

## BUGFIX — Bug Fixes

- [ ] **BUGFIX-01**: README usage example omits redundant `kubectl` after `--`
- [ ] **BUGFIX-02**: `usage()` displays `namespace-2` (typo: was `namespac-2`)
- [ ] **BUGFIX-03**: `usage()` output goes to stderr instead of stdout
- [ ] **BUGFIX-04**: Plugin exits with code 1 when invoked with no args (was: 0)

## SECURITY — CI Security

- [ ] **SECURITY-01**: Codacy GitHub Action pinned to a commit SHA (not `@master`)

## ERRORS — Error Handling

- [ ] **ERRORS-01**: Per-namespace kubectl failure is caught; script continues and reports error to stderr

## OUTPUT — Output UX

- [ ] **OUTPUT-01**: Namespace label printed before each output block (`=== namespace: <ns> ===`)

## ARGS — Argument Handling

- [ ] **ARGS-01**: `--context <ctx>` accepted before `--` and forwarded to every kubectl call
- [ ] **ARGS-02**: `--kubeconfig <path>` accepted before `--` and forwarded to every kubectl call

## TESTS — Test Suite

- [ ] **TESTS-01**: bats-core test suite exists at `test/kubectl-mns.bats`
- [ ] **TESTS-02**: Test: no namespace given → defaults to `default`
- [ ] **TESTS-03**: Test: multiple namespaces → one kubectl call per namespace
- [ ] **TESTS-04**: Test: `--all-namespaces` stripped from forwarded args
- [ ] **TESTS-05**: Test: empty kubectl args → exits 1 and prints usage
- [ ] **TESTS-06**: Test: `-h` / `--help` → prints usage and exits 0
- [ ] **TESTS-07**: Test: namespace failure continues to next namespace

## Future Requirements (deferred)

- Parallel namespace execution — adds output ordering complexity; sequential is intentional for now
- Release pipeline / versioning — address in v1.1
- Client-side namespace name validation (RFC 1123) — kubectl validates server-side

## Out of Scope

- `--all-namespaces` mode (stripped from args today, not added as a flag) — not requested
- Output formatting beyond namespace labels (JSON, table) — not requested
- Kubeconfig context listing / auto-discovery — out of scope for this milestone

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| SAFETY-01 | Phase 1 | Pending |
| SAFETY-02 | Phase 1 | Pending |
| SAFETY-03 | Phase 1 | Pending |
| BUGFIX-01 | Phase 1 | Pending |
| BUGFIX-02 | Phase 1 | Pending |
| BUGFIX-03 | Phase 1 | Pending |
| BUGFIX-04 | Phase 1 | Pending |
| SECURITY-01 | Phase 1 | Pending |
| ERRORS-01 | Phase 2 | Pending |
| OUTPUT-01 | Phase 2 | Pending |
| ARGS-01 | Phase 2 | Pending |
| ARGS-02 | Phase 2 | Pending |
| TESTS-01 | Phase 3 | Pending |
| TESTS-02 | Phase 3 | Pending |
| TESTS-03 | Phase 3 | Pending |
| TESTS-04 | Phase 3 | Pending |
| TESTS-05 | Phase 3 | Pending |
| TESTS-06 | Phase 3 | Pending |
| TESTS-07 | Phase 3 | Pending |
