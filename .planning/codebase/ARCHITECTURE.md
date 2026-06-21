# Architecture

_Generated: 2026-06-21_

## Summary

`kubectl-mns` is a single-file Bash kubectl plugin. It accepts a list of Kubernetes namespace names and a standard kubectl command (separated by `--`), then executes that kubectl command once per namespace, sequentially, printing non-empty results to stdout. There is no build step, no external runtime dependency beyond `bash` and `kubectl`.

---

## System Overview

```text
User invokes:
  kubectl mns <ns1> [ns2 ...] -- <kubectl subcommand> [args...]
       │
       ▼
kubectl plugin discovery (PATH lookup for binary named "kubectl-mns")
       │
       ▼
  ┌───────────────────────────────────────┐
  │  kubectl-mns  (bash script)           │
  │                                       │
  │  1. Guard clauses (no args / -h)      │
  │         │                             │
  │         ▼                             │
  │  2. run_kubectl "$@"                  │
  │     ├── parse args → namespaces[]     │
  │     │               actual_kubectl_args[]
  │     ├── default namespace = "default" │
  │     │   (when no namespaces given)    │
  │     └── for ns in namespaces:         │
  │           build kubectl_command str   │
  │           execute via $()             │
  │           print non-empty output      │
  └───────────────────────────────────────┘
       │
       ▼
  stdout (raw kubectl output per namespace)
```

---

## Execution Flow (end-to-end)

### Step 1 — kubectl Plugin Discovery

kubectl looks for executables named `kubectl-<plugin>` on `$PATH`. When a user runs `kubectl mns`, kubectl resolves this to the `kubectl-mns` binary found on PATH. No registration, manifest, or config file is involved. The shebang `#!/usr/bin/env bash` ensures portability across systems where bash is not at a fixed path.

### Step 2 — Guard Clauses (lines 63–65)

Before delegating to `run_kubectl`, three top-level guards handle early exits:

| Condition | Action |
|-----------|--------|
| `$1` is empty | print usage, exit 0 |
| `$1` is `-h` | print usage, exit 0 |
| `$1` is `--help` | print usage, exit 0 |

### Step 3 — Argument Parsing (lines 16–35 inside `run_kubectl`)

All positional arguments are scanned in a single `for` loop. A boolean flag `is_double_dash` gates which bucket each token falls into:

- Tokens **before** `--` → appended to `namespaces[]`
- The `--` token itself → sets `is_double_dash=true`, is discarded
- Tokens **after** `--` → appended to `actual_kubectl_args[]`, **except** `--all-namespaces` which is silently stripped

### Step 4 — Defaults and Validation (lines 37–43)

- If `namespaces[]` is empty → defaults to `("default")`
- If `actual_kubectl_args[]` is empty → prints usage and exits with code 1

### Step 5 — Namespace Loop (lines 45–59)

For each namespace, a kubectl command string is assembled by string concatenation:

```bash
kubectl_command="kubectl"
for command_arg in ${actual_kubectl_args[@]}; do
    kubectl_command+=" $command_arg"
done
kubectl_command+=" --namespace $ns"
```

The assembled string is executed via command substitution `$()`, capturing stdout. If the output is non-empty, it is printed followed by a blank line (`printf '\n'`). Empty output (no resources found) is silently skipped.

**Execution is sequential** — namespaces are processed one after another, not in parallel.

---

## Data Flow

```
argv
  │
  ├──[before --]──► namespaces[]       (bash array)
  │
  └──[after  --]──► actual_kubectl_args[]  (bash array, --all-namespaces filtered)
                          │
                    string concat → kubectl_command  (plain string)
                          │
                    $()  subshell execution → data  (string, may be empty)
                          │
                    [non-empty?] ──yes──► echo -e "$data" + printf '\n'
                                ──no───► (skip)
```

---

## kubectl Plugin Discovery

kubectl's plugin mechanism (since v1.12) is purely PATH-based:

1. User runs `kubectl <word>`.
2. kubectl checks if `kubectl-<word>` exists and is executable anywhere on `$PATH`.
3. If found, it execs the binary, passing all remaining CLI arguments as `$@`.
4. No plugin index, no `kubectl plugin install`, no manifest needed.

**Implication:** installation = copy the file to any PATH directory + `chmod +x`. There is no version negotiation or API contract with kubectl beyond argument passing.

---

## Key Design Decisions

| Decision | Detail |
|----------|--------|
| Single bash file | Zero build chain, zero dependencies beyond bash + kubectl |
| `--` separator | Cleanly splits plugin args (namespaces) from kubectl args |
| String-based command build | Simple; avoids array-exec complexity but loses word-splitting safety |
| Sequential execution | Output is predictable and interleaved-free; no parallelism |
| Silent skip on empty output | Avoids cluttering output when a namespace has no matching resources |
| Strip `--all-namespaces` | Prevents conflicting with the per-namespace `--namespace` flag appended later |
| `set -eo pipefail` | Exits immediately on error; pipeline failures are not silently ignored |

---

## Limitations and Constraints

**Word splitting on unquoted arrays (lines 48, 45):**
`${actual_kubectl_args[@]}` and `${namespaces[@]}` are iterated unquoted (`for item in ${array[@]}`). Arguments containing spaces will be split incorrectly. The initial parse loop on line 20 does quote `"$@"` correctly, but the reconstruction loop does not.

**No output labeling:**
Output blocks are not prefixed with the namespace name. When multiple namespaces return results, it is impossible to tell which block belongs to which namespace from stdout alone.

**No error-per-namespace handling:**
If kubectl fails for one namespace (e.g., permission denied), `set -e` causes the entire script to exit immediately. Subsequent namespaces are not processed.

**No parallelism:**
Namespaces are queried sequentially. For large namespace lists or slow API servers, total runtime is additive.

**No kubeconfig/context flag forwarding:**
There is no mechanism to pass `--context` or `--kubeconfig`; users must rely on the active kubectl context.

**README usage example error:**
README shows `kubectl mns ns1 ns2 ns3 -- kubectl get pods` (with an extra `kubectl` after `--`). The script would pass `kubectl get pods` literally to kubectl, resulting in `kubectl kubectl get pods --namespace ns1`, which fails. Correct usage is `kubectl mns ns1 ns2 -- get pods`.

---

## Error Handling

`set -eo pipefail` is set at the top. Any non-zero exit from the `kubectl` subshell will abort the script. There is no per-namespace try/catch. The `usage` function prints to stdout (not stderr) and exits 0 for help flags, exits 1 for missing kubectl args.

---

## Gaps & Unknowns

- No tests exist — correctness is not verified automatically.
- No linting of the bash script (Codacy runs analysis but results are not blocking).
- The README usage example (`-- kubectl get pods`) appears incorrect; actual correct invocation is undocumented beyond the usage string.
- Behavior when namespaces contain special characters is undefined.
