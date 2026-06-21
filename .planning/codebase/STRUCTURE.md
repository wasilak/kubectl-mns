# Codebase Structure

**Analysis Date:** 2026-06-21

## Directory Layout

```
kubectl-mns/
├── kubectl-mns          # Main plugin script (sole executable)
├── LICENSE              # Apache 2.0 license
├── README.md            # Project documentation
├── renovate.json        # Renovate bot config for dependency updates
├── .github/
│   └── workflows/
│       ├── codacy.yml   # Codacy static analysis CI
│       └── stale.yml    # Stale issue/PR automation
├── .planning/
│   └── codebase/        # GSD codebase map documents
└── .serena/
    └── memories/        # Serena symbolic memory store
```

## Directory Purposes

**Root:**
- Purpose: Contains the entire project — a single-file bash plugin
- Contains: The executable script, license, readme, and config files
- Key files: `kubectl-mns`

**.github/workflows/:**
- Purpose: GitHub Actions CI pipelines
- Contains: Codacy code quality analysis, stale issue management
- Key files: `.github/workflows/codacy.yml`, `.github/workflows/stale.yml`

**.planning/codebase/:**
- Purpose: GSD codebase analysis documents written by map-codebase
- Contains: ARCHITECTURE.md, CONVENTIONS.md, INTEGRATIONS.md, STACK.md, STRUCTURE.md
- Generated: Yes (by GSD tooling)
- Committed: Yes

**.serena/memories/:**
- Purpose: Serena MCP symbolic memory store for this project
- Generated: Yes
- Committed: Depends on project preference

## Key File Locations

**Entry Points:**
- `kubectl-mns`: The plugin script — entry point when invoked as `kubectl mns ...`

**Configuration:**
- `renovate.json`: Renovate dependency update bot configuration

**Documentation:**
- `README.md`: Usage instructions, installation steps, examples
- `LICENSE`: Apache 2.0

**CI:**
- `.github/workflows/codacy.yml`: Static analysis via Codacy
- `.github/workflows/stale.yml`: Automated stale issue/PR management

## Naming Conventions

**Files:**
- Plugin script uses hyphen-separated lowercase: `kubectl-mns` (no extension — required by kubectl plugin convention)
- Workflow files use lowercase with hyphens: `codacy.yml`, `stale.yml`

**Functions (inside `kubectl-mns`):**
- Snake_case: `usage`, `run_kubectl`

**Variables (inside `kubectl-mns`):**
- Snake_case: `is_double_dash`, `namespaces`, `actual_kubectl_args`, `kubectl_command`

## Where to Add New Code

**New functionality:**
- All logic goes in `kubectl-mns` — add new functions, then call them from the bottom of the script
- Follow the existing pattern: define a function, call it after the argument-parsing guards at the bottom

**New CI pipeline:**
- Add a `.yml` file to `.github/workflows/`

**Helper scripts (if project grows):**
- No `scripts/` or `lib/` directory exists; if needed, create at root level and document in `README.md`

**Tests (if added):**
- No test directory exists; `test/` at root would be the natural location
- Use `bats` (Bash Automated Testing System) — the standard for bash script testing

## Special Directories

**.planning/:**
- Purpose: GSD planning and codebase map documents
- Generated: Yes (by GSD `/gsd:map-codebase` command)
- Committed: Yes

**.serena/:**
- Purpose: Serena MCP tool memory store
- Generated: Yes
- Committed: Project-dependent

**.github/:**
- Purpose: GitHub platform configuration (Actions, bots)
- Generated: No (manually maintained)
- Committed: Yes

## Project Scope Note

This is a minimal single-file project. The entire implementation is `kubectl-mns` (68 lines of bash). There are no packages, modules, build artifacts, or dependency lockfiles. Any structural expansion should remain minimal and justified.

---

*Structure analysis: 2026-06-21*
