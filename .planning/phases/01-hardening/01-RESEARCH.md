# Phase 1: Hardening — Research

**Researched:** 2026-06-21
**Domain:** Bash scripting safety, kubectl plugin conventions, GitHub Actions supply-chain security
**Confidence:** HIGH

---

## Summary

Phase 1 is a pure hardening pass on a small (~67 line) bash kubectl plugin. There are no external
library dependencies to install, no new features, and no test framework to set up. Every
requirement maps directly to a surgical, line-level change in one of three artifacts:
`kubectl-mns` (the plugin), `README.md`, or `.github/workflows/codacy.yml`.

The issues are well-understood and confirmed by static analysis (shellcheck 0.11.0 reports
SC2068 on both unquoted array expansions) and manual code inspection. The Codacy workflow
pins the action at `@master` — a supply-chain risk that is fixed by substituting a pinned
commit SHA with an inline version comment. The README example incorrectly shows
`kubectl mns ns1 ns2 ns3 -- kubectl get pods` (redundant `kubectl` after `--`).

All eight requirements can be addressed in a single wave of edits. No package installs,
no environment probing, and no external service calls are needed.

**Primary recommendation:** Make all eight changes as a single coherent commit after a
pre-flight `shellcheck` run confirms zero errors.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SAFETY-01 | Quote all array expansions (`"${namespaces[@]}"`, `"${actual_kubectl_args[@]}"`) | SC2068 confirmed by shellcheck; fix is `"${arr[@]}"` |
| SAFETY-02 | kubectl invoked via bash array, not string concatenation | Current string-build pattern is word-split-unsafe; array invocation pattern documented below |
| SAFETY-03 | Data check uses `-n "$data"` not `! -z $data` | ShellCheck best-practice; `! -z` is double-negation, `-n` is canonical and quotes the variable |
| BUGFIX-01 | README example omits redundant `kubectl` after `--` | Line 44 of README.md: `kubectl mns ns1 ns2 ns3 -- kubectl get pods` should be `kubectl mns ns1 ns2 ns3 -- get pods` |
| BUGFIX-02 | `usage()` shows `namespace-2` (typo: was `namespac-2`) | Line 7 of plugin: `namespac-2` → `namespace-2` |
| BUGFIX-03 | `usage()` output goes to stderr | Lines 5–13: all `echo` calls in `usage()` must redirect to `>&2` |
| BUGFIX-04 | Exit code 1 when invoked with no args (was 0) | Line 63: `exit` → `exit 1` |
| SECURITY-01 | Codacy action pinned to commit SHA, not `@master` | SHA verified: `d43360362776a6789b47b99ae8973510854e2d3d` (tag v4.4.7) |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Shell safety (array quoting, array exec) | Plugin (bash script) | — | All logic lives in a single bash file |
| Bug fixes (typo, exit codes, stderr) | Plugin (bash script) | README.md | Usage typo is in the script; example bug is in docs |
| CI supply-chain hardening | GitHub Actions workflow | — | Workflow file owns action pinning |

---

## Standard Stack

### Core
This phase involves no new packages. All changes are edits to existing files.

| Tool | Version Available | Purpose | Status |
|------|-------------------|---------|--------|
| bash | system (≥4 on Linux/macOS) | Script runtime | Already in use |
| shellcheck | 0.11.0 (verified on machine) | Static analysis pre-flight | Available locally |

**No `npm install`, `pip install`, or any other package install is required for this phase.**

---

## Package Legitimacy Audit

No external packages are introduced in this phase.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
User invokes: kubectl mns <ns...> -- <kubectl-args...>
                        |
              kubectl-mns (bash plugin)
                        |
         +--------------+--------------+
         |                             |
    Parse args                    usage() → stderr
    (split on --)                  exit 1
         |
    Build cmd array: kubectl + args + --namespace $ns
         |
    for ns in "${namespaces[@]}":
         |
    Execute: "${kubectl_cmd[@]}"
         |
    Capture $data → echo if non-empty
```

### Recommended File Layout (unchanged)

```
kubectl-mns          # plugin (single bash file)
README.md            # docs (BUGFIX-01 fix here)
.github/
  workflows/
    codacy.yml       # CI security (SECURITY-01 fix here)
    stale.yml        # untouched
```

### Pattern: Bash Array Invocation

Replace string-concatenation kubectl build with an array:

**Before (unsafe):**
```bash
kubectl_command="kubectl"
for command_arg in ${actual_kubectl_args[@]}; do
  kubectl_command+=" $command_arg"
done
kubectl_command+=" --namespace $ns"
data=$($kubectl_command)
```

**After (safe — SAFETY-01 + SAFETY-02):**
```bash
local kubectl_cmd=("kubectl")
for command_arg in "${actual_kubectl_args[@]}"; do
  kubectl_cmd+=("$command_arg")
done
kubectl_cmd+=(--namespace "$ns")
data=$("${kubectl_cmd[@]}")
```

[VERIFIED: bash manual — array expansion with `"${arr[@]}"` preserves word boundaries]

### Pattern: usage() to stderr

```bash
function usage() {
  echo "Usage" >&2
  echo "kubectl mns namespace-1 namespace-2 namespace-N -- [regular kubectl command]" >&2
  echo "" >&2
  echo "List of namespaces defaults to [default]" >&2
  echo "" >&2
  echo "kubectl mns -h | --help               : Usage of this command line" >&2
  echo "" >&2
}
```

[ASSUMED] — POSIX convention for usage messages is stderr; this is widely accepted practice
but is a convention, not a standard mandated by a spec.

### Pattern: No-args guard with exit 1

**Before:**
```bash
if [ -z "$1" ]; then usage && exit; fi
```

**After (BUGFIX-04):**
```bash
if [ -z "$1" ]; then usage && exit 1; fi
```

`-h`/`--help` paths keep `exit` (exit 0 on explicit help request is correct).

### Pattern: Canonical empty-string check

**Before:**
```bash
if [[ ! -z $data ]]; then
```

**After (SAFETY-03):**
```bash
if [[ -n "$data" ]]; then
```

[VERIFIED: bash manual — `-n` tests non-zero-length string; variable must be quoted to avoid
glob expansion in `[[ ]]` (though `[[ ]]` suppresses word-splitting, quoting the variable
is still idiomatic and shellcheck-clean)]

### Pattern: GitHub Actions SHA pinning

**Before:**
```yaml
uses: codacy/codacy-analysis-cli-action@master
```

**After (SECURITY-01):**
```yaml
uses: codacy/codacy-analysis-cli-action@d43360362776a6789b47b99ae8973510854e2d3d  # v4.4.7
```

SHA `d43360362776a6789b47b99ae8973510854e2d3d` verified via GitHub API against tag `v4.4.7`.
[VERIFIED: GitHub API — `gh api repos/codacy/codacy-analysis-cli-action/git/ref/tags/v4.4.7`]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Shell static analysis | Manual code inspection | `shellcheck` (already available) | Catches SC2068 and similar issues reliably |
| SHA lookup for actions | Hardcoding guessed SHAs | `gh api repos/<owner>/<repo>/git/ref/tags/<tag>` | Gets the verified commit SHA for any release tag |

---

## Common Pitfalls

### Pitfall 1: Partial array quoting fix

**What goes wrong:** Developer quotes only one of the two unquoted array expansions (`namespaces` or `actual_kubectl_args`) and misses the other.
**Why it happens:** They appear in different loops and are easy to overlook individually.
**How to avoid:** Run `shellcheck kubectl-mns` after the fix — it will report 0 errors only when both are fixed.
**Warning signs:** shellcheck still exits 1 after the change.

### Pitfall 2: Switching to array-exec but forgetting `local`

**What goes wrong:** `kubectl_cmd` is declared without `local` inside `run_kubectl()`, leaking it to global scope.
**Why it happens:** Bash functions don't enforce local scope by default.
**How to avoid:** Use `local kubectl_cmd=(...)` at declaration site.

### Pitfall 3: `usage()` stderr redirect — `echo -e` vs `printf`

**What goes wrong:** Some of the existing `echo` calls in `usage()` might be missed or a new
`echo -e` (with flags) redirected improperly.
**Why it happens:** Mechanical redirect of `echo` calls; `echo -e` is non-portable but works on
bash/glibc systems. Since no `-e` flag is used in `usage()` currently, there's no portability
risk here — just ensure each `echo` in `usage()` gets `>&2`.
**How to avoid:** Count `echo` lines in `usage()` before and after; verify count matches (6 lines).

### Pitfall 4: `@master` SHA can drift

**What goes wrong:** Using the current `@master` SHA directly without a tag comment — next time
someone reads the workflow they don't know what version it represents.
**How to avoid:** Always add a `# v<version>` comment on the same line as the SHA.

### Pitfall 5: Help exit code regression

**What goes wrong:** Changing `exit` to `exit 1` on ALL three exit paths — including `-h`/`--help`.
**Why it happens:** Mechanical find-replace of all bare `exit` calls.
**How to avoid:** Only the no-args path (line 63) should exit 1. The `-h` and `--help` paths
should remain `exit` (which is `exit 0`). BUGFIX-04 is scoped to the no-args case only.

---

## Code Examples

### Full corrected `run_kubectl()` inner loop (SAFETY-01 + SAFETY-02)

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

This collapses three constructs (the inner `for` loop, the string build, the `! -z` check)
into a cleaner form. The `local kubectl_cmd` array is constructed in one shot, removing the
need for the inner loop entirely.

[ASSUMED] — collapsing the inner loop is a style improvement; the requirement only mandates
array exec, not loop removal. The planner should decide whether to keep the inner loop or
collapse it. Either is correct; collapsing is simpler.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `! -z $var` | `-n "$var"` | bash 3+ convention | Canonical, shellcheck-clean |
| String-built commands | Array exec `"${cmd[@]}"` | Bash best-practice since bash 4 | Immune to word-splitting and glob expansion |
| `@branch` action refs | Pinned commit SHA + tag comment | GitHub hardening guides 2021+ | Prevents supply-chain substitution attack |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Usage messages should go to stderr by convention | Architecture Patterns — usage() to stderr | If project deliberately chose stdout, BUGFIX-03 would be wrong — but REQUIREMENTS.md explicitly mandates stderr, so the requirement itself overrides convention |
| A2 | Collapsing inner `for command_arg` loop into single array construction is acceptable | Code Examples | Planner might choose to keep inner loop for readability; either approach satisfies SAFETY-02 |

---

## Open Questions (RESOLVED)

1. **`local` keyword in `run_kubectl()`**
   - What we know: `kubectl_cmd` is used only inside `run_kubectl()`.
   - What's unclear: Whether to add `local` to other existing variables (`is_double_dash`, `namespaces`, `actual_kubectl_args`, `data`) while touching the function — these are currently unscoped.
   - Recommendation: Scope changes to what the requirements ask. Add `local kubectl_cmd` for the new array. Leave existing variables as-is unless a separate requirement covers it. Avoids scope creep.

2. **`echo -e` in data output (line 56)**
   - What we know: `echo -e "$data"` uses a non-POSIX flag (`-e`) but works on bash/Linux.
   - What's unclear: Whether this should be `printf '%s\n' "$data"` for portability.
   - Recommendation: Leave `echo -e` unchanged. No requirement targets this, and changing it risks regressions with data containing `\n` sequences. Out of scope for Phase 1.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| shellcheck | Pre-flight validation | Yes | 0.11.0 | Manual inspection (weaker) |
| gh CLI | SHA lookup for SECURITY-01 | Yes | (installed) | Look up SHA on github.com manually |
| bash | Plugin runtime | Yes | system default | — |

**Missing dependencies with no fallback:** none

---

## Validation Architecture

No test framework is introduced in Phase 1 (bats-core is Phase 3). Validation is:

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SAFETY-01, SAFETY-02, SAFETY-03 | No shellcheck errors | static analysis | `shellcheck kubectl-mns` | ✅ (tool available) |
| BUGFIX-01 | README shows no redundant `kubectl` | manual review | `grep "kubectl get pods" README.md` should return 0 matches | ✅ |
| BUGFIX-02 | usage() shows `namespace-2` | manual review | `grep "namespac-2" kubectl-mns` should return 0 matches | ✅ |
| BUGFIX-03 | usage() output goes to stderr | smoke test | `bash kubectl-mns 2>/dev/null` prints nothing; `bash kubectl-mns >/dev/null` shows usage | ✅ |
| BUGFIX-04 | Exit code 1 on no args | smoke test | `bash kubectl-mns; echo $?` returns 1 | ✅ |
| SECURITY-01 | codacy.yml uses SHA not @master | grep | `grep "@master" .github/workflows/codacy.yml` returns 0 matches | ✅ |

### Phase gate

Run before closing Phase 1:
```bash
shellcheck kubectl-mns
grep "namespac-2" kubectl-mns        # expect no output
grep "@master" .github/workflows/codacy.yml  # expect no output
bash kubectl-mns; echo "exit: $?"    # expect: usage on stderr, exit: 1
bash kubectl-mns 2>/dev/null         # expect: no stdout output
```

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | Partial | Array quoting prevents word-splitting on namespace names containing spaces/special chars |
| Supply-chain (V14) | Yes | Pin third-party GitHub Actions to commit SHA |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Word-splitting on user-controlled namespace names | Tampering | `"${arr[@]}"` quoting + array exec |
| Mutable `@master` tag substitution in CI | Tampering/Elevation | Pin to commit SHA |

---

## Sources

### Primary (HIGH confidence)
- Bash manual (array expansion) — `"${arr[@]}"` semantics verified against bash.info
- shellcheck SC2068 — confirmed by running `shellcheck 0.11.0` locally [VERIFIED]
- GitHub API — `gh api repos/codacy/codacy-analysis-cli-action/git/ref/tags/v4.4.7` returned SHA `d43360362776a6789b47b99ae8973510854e2d3d` [VERIFIED]

### Secondary (MEDIUM confidence)
- POSIX convention: usage messages to stderr — widely referenced in shell scripting guides; requirement mandates this explicitly so convention is moot

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; only bash and available tools
- Architecture: HIGH — single-file script with confirmed issues from shellcheck and code inspection
- Pitfalls: HIGH — confirmed by static analysis and direct code reading
- SHA for SECURITY-01: HIGH — fetched live from GitHub API

**Research date:** 2026-06-21
**Valid until:** 2026-07-21 (SHA remains valid as long as tag v4.4.7 is not re-pointed; stable)
