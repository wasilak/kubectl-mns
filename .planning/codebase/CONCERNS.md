# Codebase Concerns

**Analysis Date:** 2026-06-21

## Tech Debt

**String-based command construction instead of array exec:**
- Issue: `kubectl_command` is built as a plain string via concatenation, then executed via `$()` subshell. This is a Bash anti-pattern — it relies on word splitting to re-tokenize arguments, which breaks for any argument containing spaces or special characters.
- Files: `kubectl-mns` (lines 48–56)
- Impact: Commands with arguments containing spaces (e.g., label selectors with spaces, field selectors) silently misbehave or fail. No error is surfaced.
- Fix approach: Replace string concatenation with a proper Bash array: `kubectl_cmd=("kubectl" "${actual_kubectl_args[@]}" "--namespace" "$ns")` and execute as `"${kubectl_cmd[@]}"`.

**Unquoted array expansion in for-loops:**
- Issue: Both `${namespaces[@]}` and `${actual_kubectl_args[@]}` are expanded unquoted in `for` loops (lines 45, 48). This triggers word splitting and glob expansion on each element.
- Files: `kubectl-mns` (lines 45, 48)
- Impact: Namespace names or kubectl arguments containing spaces, `*`, `?`, or `[` characters will be split or glob-expanded, producing wrong behavior silently.
- Fix approach: Use `for ns in "${namespaces[@]}"` and `for command_arg in "${actual_kubectl_args[@]}"` (quoted).

## Known Bugs

**README usage example is incorrect:**
- Symptoms: The README instructs `kubectl mns ns1 ns2 ns3 -- kubectl get pods` (with `kubectl` repeated after `--`). This causes the script to construct and run `kubectl kubectl get pods --namespace ns1`, which fails with an unknown command error.
- Files: `README.md` (Usage section, first example)
- Trigger: Any user following the README example verbatim.
- Workaround: Correct invocation is `kubectl mns ns1 ns2 ns3 -- get pods` — omit `kubectl` after `--`.

**Typo in usage() output:**
- Symptoms: `usage()` prints `kubectl mns namespace-1 namespac-2 namespace-N` — `namespac-2` is missing the trailing `e`.
- Files: `kubectl-mns` (line 9)
- Trigger: Any invocation that prints help text (`--help`, `-h`, no args).
- Workaround: None needed functionally, but misleading for new users.

## Security Considerations

**No input validation on namespace names:**
- Risk: Namespace names passed before `--` are not validated. While kubectl itself rejects invalid names, a crafted value could potentially influence the constructed command string in unexpected ways under the current string-concatenation model.
- Files: `kubectl-mns` (lines 16–35)
- Current mitigation: `set -eo pipefail` aborts on any non-zero exit; kubectl rejects malformed names server-side.
- Recommendations: Validate namespace format with a regex (RFC 1123 DNS label) before use. Switch to array-based exec to eliminate injection surface entirely.

**`codacy/codacy-analysis-cli-action` pinned to `@master`:**
- Risk: The Codacy action in `.github/workflows/codacy.yml` uses `@master` (floating ref), not a pinned commit SHA or tag. A supply-chain compromise of that action would execute arbitrary code in the CI runner with `contents: read` and `security-events: write` permissions.
- Files: `.github/workflows/codacy.yml` (line 33)
- Current mitigation: None — the ref is unpinned.
- Recommendations: Pin to a specific commit SHA (e.g., `codacy/codacy-analysis-cli-action@<SHA>`).

## Performance Bottlenecks

**Sequential namespace execution:**
- Problem: Namespaces are queried one at a time in a blocking loop. Each kubectl call includes a full API round-trip.
- Files: `kubectl-mns` (lines 45–59)
- Cause: No parallelism; the design is intentionally sequential for output simplicity.
- Improvement path: Run kubectl calls in parallel background subshells, collect output with `wait`, then print in order. Requires output buffering per namespace to avoid interleaving.

## Fragile Areas

**`set -e` causes full abort on first namespace failure:**
- Files: `kubectl-mns` (line 3, lines 45–59)
- Why fragile: If kubectl returns non-zero for any single namespace (e.g., RBAC denial, namespace not found, network timeout), `set -e` aborts the entire script. Remaining namespaces in the list are never queried. The user gets no indication of partial failure.
- Safe modification: Wrap the per-namespace block in `|| true` or a local error handler to continue on failure while reporting the error, e.g.:
  ```bash
  data=$($kubectl_command) || { echo "Error: namespace $ns failed" >&2; continue; }
  ```
- Test coverage: None — no test suite exists.

**`usage()` prints to stdout, not stderr:**
- Files: `kubectl-mns` (lines 6–13)
- Why fragile: Usage/error output mixed with data output breaks scripted consumers that parse stdout. Exit code for `-h`/`--help` is 0, which is correct, but the exit code for "no args" is also 0 (line 63: `usage && exit`) rather than 1.
- Safe modification: Redirect `echo` in `usage()` to `>&2` and differentiate exit codes (0 for `--help`, 1 for missing args).

## Test Coverage Gaps

**No test suite of any kind:**
- What's not tested: Argument parsing, namespace defaulting, `--all-namespaces` stripping, empty output skipping, multi-namespace iteration, error behavior.
- Files: `kubectl-mns` (entire script)
- Risk: Any refactoring or fix has no regression safety net. Bugs in edge cases (spaces in args, single namespace, zero kubectl args) are undetectable without manual invocation.
- Priority: High — the entire codebase is a single untested script.
- Improvement path: Add [bats-core](https://github.com/bats-core/bats-core) tests. Mock `kubectl` with a stub script on `$PATH` during test runs.

## Missing Critical Features

**No namespace output labeling:**
- Problem: When multiple namespaces return results, stdout contains sequential blocks with no header indicating which namespace each block belongs to.
- Blocks: Makes the tool impractical for any automated parsing or human review of multi-namespace output.
- Improvement path: Print a separator line before each namespace block, e.g., `echo "=== namespace: $ns ==="`.

**No `--context` / `--kubeconfig` forwarding:**
- Problem: There is no way to specify a non-default kubeconfig or kubectl context via the plugin. Users must set the active context externally before invocation.
- Blocks: Multi-cluster workflows; the tool cannot be used declaratively in scripts targeting a specific cluster.
- Improvement path: Accept optional `--context` and `--kubeconfig` flags before `--` and forward them to every kubectl invocation.

**No release or versioning mechanism:**
- Problem: The script has no version string, no Git tags, no release artifacts. `renovate.json` includes a `gomod` rule that has no effect (no Go code exists). There is no automated release pipeline.
- Blocks: Users cannot pin to a known-good version; dependency managers cannot track it.
- Improvement path: Add a `VERSION` variable in the script header; create GitHub Releases with tagged versions; add a release workflow.

---

*Concerns audit: 2026-06-21*
