# Story 1.1: Dependency Check & Script Bootstrap

Status: done

## Story

As a platform engineer,
I want the script to verify all required tools are present and I'm logged in,
so that I get a clear error message instead of cryptic failures.

## Acceptance Criteria

1. **Given** the user runs `pim-me-up`, **When** fzf, jq, or az cli is not installed, **Then** the script prints which dependencies are missing and exits with code 1.

2. **Given** the user runs `pim-me-up`, **When** all dependencies are present but `az login` has not been run, **Then** the script prints "Run `az login` first" and exits with code 1.

3. **Given** the user runs `pim-me-up`, **When** all dependencies are present and `az login` is active, **Then** the script retrieves the user's object ID and proceeds to the next step.

4. **Given** the user is logged in, **When** the startup sequence runs, **Then** the current tenant/organization name is clearly displayed so the user can confirm they're in the right context.

## Tasks / Subtasks

- [x] Task 1: Create the script file `pim-me-up` with shebang and constants section (AC: all)
  - [x] 1.1: Add `#!/usr/bin/env bash` and `set -euo pipefail`
  - [x] 1.2: Define constants: `PIM_API`, `ARM_API`, color codes, fzf config strings
  - [x] 1.3: Define `DURATION_OPTIONS` array
- [x] Task 2: Implement `die()` utility function (AC: 1, 2)
  - [x] 2.1: Print colored error to stderr and exit with given code
- [x] Task 3: Implement `check_deps()` function (AC: 1)
  - [x] 3.1: Check for `fzf`, `jq`, `az`, `curl` using `command -v`
  - [x] 3.2: Collect all missing deps, report them all at once (not one at a time), exit 1
- [x] Task 4: Implement `get_user_id()` function (AC: 2, 3, 4)
  - [x] 4.1: Run `az ad signed-in-user show` to get objectId
  - [x] 4.2: If it fails, print "Run `az login` first" and exit 1
  - [x] 4.3: Extract and store `USER_ID` (objectId) from the JSON response
  - [x] 4.4: Extract and display tenant/organization name so user sees context
- [x] Task 5: Implement `gen_uuid()` and `iso_now()` utility functions (AC: n/a — needed by later stories)
  - [x] 5.1: `gen_uuid()` — read from `/proc/sys/kernel/random/uuid`, fallback to `uuidgen`
  - [x] 5.2: `iso_now()` — `date -u +%Y-%m-%dT%H:%M:%SZ`
- [x] Task 6: Implement `main()` entry point calling check_deps → get_user_id (AC: all)
  - [x] 6.1: Wire up the startup sequence
  - [x] 6.2: Make script executable (`chmod +x`)
- [x] Task 7: Manual testing of all four acceptance criteria scenarios

### Review Findings

- [x] [Review][Patch] Tenant fallback shows GUID instead of display name [pim-me-up:75-78] — fixed: reads `.tenantDisplayName // .name` + pipefail-safe capture
- [x] [Review][Patch] `gen_uuid()` fails silently if both paths unavailable [pim-me-up:85] — fixed: added `|| die` on `uuidgen` fallback
- [x] [Review][Patch] `az account show` pipe vulnerable to `pipefail` [pim-me-up:75-78] — fixed: capture to variable first
- [x] [Review][Patch] fzf `--height=~50%` requires 0.30+, no fallback [pim-me-up:25] — fixed: runtime version detection with fallback to `--height=50%`
- [x] [Review][Decision] Tenant retrieval uses Graph API instead of spec'd `az account show` — resolved: keep Graph API (better org name), fixed fallback
- [x] [Review][Defer] `USER_ID` global unsanitized for future API interpolation — deferred, address in Epic 2
- [x] [Review][Defer] macOS / bash 4.0+ version compatibility — deferred, spec explicitly defers version checking
- [x] [Review][Defer] fzf version check at startup — deferred, only `--height` flag affected and now handled

## Dev Notes

### Script File & Structure

Create a single file named `pim-me-up` at the project root. This is the only source file for the entire project — all future stories add functions to this same file.

The architecture specifies this exact function organization order:
1. Constants & configuration
2. Utility functions (`die`, `check_deps`, `get_user_id`, `gen_uuid`, `iso_now`)
3. API functions (later stories)
4. Display formatting (later stories)
5. UI flow functions (later stories)
6. Activation orchestration (later stories)
7. `main()`

**Follow this order exactly.** Place section comment headers so future stories know where to insert their functions.

### Constants Section

```bash
PIM_API="https://api.azrbac.mspim.azure.com"
ARM_API="https://management.azure.com"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# fzf configuration
FZF_COMMON="--height=~50% --border --margin=1,2"
FZF_SINGLE="$FZF_COMMON --no-multi"
FZF_MULTI="$FZF_COMMON --multi --bind='space:toggle,ctrl-a:toggle-all'"
```

### Dependency Check Details

- Required dependencies: `bash` (4.0+), `fzf` (0.20+), `jq` (1.5+), `az` (2.40+), `curl`
- Use `command -v <tool>` to check presence — do NOT check versions in this story (keep it simple)
- Collect ALL missing deps before reporting — don't exit on the first missing one
- Output format: `"Missing required dependencies: fzf, jq"` (comma-separated list)

### Login Check Details

- `az ad signed-in-user show` returns JSON with the user's `id` (objectId) if logged in
- If not logged in, az cli returns non-zero — catch this and print "Run `az login` first"
- Extract `id` field via `jq -r '.id'`
- For tenant display: use `az account show` to get `tenantDisplayName` or `name` (the subscription/account name gives enough context)

### Security Requirements (NFR5, NFR6)

- NEVER store, cache, or log tokens — `az rest` handles all token management
- NEVER echo tokens or credentials to stdout or stderr
- The script delegates ALL authentication to `az cli`

### Architecture Compliance

- Single bash file, no external scripts or modules
- `set -euo pipefail` at the top
- Functions defined before use (bash requirement)
- Use `local` for all function-scoped variables
- Exit code 0 for clean exit, 1 for errors

### File Structure

```
pim-me-up          ← the script (this story creates it)
```

No other files. No lib directory. No config files. Single script is the entire tool.

### Testing Approach

Manual testing only (no test framework for bash in this project):
1. Run without fzf installed → verify error lists missing deps
2. Run without `az login` → verify "Run `az login` first" message
3. Run with everything present → verify user ID retrieved and tenant displayed
4. Run with multiple missing deps → verify ALL are listed (not just first)

### What NOT To Build

- Do NOT implement the category picker, role selection, or any fzf UI — that's Story 1.3
- Do NOT implement active assignment display — that's Story 1.2
- Do NOT implement API calls — that's Epic 2
- Do NOT add `--help` flags or argument parsing — not in MVP scope
- Do NOT add logging or config files — architecture says zero-config

### References

- [Source: _bmad-output/architecture.md#Script Structure] — function organization and naming
- [Source: _bmad-output/architecture.md#Auth Strategy] — az rest auth approach
- [Source: _bmad-output/architecture.md#Error Handling] — fail fast on prerequisites
- [Source: _bmad-output/architecture.md#Dependencies & Distribution] — required tools and versions
- [Source: _bmad-output/architecture.md#fzf Configuration] — FZF_COMMON, FZF_SINGLE, FZF_MULTI constants
- [Source: _bmad-output/planning-artifacts/prd.md#Functional Requirements] — FR1 (dependency check)
- [Source: _bmad-output/planning-artifacts/prd.md#Non-Functional Requirements] — NFR5, NFR6 (security)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1] — acceptance criteria

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

None — clean implementation with no issues.

### Completion Notes List

- Created `pim-me-up` script at project root with full section structure matching architecture spec
- Implemented constants: PIM_API, ARM_API, color codes, DURATION_OPTIONS, FZF_COMMON/SINGLE/MULTI
- Implemented `die()` — colored error to stderr with configurable exit code
- Implemented `check_deps()` — checks fzf, jq, az, curl; collects ALL missing before reporting
- Implemented `get_user_id()` — retrieves objectId via `az ad signed-in-user show`, displays tenant name via `az account show`
- Implemented `gen_uuid()` — reads from /proc/sys/kernel/random/uuid with uuidgen fallback
- Implemented `iso_now()` — UTC ISO8601 timestamp
- Implemented `main()` — calls check_deps → get_user_id, with placeholder comments for future stories
- All section headers in place for future story insertions (API, Display, UI Flow, Activation)
- Manual testing verified: missing deps reports all at once with exit 1, missing az login prints correct message with exit 1, happy path retrieves user ID and displays tenant name, gen_uuid and iso_now produce correct output

### Change Log

- 2026-04-03: Initial implementation of Story 1.1 — script bootstrap with dependency check, login verification, tenant display, and utility functions

### File List

- pim-me-up (new) — main script file
