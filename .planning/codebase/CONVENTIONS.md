# Coding Conventions
_Generated: 2026-06-21_

## Summary

`kubectl-mns` is a single bash script (`kubectl-mns`) implementing a kubectl plugin. It follows basic bash scripting conventions with `set -eo pipefail` for safety, uses the `function` keyword style for function definitions, and builds kubectl commands via string concatenation. Quoting is inconsistent — arrays are expanded unquoted in several places, which is a known defect.

---

## Shebang & Safety Flags

```bash
#!/usr/bin/env bash

set -eo pipefail
```

- Uses `/usr/bin/env bash` (portable, not `/bin/bash`).
- `set -e`: exit on error.
- `set -o pipefail`: pipeline failures propagate.
- **Missing:** `set -u` (unbound variable protection) — not used, meaning unset variables silently expand to empty string.

---

## Function Style

Functions use the explicit `function` keyword:

```bash
function usage() {
  ...
}

function run_kubectl() {
  ...
}
```

- Two spaces indent inside `usage()`, four spaces inside `run_kubectl()` — inconsistent.
- No inline comments documenting function purpose or parameters.

---

## Variable Naming

| Convention | Examples |
|---|---|
| `snake_case` for locals | `is_double_dash`, `kubectl_command`, `command_arg` |
| `snake_case` for arrays | `namespaces`, `actual_kubectl_args` |
| Lowercase throughout | No uppercase locals |

All variables are local to `run_kubectl()` in practice (no `local` declarations used — all are function-scoped only because there is no other caller scope).

---

## Quoting

**Correct quoting (positional args):**
```bash
for item in "$@"; do    # quoted — correct
```

**Missing quotes (array expansions):**
```bash
for ns in ${namespaces[@]}; do           # should be "${namespaces[@]}"
for command_arg in ${actual_kubectl_args[@]}; do  # should be "${actual_kubectl_args[@]}"
```

Unquoted array expansions break on values containing spaces or special characters.

**Unquoted variable in condition:**
```bash
if [[ ! -z $data ]]; then   # $data should be quoted: [[ -n "$data" ]]
```

**Rule to follow:** Always quote array expansions with `"${array[@]}"`. Use `[[ -n "$var" ]]` instead of `[[ ! -z $var ]]`.

---

## Conditional Style

Mixed style — both `[ ]` and `[[ ]]` are used:

```bash
# Single bracket (POSIX)
if [ "--" == "$item" ]; then
if [ "false" == "$is_double_dash" ]; then
if [ ${#namespaces[@]} -eq 0 ]; then

# Double bracket (bash-specific)
if [[ ! -z $data ]]; then
```

**Rule to follow:** Since the shebang is `bash`, standardize on `[[ ]]` throughout.

---

## Output Format

- Usage messages go to stdout via `echo`.
- kubectl output is captured, checked for emptiness, then printed with `echo -e` followed by a blank line via `printf '\n'`:

```bash
data=$($kubectl_command)
if [[ ! -z $data ]]; then
    echo -e "$data"
    printf '\n'
fi
```

- `echo -e` enables escape sequence interpretation — relevant if kubectl output contains `\n` etc.
- Empty results are silently suppressed (no "no output" message).

---

## Command Construction

kubectl commands are built via string concatenation (not arrays):

```bash
kubectl_command="kubectl"
for command_arg in ${actual_kubectl_args[@]}; do
  kubectl_command+=" $command_arg"
done
kubectl_command+=" --namespace $ns"
data=$($kubectl_command)
```

This pattern is fragile for arguments containing spaces. The idiomatic bash approach is to use an array and expand with `"${cmd_array[@]}"`.

---

## Exit Codes

- `exit 1` on missing kubectl args (after printing usage).
- `exit` (no code) on `-h`/`--help` — exits with code `0`.
- `set -e` causes the script to exit on any kubectl command failure.

---

## Argument Parsing

No `getopts` — manual iteration over `"$@"` with a `--` separator:

```bash
for item in "$@"; do
  if [ "--" == "$item" ]; then
    is_double_dash="true"
    continue
  fi
  ...
done
```

`--all-namespaces` is explicitly stripped from kubectl args (silently ignored):
```bash
if [ "--all-namespaces" != "$item" ]; then
  actual_kubectl_args+=("$item")
fi
```

---

## Gaps & Unknowns

- No `local` declarations — not a bug given the structure, but non-idiomatic.
- No `.editorconfig`, `.shellcheckrc`, or formatting config present.
- Indentation is inconsistently 2 or 4 spaces — no enforced standard.
- `echo -e` portability: works in bash but discouraged by POSIX; `printf` would be more portable.
