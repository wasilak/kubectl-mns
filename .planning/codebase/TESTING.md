# Testing Patterns

**Analysis Date:** 2026-06-21

## Test Framework

**Runner:**
- None detected — the project is a single Bash script (`kubectl-mns`) with no test framework configured.
- Config: Not applicable

**Assertion Library:**
- None

**Run Commands:**
```bash
# No test commands defined
```

## Test File Organization

**Location:**
- No test files detected in the repository.

**Naming:**
- Not applicable

**Structure:**
```
kubectl-mns/
├── kubectl-mns    # Single shell script — no test directory
└── renovate.json
```

## Test Structure

**Suite Organization:**
- No tests exist. The project consists of a single Bash script (`kubectl-mns`) with no accompanying test suite.

**Patterns:**
- None established

## Mocking

**Framework:** None

**Patterns:**
- Not applicable — no mocking infrastructure exists.

**What to Mock:**
- If tests were added, `kubectl` CLI calls would need to be mocked (e.g., via a `kubectl` stub on `$PATH`).

**What NOT to Mock:**
- Argument parsing logic (can be tested directly)

## Fixtures and Factories

**Test Data:**
- None

**Location:**
- No fixture directory exists

## Coverage

**Requirements:** None enforced

**View Coverage:**
```bash
# Not configured
```

## Test Types

**Unit Tests:**
- Not present. The `run_kubectl` function in `kubectl-mns` parses arguments and builds `kubectl` commands — unit tests would verify namespace defaulting, `--` delimiter parsing, and `--all-namespaces` stripping.

**Integration Tests:**
- Not present. Integration tests would require a real or mocked Kubernetes cluster.

**E2E Tests:**
- Not used

## Common Patterns

**If adding tests (recommended: bats-core):**
```bash
# Install: https://github.com/bats-core/bats-core
# test/kubectl-mns.bats

@test "defaults to 'default' namespace when none given" {
  run bash kubectl-mns -- get pods
  # assert kubectl called with --namespace default
}

@test "strips --all-namespaces from kubectl args" {
  run bash kubectl-mns ns1 -- get pods --all-namespaces
  # assert --all-namespaces not passed to kubectl
}
```

**Async Testing:**
- Not applicable (synchronous Bash script)

**Error Testing:**
- Not applicable — no test framework present

## Recommendations

- Add `bats-core` for Bash unit testing (`test/kubectl-mns.bats`)
- Stub `kubectl` in `$PATH` during tests to avoid requiring a real cluster
- Key scenarios to cover:
  - No namespace given → defaults to `default`
  - Multiple namespaces → one `kubectl` call per namespace
  - `--all-namespaces` stripped from forwarded args
  - Empty `actual_kubectl_args` → prints usage and exits 1
  - `-h` / `--help` flags → prints usage and exits

---

*Testing analysis: 2026-06-21*
