# Phase 2: Features — Research

**Researched:** 2026-06-21
**Domain:** Bash scripting — argument parsing, error handling, output formatting
**Confidence:** HIGH

---

## Summary

Phase 2 adds four behaviours to the `kubectl-mns` bash plugin: namespace-prefixed output labels (OUTPUT-01), per-namespace error continuation (ERRORS-01), and forwarding of `--context` / `--kubeconfig` to every kubectl call (ARGS-01, ARGS-02).

All four requirements are changes to a single ~60-line bash script. No external packages are required. The entire implementation space is pure bash idiom — argument parsing before `--`, error trapping inside a loop, and echo/printf output formatting. The patterns are well-established and shellcheck-verifiable.

The current script (post-phase-1 hardening) already uses array-based kubectl exec, quoted expansions, and correct error paths. Phase 2 extends the argument parser and the per-namespace loop. No architectural restructuring is needed.

**Primary recommendation:** Implement all four requirements in a single plan touching only `kubectl-mns`. The changes are small, tightly coupled, and best reviewed together.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Argument parsing (`--context`, `--kubeconfig`) | Plugin script | — | All parsing happens in `run_kubectl()` before the loop |
| Output labelling | Plugin script | — | `printf` call injected at top of per-namespace loop body |
| Per-namespace error continuation | Plugin script | — | `set -e` must be locally overridden; `if !` pattern inside the loop |
| kubectl flag forwarding | Plugin script | — | Extra flags prepended/appended to `kubectl_cmd` array |

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ERRORS-01 | Per-namespace kubectl failure is caught; script continues and reports error to stderr | WR-01 in 01-REVIEW.md already documents the exact fix: `if ! data=...` + `continue` pattern |
| OUTPUT-01 | Namespace label printed before each output block (`=== namespace: <ns> ===`) | Simple `printf` before the kubectl call in the loop |
| ARGS-01 | `--context <ctx>` accepted before `--` and forwarded to every kubectl call | Argument parser loop extended to capture flag + value pairs |
| ARGS-02 | `--kubeconfig <path>` accepted before `--` and forwarded to every kubectl call | Same parser extension as ARGS-01 |
</phase_requirements>

---

## Standard Stack

### Core

No external packages. This is a bash-only implementation.

| Tool | Version | Purpose | Source |
|------|---------|---------|--------|
| bash | ≥4 (shebang: `#!/usr/bin/env bash`) | Script runtime | Pre-installed on all target platforms |
| shellcheck | current | Static analysis — verify no new SC violations introduced | Already used in Phase 1 |
| kubectl | any | The command being wrapped | Pre-installed on user's machine |

### No Packages Required

This phase installs zero external packages. The Package Legitimacy Audit section is omitted.

---

## Architecture Patterns

### System Architecture Diagram

```
User invocation
    │
    ▼
[ Argument parser loop ]
    │  reads "$@" one token at a time
    │  ── before "--" ──────────────────────────────────────────────────────────
    │    --context <val>    ─► extra_kubectl_flags+=("--context" "$val")
    │    --kubeconfig <val> ─► extra_kubectl_flags+=("--kubeconfig" "$val")
    │    anything else      ─► namespaces+=("$item")
    │  ── after "--" ────────────────────────────────────────────────────────────
    │    --all-namespaces / -A  ─► warn >&2, skip
    │    anything else          ─► actual_kubectl_args+=("$item")
    │
    ▼
[ Per-namespace loop ]
    │  for ns in "${namespaces[@]}"; do
    │    printf '=== namespace: %s ===\n' "$ns"      ◄── OUTPUT-01
    │    kubectl_cmd=("kubectl"
    │                 "${extra_kubectl_flags[@]}"     ◄── ARGS-01 / ARGS-02
    │                 "${actual_kubectl_args[@]}"
    │                 --namespace "$ns")
    │    if ! data=$("${kubectl_cmd[@]}" 2>&1); then ◄── ERRORS-01
    │      printf 'Error: kubectl failed for namespace %s: %s\n' "$ns" "$data" >&2
    │      continue
    │    fi
    │    [[ -n "$data" ]] && printf '%s\n\n' "$data"
    │  done
    │
    ▼
  stdout (labelled output per namespace)
  stderr (errors for failed namespaces)
```

### Recommended Structure

No structural changes needed. All modifications stay within the existing single `kubectl-mns` file.

```
kubectl-mns          # single file — all changes here
```

### Pattern 1: Argument Parser — Flag + Value Capture Before `--`

**What:** When iterating `"$@"`, recognise `--context` or `--kubeconfig` as flags that consume the next token as their value.

**When to use:** Any bash script that needs to intercept specific flags from a positional argument stream before a delimiter.

**Two approaches:**

**Approach A — lookahead with index (cleanest for small flag sets):**
```bash
# [ASSUMED] standard bash idiom
i=1
while [[ $i -le $# ]]; do
  item="${!i}"
  case "$item" in
    --context|--kubeconfig)
      ((i++))
      extra_kubectl_flags+=("$item" "${!i}")
      ;;
    --)
      ((i++))
      break
      ;;
    *)
      namespaces+=("$item")
      ;;
  esac
  ((i++))
done
# remaining positional args after -- are actual_kubectl_args
while [[ $i -le $# ]]; do
  item="${!i}"
  [[ "$item" != "--all-namespaces" && "$item" != "-A" ]] && actual_kubectl_args+=("$item")
  ((i++))
done
```

**Approach B — extend the existing `for item in "$@"` loop with a "consume-next" flag:**
```bash
# [ASSUMED] minimal-change approach — preserves current loop structure
consume_next_as=""
for item in "$@"; do
  if [[ -n "$consume_next_as" ]]; then
    extra_kubectl_flags+=("$consume_next_as" "$item")
    consume_next_as=""
    continue
  fi
  if [[ "$item" == "--" ]]; then
    is_double_dash="true"
    continue
  fi
  if [[ "$is_double_dash" == "false" ]]; then
    case "$item" in
      --context|--kubeconfig)
        consume_next_as="$item"
        ;;
      *)
        namespaces+=("$item")
        ;;
    esac
  else
    [[ "$item" != "--all-namespaces" && "$item" != "-A" ]] && actual_kubectl_args+=("$item")
  fi
done
```

**Recommendation:** Approach B — it is the smallest diff from the current code (preserves the `for item in "$@"` structure and `is_double_dash` logic that already exists). This satisfies the project's "surgical changes" principle.

### Pattern 2: Per-Namespace Error Continuation (ERRORS-01)

**What:** Override `set -e` locally for the kubectl call by using an `if !` construct, which prevents `set -e` from triggering on non-zero exit while still capturing the exit status.

**Why this is needed:** The current script has `set -eo pipefail` at line 3. Inside the loop, `data=$("${kubectl_cmd[@]}")` will cause `set -e` to abort the entire script if kubectl exits non-zero. This was documented in the Phase 1 review as WR-01.

```bash
# [ASSUMED] standard bash idiom — "if !" suppresses set -e for that command
for ns in "${namespaces[@]}"; do
  printf '=== namespace: %s ===\n' "$ns"
  local kubectl_cmd=("kubectl" "${extra_kubectl_flags[@]}" "${actual_kubectl_args[@]}" --namespace "$ns")
  if ! data=$("${kubectl_cmd[@]}" 2>&1); then
    printf 'Error: kubectl failed for namespace '\''%s'\'': %s\n' "$ns" "$data" >&2
    continue
  fi
  if [[ -n "$data" ]]; then
    printf '%s\n\n' "$data"
  fi
done
```

**Key detail:** `2>&1` on the kubectl call captures stderr into `$data` so the error message is meaningful. Without it, kubectl's own error messages go to the terminal but `$data` is empty, making the logged message unhelpful.

### Pattern 3: Output Label (OUTPUT-01)

**What:** Print `=== namespace: <ns> ===` before each namespace's output block.

```bash
printf '=== namespace: %s ===\n' "$ns"
```

**Why `printf` not `echo`:** Consistent with the Phase 1 review recommendation (CR-01) — `printf` is POSIX, does not interpret escape sequences in `$ns`, and is already used elsewhere in the script after Phase 1. `echo -e` was specifically called out as a problem in CR-01.

**Placement:** Unconditionally before the kubectl call — the label is printed even if kubectl returns empty output, so the user knows the namespace was attempted.

### Pattern 4: Forwarding Extra Flags (ARGS-01, ARGS-02)

**What:** Captured `--context`/`--kubeconfig` flags are injected into the `kubectl_cmd` array before `actual_kubectl_args`.

```bash
local kubectl_cmd=("kubectl" "${extra_kubectl_flags[@]}" "${actual_kubectl_args[@]}" --namespace "$ns")
```

**Why flags before args:** kubectl accepts global flags (like `--context`, `--kubeconfig`, `--namespace`) before the subcommand. Placing `extra_kubectl_flags` first then `actual_kubectl_args` (which starts with the subcommand like `get pods`) is the correct order.

**Empty array safety:** `"${extra_kubectl_flags[@]}"` expands to nothing when the array is empty — this is safe in bash with `set -u` disabled (the current script does not use `set -u`). However, declaring the array at the top of `run_kubectl()` before the loop ensures it is always defined.

### Anti-Patterns to Avoid

- **Passing flags as a single string:** `extra_flags="--context my-ctx"` then `$extra_flags` — breaks with spaces in context names. Always use arrays.
- **Capturing kubectl stderr separately with process substitution:** Adds complexity. `2>&1` in `if ! data=$(... 2>&1)` is the idiomatic, simple approach.
- **Printing the label only when output is non-empty:** The label should appear unconditionally so users know which namespaces were iterated even when output is empty. If the label were inside `if [[ -n "$data" ]]`, a namespace with no pods would produce no output and the user would not know it was queried.
- **Using `|| true` instead of `if !`:** `data=$(cmd) || true` suppresses the exit code but also suppresses the ability to branch on failure. The `if !` form is cleaner and explicit.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Flag parsing | Custom tokeniser | Standard bash `case` statement in the existing `for` loop |
| Error suppression with `set -e` active | Subshell tricks, `trap ERR` | `if ! cmd` idiom — suppresses `set -e` for exactly one command |
| Output labelling | Complex formatting | Single `printf` call |

**Key insight:** Every requirement in this phase is a 1-5 line bash change. There is no library, no tool, no abstraction needed beyond what bash provides.

---

## Common Pitfalls

### Pitfall 1: `set -e` Aborts Loop on First kubectl Failure

**What goes wrong:** Without `if !`, a failing kubectl call (e.g., namespace not found, RBAC denied) causes `set -e` to abort the script immediately. The remaining namespaces are never processed, with no error message.

**Why it happens:** `set -eo pipefail` is active at script level. Command substitution `data=$(cmd)` propagates the exit code to the enclosing scope, triggering `set -e`.

**How to avoid:** Use `if ! data=$("${kubectl_cmd[@]}" 2>&1); then` — the `if` construct explicitly tests the exit code, which prevents `set -e` from triggering.

**Warning signs:** Testing with a non-existent namespace causes script to exit silently without iterating remaining namespaces.

---

### Pitfall 2: Flag Value Consumed as Namespace Name

**What goes wrong:** If `--context` is parsed without consuming the next token, the value (e.g., `my-ctx`) falls through to `namespaces+=("$item")` and is treated as a namespace name.

**Why it happens:** The current parser has a single `else` branch for pre-`--` tokens — anything that is not a known flag becomes a namespace.

**How to avoid:** The `consume_next_as` approach (Pattern 1, Approach B) must be checked first, before the `is_double_dash` branch. Order in the `for` loop matters.

**Warning signs:** kubectl is called with `--namespace my-ctx` instead of `--context my-ctx --namespace ns1`.

---

### Pitfall 3: Empty `extra_kubectl_flags` Array Causes SC2086 or `set -u` Error

**What goes wrong:** If `extra_kubectl_flags` is declared but the array is empty, `"${extra_kubectl_flags[@]}"` can cause a `set -u` error in strict scripts, or an `SC2086` warning in shellcheck.

**Why it happens:** bash treats an empty array expansion differently under `set -u`. The current script does NOT use `set -u`, so this is not a runtime risk, but shellcheck may still warn.

**How to avoid:** Declare `extra_kubectl_flags=()` at the top of `run_kubectl()` alongside `namespaces=()` and `actual_kubectl_args=()`. This ensures it is always defined and shellcheck is satisfied.

**Warning signs:** `shellcheck kubectl-mns` reports SC2154 or similar after the change.

---

### Pitfall 4: Namespace Label Printed After Empty Namespace Query

**What goes wrong:** If the label is printed inside `if [[ -n "$data" ]]`, namespaces that return empty output (e.g., no pods in that namespace) produce no output at all. The user cannot tell whether the namespace was skipped, failed silently, or had no resources.

**Why it happens:** Optimising for "clean" output by hiding empty results.

**How to avoid:** Print the label unconditionally before the kubectl call. Empty output is valid and expected (e.g., `kubectl get pods` in an empty namespace). The user needs to see that the namespace was queried.

---

### Pitfall 5: Flag Order in kubectl Command Array

**What goes wrong:** `("kubectl" "${actual_kubectl_args[@]}" "${extra_kubectl_flags[@]}" --namespace "$ns")` — global flags after the subcommand. Some kubectl versions reject global flags after the subcommand verb.

**Why it happens:** Natural inclination to append new flags at the end.

**How to avoid:** Global flags (`--context`, `--kubeconfig`, `--namespace`) must come before the subcommand: `("kubectl" "${extra_kubectl_flags[@]}" "${actual_kubectl_args[@]}" --namespace "$ns")`.

---

## Code Examples

### Complete Revised `run_kubectl()` Function

This is the target state after all four requirements are implemented:

```bash
# [ASSUMED] — derives from current codebase + standard bash idioms
function run_kubectl() {
    is_double_dash="false"
    consume_next_as=""
    namespaces=()
    actual_kubectl_args=()
    extra_kubectl_flags=()

    for item in "$@"; do

      if [[ -n "$consume_next_as" ]]; then
        extra_kubectl_flags+=("$consume_next_as" "$item")
        consume_next_as=""
        continue
      fi

      if [ "--" == "$item" ]; then
        is_double_dash="true"
        continue
      fi

      if [ "false" == "$is_double_dash" ]; then
        case "$item" in
          --context|--kubeconfig)
            consume_next_as="$item"
            ;;
          *)
            namespaces+=("$item")
            ;;
        esac
      else
        if [[ "$item" != "--all-namespaces" && "$item" != "-A" ]]; then
          actual_kubectl_args+=("$item")
        fi
      fi

    done

    if [ ${#namespaces[@]} -eq 0 ]; then
      namespaces+=("default")
    fi

    if [ ${#actual_kubectl_args[@]} -eq 0 ]; then
      usage && exit 1
    fi

    for ns in "${namespaces[@]}"; do
      printf '=== namespace: %s ===\n' "$ns"
      local kubectl_cmd=("kubectl" "${extra_kubectl_flags[@]}" "${actual_kubectl_args[@]}" --namespace "$ns")
      if ! data=$("${kubectl_cmd[@]}" 2>&1); then
        printf 'Error: kubectl failed for namespace '\''%s'\'': %s\n' "$ns" "$data" >&2
        continue
      fi
      if [[ -n "$data" ]]; then
        printf '%s\n\n' "$data"
      fi
    done
}
```

**Changes from current script (minimal diff):**
1. Added `consume_next_as=""` declaration
2. Added `extra_kubectl_flags=()` declaration
3. Added `consume_next_as` check at the top of the `for` loop
4. Changed pre-`--` `else` branch to a `case` statement to capture `--context`/`--kubeconfig`
5. Also filters `-A` (already flagged in CR-01 as a gap — IN-01)
6. Added `printf '=== namespace: %s ===\n' "$ns"` before kubectl call (OUTPUT-01)
7. Changed `data=$("${kubectl_cmd[@]}")` to `if ! data=$("${kubectl_cmd[@]}" 2>&1)` with `continue` (ERRORS-01)
8. Replaced `echo -e "$data" && printf '\n'` with `printf '%s\n\n' "$data"` (fixes CR-01 from review)
9. Added `"${extra_kubectl_flags[@]}"` to `kubectl_cmd` array (ARGS-01, ARGS-02)

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `echo -e "$data"` for output | `printf '%s\n\n' "$data"` | Verbatim output, POSIX-safe |
| `set -e` kills loop on kubectl failure | `if ! data=$(cmd 2>&1)` | Continues to next namespace |
| No output labels | `printf '=== namespace: %s ===\n'` before kubectl | User sees which namespace each block belongs to |
| No `--context`/`--kubeconfig` forwarding | `consume_next_as` parser + `extra_kubectl_flags` array | Supports multi-cluster/kubeconfig usage |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `if ! data=$(cmd 2>&1)` suppresses `set -e` for the kubectl call | Patterns 1 & 2, Pitfall 1 | Low — this is a fundamental bash behaviour; any bash ≥3.2 behaves this way |
| A2 | `"${empty_array[@]}"` expands to nothing (not an error) when `set -u` is not active | Pitfall 3 | Low — the current script does not use `set -u`; confirmed by reading script line 3 |
| A3 | kubectl accepts global flags (`--context`, `--kubeconfig`) before the subcommand | Pitfall 5 | Low — kubectl flag ordering is documented kubectl convention; `--namespace` already uses this position in current code |
| A4 | The `consume_next_as` approach handles a missing value for `--context` gracefully | Pattern 1 | Medium — if the user writes `kubectl-mns --context -- get pods` (flag with no value before `--`), `--` gets consumed as the context value; a guard `[[ "$item" == "--" ]]` check before consuming would prevent this edge case |

---

## Open Questions (RESOLVED)

1. **What happens when `--context` has no value (e.g., `--context --`)?**
   - What we know: The `consume_next_as` pattern consumes the next token blindly.
   - What's unclear: Should the parser detect this as an error?
   - Recommendation: Out of scope for this phase; add a `[[ "$item" == "--" ]]` guard inside the consume block to detect and error-exit if desired. Phase 2 does not require defensive parsing of malformed input.

2. **Should the namespace label be printed even when kubectl fails for that namespace?**
   - What we know: The success criteria says to print the label before each block; ERRORS-01 says to print an error to stderr and continue.
   - What's unclear: Should the label appear on stdout even when the output is an error?
   - Recommendation: Yes — print the label unconditionally before the kubectl call. The error goes to stderr; the label goes to stdout. They are independent streams. This is consistent with the success criterion wording ("prints `=== namespace: ns1 ===` ... before each block of output").

---

## Environment Availability

Step 2.6: SKIPPED — phase is code-only changes to a bash script. No external tools beyond `shellcheck` (already available, confirmed in Phase 1) are required.

---

## Validation Architecture

`workflow.nyquist_validation` is not set to false in `.planning/config.json` — validation section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bats-core (Phase 3 will install; not yet available) |
| Config file | none — Phase 3 |
| Quick run command | `shellcheck kubectl-mns` (available now) |
| Full suite command | `bats test/kubectl-mns.bats` (Phase 3) |

### Phase 2 Verification Strategy

Phase 3 will write the full bats suite. For Phase 2, validation is via `shellcheck` (zero warnings) and manual invocation patterns using a kubectl stub or `command -v kubectl`.

**Minimal smoke tests for the plan's acceptance criteria (manual or inline bash):**

```bash
# Stub kubectl for testing without a live cluster
kubectl() {
  case "$3" in
    ns1) echo "pod1 running" ;;
    ns2) return 1 ;;          # simulate failure
  esac
}
export -f kubectl

# Test OUTPUT-01: labels appear
bash kubectl-mns ns1 ns2 -- get pods | grep '=== namespace:'

# Test ERRORS-01: continues past ns2 failure
bash kubectl-mns ns1 ns2 -- get pods; echo "exit: $?"

# Test ARGS-01
bash kubectl-mns --context my-ctx ns1 -- get pods
# expect: kubectl called with --context my-ctx

# Test ARGS-02
bash kubectl-mns --kubeconfig /tmp/cfg ns1 -- get pods
# expect: kubectl called with --kubeconfig /tmp/cfg
```

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command |
|--------|----------|-----------|-------------------|
| OUTPUT-01 | Label printed before each namespace block | smoke | `shellcheck kubectl-mns` (static) + manual kubectl stub |
| ERRORS-01 | Script continues after namespace failure, error to stderr | smoke | Manual kubectl stub (see above) |
| ARGS-01 | `--context` forwarded to every kubectl call | smoke | Manual kubectl stub |
| ARGS-02 | `--kubeconfig` forwarded to every kubectl call | smoke | Manual kubectl stub |

**Note:** All four requirements will be covered by the bats suite in Phase 3 (TESTS-03, TESTS-07, and new cases). Phase 2 must pass `shellcheck` clean as the minimum automated gate.

### Wave 0 Gaps

- No test infrastructure exists yet — Phase 3 creates it.
- Phase 2 plan must include: `shellcheck kubectl-mns` as the verification step after changes.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Control |
|---------------|---------|---------|
| V5 Input Validation | yes | Namespace names and flag values pass through to kubectl via array exec — no shell expansion risk because array exec is used (already hardened in Phase 1) |
| V2 Authentication | no | kubectl handles authentication externally |
| V6 Cryptography | no | N/A |

### Known Threat Patterns

| Pattern | STRIDE | Mitigation |
|---------|--------|------------|
| Malicious namespace name with spaces/special chars | Tampering | Array exec `"${kubectl_cmd[@]}"` (already in place from Phase 1) — no word-splitting possible |
| Malicious `--context` value with shell metacharacters | Tampering | Same array exec path — value stored in array element, never interpolated into a string |
| `--kubeconfig` pointing to attacker-controlled file | Elevation | Out of scope — plugin trusts the invoking user's input; kubectl itself validates the kubeconfig file |

**No new security surface is introduced.** The `extra_kubectl_flags` array follows the same array-exec path as `actual_kubectl_args`. The trust model is unchanged: the plugin trusts its invoker.

---

## Sources

### Primary (HIGH confidence)
- Codebase: `kubectl-mns` (read directly) — current script state confirmed post-Phase-1
- Codebase: `.planning/phases/01-hardening/01-REVIEW.md` — WR-01 documents exactly the error-continuation fix needed for ERRORS-01

### Secondary (MEDIUM confidence)
- Bash manual (training knowledge): `if ! cmd` suppresses `set -e`; array expansion behaviour with empty arrays under no `set -u`

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no packages; pure bash
- Architecture: HIGH — all changes are in one well-understood file; patterns are elementary bash idioms
- Pitfalls: HIGH — Pitfall 1 (set -e interaction) is directly documented in the Phase 1 review

**Research date:** 2026-06-21
**Valid until:** Indefinite — bash idioms are stable; no external dependencies
