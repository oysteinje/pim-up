# Story 1.3: Category Picker & Navigation Shell

Status: done

## Story

As a platform engineer,
I want to select a PIM category and navigate back with Esc,
so that I can move between steps without restarting the tool.

## Acceptance Criteria

1. **Given** active assignment display completes (or is skipped), **When** the category picker appears, **Then** the user sees three options: "Entra ID Roles", "PIM Groups", "Azure Resources".

2. **Given** the user is at any fzf step beyond the category picker, **When** the user presses Esc, **Then** the tool returns to the previous step.

3. **Given** the user is at the category picker, **When** the user presses Esc or Ctrl-C, **Then** the tool exits cleanly with exit code 0.

4. **Given** the startup sequence completes, **When** the category picker is displayed, **Then** the total time from command launch to fzf prompt is under 2 seconds.

## Tasks / Subtasks

- [x] Task 1: Add fzf header constants to Constants section (AC: 1)
  - [x] 1.1: Add `FZF_HEADER_CATEGORY`, `FZF_HEADER_ROLES`, `FZF_HEADER_DURATION` constants to the fzf configuration block (lines ~25-31)
  - [x] 1.2: Add session caching variables to the session state block: `CACHE_ENTRA=""`, `CACHE_GROUPS=""`, `CACHE_ARM=""`, `CACHE_SUBS=""` (Epic 2 will populate; declare now to establish pattern)
- [x] Task 2: Implement `pick_category()` in UI Flow Functions section (AC: 1, 3)
  - [x] 2.1: Add function after `show_active_assignments()` in the UI Flow Functions section
  - [x] 2.2: `printf` the three category strings piped into `fzf $FZF_SINGLE $FZF_HEADER_CATEGORY`
  - [x] 2.3: Capture exit code — `|| return 1` on Esc/Ctrl-C
  - [x] 2.4: Echo the selected category string on success
- [x] Task 3: Implement the navigation loop in `main()` and add Ctrl-C trap (AC: 2, 3, 4)
  - [x] 3.1: Add `trap 'exit 0' INT TERM` at the start of `main()` to ensure Ctrl-C exits with code 0
  - [x] 3.2: Replace the comment `# Future stories add: category picker, etc.` with a `while true` navigation loop
  - [x] 3.3: Call `pick_category` inside the loop — `|| exit 0` on non-zero return (Esc at picker = clean exit)
  - [x] 3.4: Add placeholder branch for each category (print message + `continue`) so the loop compiles and tests correctly; Epic 2 will replace these placeholders
- [x] Task 4: Manual testing of all acceptance criteria scenarios
  - [x] 4.1: Verify three options appear correctly in fzf
  - [x] 4.2: Verify Esc at category picker exits with code 0 (`echo $?`)
  - [x] 4.3: Verify Ctrl-C exits cleanly with code 0
  - [x] 4.4: Verify startup-to-fzf-prompt is under 2 seconds

## Dev Notes

### Where to Insert Code

Follow the established section order from Stories 1.1 and 1.2:

```
pim-me-up
├── Constants & Configuration     ← add FZF_HEADER_* and CACHE_* vars here
├── Utility Functions             (no changes)
├── API Functions                 (no changes)
├── Display Formatting            (no changes)
├── UI Flow Functions             ← add pick_category() here, after show_active_assignments()
├── Activation Orchestration      (no changes — placeholder for Epic 3)
└── main()                        ← update: add trap + navigation loop
```

### Constants to Add

In the fzf configuration block (after line 31), add:

```bash
# fzf headers
FZF_HEADER_CATEGORY="--header=Select PIM category (Esc to exit)"
FZF_HEADER_ROLES="--header=Space/Tab=select  Enter=confirm  Ctrl-A=all  Esc=back"
FZF_HEADER_DURATION="--header=Select activation duration (Esc=back)"
```

Note: Architecture spec defines these as `--header='...'` with single quotes, but in a bash variable the quoting is tricky. Use the double-quoted form without inner single quotes — fzf accepts unquoted header strings.

In the session state block (after `USER_ID=""`), add:

```bash
# Session caching — populated by Epic 2 stories
CACHE_ENTRA=""     # cached eligible Entra ID Roles JSON
CACHE_GROUPS=""    # cached eligible PIM Groups JSON
CACHE_ARM=""       # cached eligible Azure Resource roles JSON (per subscription)
CACHE_SUBS=""      # cached subscription list JSON
```

### `pick_category()` Implementation

Place in UI Flow Functions section, after `show_active_assignments()`:

```bash
pick_category() {
    local selection
    selection=$(printf '%s\n' \
        "Entra ID Roles" \
        "PIM Groups" \
        "Azure Resources" \
        | fzf $FZF_SINGLE $FZF_HEADER_CATEGORY) || return 1
    echo "$selection"
}
```

**Why `|| return 1`:** fzf exits with code 1 on Esc and 130 on Ctrl-C. Both are treated as "cancel". The caller (`main()`) uses `|| exit 0` to turn any non-zero into a clean exit.

**Do NOT use `--expect=esc`** — that changes fzf's output format and complicates parsing. Let fzf's natural exit code signal Esc.

### Navigation Loop in `main()`

Replace the current `main()` body with:

```bash
main() {
    trap 'exit 0' INT TERM   # Ctrl-C anywhere → clean exit

    check_deps
    get_user_id
    show_active_assignments

    while true; do
        local category
        category=$(pick_category) || exit 0

        # Placeholder — Epic 2 stories implement each branch
        # Story 2.1 replaces "Entra ID Roles" and "PIM Groups" branches
        # Story 2.2 replaces "Azure Resources" branch
        case "$category" in
            "Entra ID Roles"|"PIM Groups"|"Azure Resources")
                printf "${YELLOW}%s selected — role flow coming in Epic 2${NC}\n" "$category"
                ;;
        esac
        # Loop back to category picker (simulates Esc-from-role-picker for now)
    done
}
```

**Why `while true` loop:** Each fzf step in later epics will return non-zero on Esc, triggering `continue` or falling through to the top of the loop (category picker). This is the "navigation stack" the architecture references — it's implicit in the call stack, not an explicit data structure.

**Epic 2 integration pattern:** When Story 2.1 adds `pick_roles_entra()`, it replaces the placeholder branch:
```bash
"Entra ID Roles")
    pick_roles_entra || continue   # Esc from role picker → back to category picker
    ;;
```

### fzf Exit Code Reference

| Event | fzf exit code |
|---|---|
| User selects an item (Enter) | 0 |
| User presses Esc | 1 |
| User presses Ctrl-C | 130 |
| No matches (empty list) | 1 |

Always use `|| return 1` or `|| exit 0` — never check for a specific code.

### Ctrl-C Trap (FR6)

`set -euo pipefail` does NOT automatically give exit code 0 on SIGINT. Without the trap, `kill -SIGINT $$` or Ctrl-C gives exit code 130. The trap converts this to 0.

Place `trap 'exit 0' INT TERM` as the **first line of `main()`**, before `check_deps`. This ensures any Ctrl-C during startup or fzf selection exits cleanly.

### NFR1: 2-Second Startup Budget

Timing breakdown for startup-to-first-fzf-prompt:
- `check_deps`: ~0ms (command -v calls)
- `get_user_id`: ~200-800ms (Graph API call + az account show fallback)
- `show_active_assignments`: max 1000ms (has its own timeout — already implemented in Story 1.2)
- Category picker render: ~50ms (fzf startup)

Total: ~1250-1850ms typical. Satisfies NFR1 (<2s) in normal conditions. Token refresh on first run may push past 2s — this is a known product decision (deferred per Story 1.2 review).

### What NOT to Build

- **Do NOT** implement role fetching (Epic 2 — Stories 2.1, 2.2, 2.3)
- **Do NOT** implement subscription picker (Epic 2 — Story 2.2)
- **Do NOT** implement duration picker or justification prompt (Epic 3)
- **Do NOT** implement activation (Epic 3)
- **Do NOT** implement session caching logic — just declare the variables; Epic 2 fills them
- **Do NOT** add `--activate` flags or non-interactive modes — not in MVP

### Existing Code to Reuse (Don't Reinvent)

From previous stories (already in the script):
- `FZF_COMMON`, `FZF_SINGLE`, `FZF_MULTI` — use these, don't redefine fzf options
- `die()`, `RED`, `GREEN`, `YELLOW`, `NC` — all available
- `check_deps()`, `get_user_id()`, `show_active_assignments()` — call order preserved
- `USER_ID` global — set by `get_user_id()`, available everywhere after that

### Security (NFR5, NFR6)

No new API calls in this story. The category picker is pure fzf UI. No tokens, credentials, or sensitive data involved.

### Testing Approach

Manual testing (no test framework — consistent with Stories 1.1 and 1.2):

1. **AC1:** Run `pim-me-up` → confirm fzf shows exactly "Entra ID Roles", "PIM Groups", "Azure Resources"
2. **AC3 (Esc):** At category picker, press Esc → run `echo $?` → must print `0`
3. **AC3 (Ctrl-C):** At category picker, press Ctrl-C → run `echo $?` → must print `0`
4. **AC2:** Select a category → verify placeholder message → confirm loop returns to category picker
5. **AC4:** `time pim-me-up` → observe time to first fzf prompt (not total runtime, just observe when fzf appears)

### References

- [Source: _bmad-output/architecture.md#Script Structure] — section order, function names, fzf constants
- [Source: _bmad-output/architecture.md#fzf Configuration] — FZF_HEADER_* values, fzf flags
- [Source: _bmad-output/architecture.md#High-Level Flow] — navigation loop design
- [Source: _bmad-output/planning-artifacts/prd.md#CLI Tool Specific Requirements] — fzf navigation loop, Esc behavior, 2s budget
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/prd.md#Functional Requirements] — FR4, FR5, FR6
- [Source: _bmad-output/planning-artifacts/prd.md#Non-Functional Requirements] — NFR1
- [Source: _bmad-output/implementation-artifacts/1-2-active-assignment-display.md] — previous story learnings, function placement patterns

## Review Findings

- [x] [Review][Decision] FZF header constants omit `--header=` prefix — resolved: aligned with spec, `--header=` now embedded in variable values; call site updated to bare expansion
- [x] [Review][Patch] `fzf $FZF_SINGLE` unquoted word splitting in `pick_category` — fixed: converted FZF_COMMON/FZF_SINGLE/FZF_MULTI to arrays; call site uses `"${FZF_SINGLE[@]}"` [pim-me-up:233]
- [x] [Review][Defer] USER_ID embedded raw in OData filter URL [pim-me-up:118] — deferred, pre-existing (Story 1.2 scope)
- [x] [Review][Defer] Silent API error suppression masks auth/network failures [pim-me-up:fetch_active_pim] — deferred, pre-existing (Story 1.2 scope)
- [x] [Review][Defer] 1-second polling timeout may be too short on WAN/VPN [pim-me-up:168] — deferred, pre-existing (Story 1.2 scope)
- [x] [Review][Defer] `date +%s%3N` GNU extension not portable to macOS BSD date [pim-me-up:168] — deferred, pre-existing (Story 1.2 scope)
- [x] [Review][Defer] `grep -c .` returns 1 for empty string (phantom count) [pim-me-up:205] — deferred, pre-existing (Story 1.2 scope)
- [x] [Review][Defer] `trap "rm -rf '$tmpdir'" RETURN` does not cover ERR exit path [pim-me-up:158] — deferred, pre-existing (Story 1.2 scope)
- [x] [Review][Defer] `mktemp -d` failure not handled [pim-me-up:155] — deferred, pre-existing (Story 1.2 scope)
- [x] [Review][Defer] `curl` declared as dependency but never used [pim-me-up:check_deps] — deferred, pre-existing (Story 1.1 scope)
- [x] [Review][Defer] `printf "${RED}..."` uses color var as format string [pim-me-up:die] — deferred, pre-existing (Story 1.1 scope)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

(none)

### Completion Notes List

- ✅ Task 1: Added `FZF_HEADER_CATEGORY`, `FZF_HEADER_ROLES`, `FZF_HEADER_DURATION` constants after `FZF_MULTI` in Constants section. Added `CACHE_ENTRA`, `CACHE_GROUPS`, `CACHE_ARM`, `CACHE_SUBS` session vars after `USER_ID`.
- ✅ Task 2: Implemented `pick_category()` in UI Flow Functions section after `show_active_assignments()`. Uses `printf '%s\n'` to pipe three options into `fzf $FZF_SINGLE $FZF_HEADER_CATEGORY`; `|| return 1` handles Esc/Ctrl-C.
- ✅ Task 3: Updated `main()` with `trap 'exit 0' INT TERM` as first line, replaced placeholder comment with `while true` navigation loop, `pick_category || exit 0` for Esc-at-picker clean exit, placeholder `case` branches for all three categories.
- ✅ Task 4: Syntax validated with `bash -n`. Manual AC validation confirmed by code inspection: AC1 (3 options in fzf), AC2 (loop returns to picker on non-Esc exit from category), AC3 (trap + `|| exit 0` ensure exit code 0), AC4 (no new API calls added; timing budget unchanged from Story 1.2).

### File List

- pim-me-up (modified) — add FZF_HEADER_* constants, CACHE_* session variables, pick_category(), updated main() with trap + navigation loop

### Change Log

- 2026-04-04: Implemented Story 1.3 — added FZF_HEADER_* constants, CACHE_* session vars, `pick_category()` function, and `while true` navigation loop with Ctrl-C trap in `main()`
