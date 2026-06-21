# Phase 2: Features — Pattern Map

**Mapped:** 2026-06-21
**Files analyzed:** 1 (single-file modification)
**Analogs found:** 1 / 1 (self-referential — the file being modified IS the only analog)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `kubectl-mns` | utility / CLI wrapper | request-response (per-namespace loop) | `kubectl-mns` (current state) | exact — self |

---

## Pattern Assignments

### `kubectl-mns` (utility, request-response)

**Analog:** `kubectl-mns` (lines 1–61, current file)

This is the only file in the project. All four requirements are surgical modifications within the existing `run_kubectl()` function. The patterns below show the current code state and exactly what must change.

---

#### Current State — Full Script (lines 1–61)

```bash
#!/usr/bin/env bash

set -eo pipefail

function usage() {
  echo "Usage" >&2
  echo "kubectl mns namespace-1 namespace-2 namespace-N -- [regular kubectl command]" >&2
  echo "" >&2
  echo "List of namespaces defaults to [default]" >&2
  echo "" >&2
  echo "kubectl mns -h | --help               : Usage of this command line" >&2
  echo "" >&2
}

function run_kubectl() {
    is_double_dash="false"
    namespaces=()
    actual_kubectl_args=()

    for item in "$@"; do
    
      if [ "--" == "$item" ]; then
        is_double_dash="true";
        continue
      fi
      
      if [ "false" == "$is_double_dash" ]; then
        namespaces+=("$item")
      else
        if [ "--all-namespaces" != "$item" ]; then
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
      local kubectl_cmd=("kubectl" "${actual_kubectl_args[@]}" --namespace "$ns")
      data=$("${kubectl_cmd[@]}")
      if [[ -n "$data" ]]; then
            echo -e "$data"
            printf '\n'
      fi
    done

}

if [ -z "$1" ]; then usage && exit 1; fi
if [ "-h" == "$1" ]; then usage && exit; fi
if [ "--help" == "$1" ]; then usage && exit; fi

run_kubectl "$@"
```

---

#### Pattern: Variable Declarations at Top of `run_kubectl()` (lines 16–18)

Current pattern — three declarations before the loop:

```bash
function run_kubectl() {
    is_double_dash="false"
    namespaces=()
    actual_kubectl_args=()
```

**Extension for Phase 2 (ARGS-01/ARGS-02):** Add two more declarations alongside these:

```bash
function run_kubectl() {
    is_double_dash="false"
    consume_next_as=""
    namespaces=()
    actual_kubectl_args=()
    extra_kubectl_flags=()
```

- `consume_next_as=""` — tracks which flag (`--context` or `--kubeconfig`) is waiting for its value
- `extra_kubectl_flags=()` — accumulates captured flag+value pairs for forwarding to kubectl
- Must be declared here (not inside the loop) so `"${extra_kubectl_flags[@]}"` is always defined

---

#### Pattern: Argument Parser Loop — `for item in "$@"` (lines 20–35)

Current structure — two branches: `--` sentinel, then pre/post-dash routing:

```bash
for item in "$@"; do

  if [ "--" == "$item" ]; then
    is_double_dash="true";
    continue
  fi
  
  if [ "false" == "$is_double_dash" ]; then
    namespaces+=("$item")        # <-- everything before -- becomes a namespace
  else
    if [ "--all-namespaces" != "$item" ]; then
      actual_kubectl_args+=("$item")
    fi
  fi

done
```

**Extension for Phase 2 (ARGS-01/ARGS-02, and also fixes IN-01 from 01-REVIEW.md):**

Insert a `consume_next_as` check at the very top of the loop body (must execute before the `--` sentinel check to avoid consuming `--` as a flag value). Change the pre-`--` `else` branch to a `case` to distinguish known flags from namespace names. Also extend the post-`--` filter to cover `-A` (IN-01):

```bash
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
```

Key ordering constraint: `consume_next_as` block must be FIRST in the loop — before the `--` check — so that a flag value of `--` is not silently consumed as a sentinel.

---

#### Pattern: Per-Namespace Loop (lines 45–52)

Current structure — array exec then echo:

```bash
for ns in "${namespaces[@]}"; do
  local kubectl_cmd=("kubectl" "${actual_kubectl_args[@]}" --namespace "$ns")
  data=$("${kubectl_cmd[@]}")
  if [[ -n "$data" ]]; then
        echo -e "$data"
        printf '\n'
  fi
done
```

**Extension for Phase 2 (OUTPUT-01, ERRORS-01, ARGS-01/ARGS-02):**

Three changes in the loop body:

1. **OUTPUT-01** — add `printf '=== namespace: %s ===\n' "$ns"` unconditionally before the kubectl call (before the `if !` block, not inside it)
2. **ARGS-01/ARGS-02** — prepend `"${extra_kubectl_flags[@]}"` to `kubectl_cmd` array, before `actual_kubectl_args`
3. **ERRORS-01** — replace bare `data=$(cmd)` with `if ! data=$(cmd 2>&1)` to prevent `set -e` from aborting the loop on a failing namespace

```bash
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

Flag ordering constraint: `"${extra_kubectl_flags[@]}"` before `"${actual_kubectl_args[@]}"` — kubectl requires global flags (`--context`, `--kubeconfig`, `--namespace`) before the subcommand verb (e.g., `get pods`).

---

#### Pattern: Output Formatting — `printf` over `echo -e` (line 49, from 01-REVIEW.md CR-01)

Current (buggy):
```bash
echo -e "$data"
printf '\n'
```

Correct (already established in Phase 1 review):
```bash
printf '%s\n\n' "$data"
```

`printf '%s\n\n'` prints content verbatim — no escape-sequence interpretation, one call instead of two, POSIX-safe. This is the established project pattern for all output after Phase 1. Do not introduce `echo -e` anywhere.

---

## Shared Patterns

### Array-Based Command Execution
**Source:** `kubectl-mns` lines 46–47 (current)
**Apply to:** The per-namespace loop's kubectl invocation
```bash
local kubectl_cmd=("kubectl" "${actual_kubectl_args[@]}" --namespace "$ns")
data=$("${kubectl_cmd[@]}")
```
This is the hardened pattern from Phase 1 — arguments in an array, expanded with `"${array[@]}"`. Never concatenate flags into a string. `extra_kubectl_flags` follows this same array pattern.

### Error Output to stderr
**Source:** `kubectl-mns` lines 6–13 (usage function), 01-REVIEW.md WR-01
**Apply to:** All error messages in the per-namespace loop
```bash
echo "..." >&2
```
All diagnostic output (errors, warnings) goes to `>&2`. The pattern is already used by `usage()`. ERRORS-01's error message must follow this convention.

### `set -e` Suppression via `if !`
**Source:** 01-REVIEW.md WR-01 (explicit fix documented there)
**Apply to:** The kubectl call inside the per-namespace loop
```bash
if ! data=$("${kubectl_cmd[@]}" 2>&1); then
  # handle error
  continue
fi
```
`set -eo pipefail` is active at line 3. The `if !` construct is the only idiomatic way to test exit status without triggering `set -e`. `|| true` is not used in this codebase and is inferior (cannot branch on failure). `2>&1` is required to capture kubectl's stderr error message into `$data` for the error log.

---

## No Analog Found

No files in this project lack an analog. There is only one file (`kubectl-mns`), and all Phase 2 changes are modifications within it. The RESEARCH.md patterns are sufficient for all four requirements — they are elementary bash idioms, not novel patterns.

---

## Complete Target State (for planner reference)

The revised `run_kubectl()` function after all four requirements are applied:

```bash
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

**Diff summary (9 line-level changes):**
1. `consume_next_as=""` — new declaration (ARGS-01/02)
2. `extra_kubectl_flags=()` — new declaration (ARGS-01/02)
3. `consume_next_as` consume block — new block at top of loop (ARGS-01/02)
4. Pre-`--` branch: `namespaces+=` replaced with `case` statement (ARGS-01/02)
5. Post-`--` filter: adds `-A` to the exclusion (fixes IN-01)
6. `printf '=== namespace: %s ===\n' "$ns"` — new line before kubectl call (OUTPUT-01)
7. `local kubectl_cmd=(...)` — `"${extra_kubectl_flags[@]}"` inserted before `"${actual_kubectl_args[@]}"` (ARGS-01/02)
8. `data=$(...)` → `if ! data=$(... 2>&1)` with error branch + `continue` (ERRORS-01)
9. `echo -e "$data" && printf '\n'` → `printf '%s\n\n' "$data"` (fixes CR-01)

---

## Metadata

**Analog search scope:** `/Users/piotrek/git/kubernetes/kubectl-mns/` (entire repository)
**Files scanned:** 1 source file (`kubectl-mns`), 2 planning docs (`01-REVIEW.md`, `02-RESEARCH.md`)
**Pattern extraction date:** 2026-06-21
