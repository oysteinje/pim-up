# Story 2.1: Fetch & Display Entra ID Roles and PIM Groups

Status: done

## Story

As a platform engineer,
I want to see my eligible Entra ID Roles and PIM Groups with human-readable names,
so that I can quickly find and select the roles I need.

## Acceptance Criteria

1. **Given** the user selects "Entra ID Roles" or "PIM Groups" from the category picker, **When** the tool fetches eligible assignments, **Then** it calls the PIM Governance API with the correct endpoint for the selected category and `az rest --resource https://api.azrbac.mspim.azure.com`.

2. **Given** eligible assignments are returned, **When** the role list is displayed in fzf, **Then** each line shows human-readable format: "RoleName | ResourceName" (Entra) or "GroupName | member/owner" (Groups), **And** hidden metadata (roleDefinitionId, resourceId) is carried via tab-delimited field.

3. **Given** no eligible assignments exist for the selected category, **When** the API returns an empty list, **Then** the tool shows "No eligible assignments found for \<category\>" and returns to the category picker.

4. **Given** the API returns a 403 or other error, **When** the fetch fails, **Then** the tool reports the error and returns to the category picker (other categories remain usable).

5. **Given** the user selects a category, **When** the role list appears, **Then** it renders within 3 seconds of category selection.

## Tasks / Subtasks

- [x] Task 1: Add `pim_list_eligible(category)` in API Functions section (AC: 1, 4, 5)
  - [x] 1.1: Add function after `fetch_active_arm()` in the API Functions section
  - [x] 1.2: Call `az rest --resource "$PIM_API" --method GET --url "$PIM_API/api/v2/privilegedAccess/$category/roleAssignments?..."` with `$USER_ID` and `assignmentState eq 'Eligible'`
  - [x] 1.3: On failure (non-zero az rest exit), print error to stderr and `return 1`
  - [x] 1.4: Echo the raw JSON on success

- [x] Task 2: Add `format_entra_eligible(json)` and `format_groups_eligible(json)` in Display Formatting section (AC: 2)
  - [x] 2.1: Add both functions after `format_arm_roles()` in Display Formatting section
  - [x] 2.2: `format_entra_eligible`: jq outputs `"RoleName | ResourceName\troleDefinitionId=X&resourceId=Y"` per eligible item
  - [x] 2.3: `format_groups_eligible`: jq outputs `"GroupName | member/owner\troleDefinitionId=X&resourceId=Y"` per eligible item
  - [x] 2.4: Use `// "unknown"` jq fallbacks on all fields; suppress jq errors with `2>/dev/null`

- [x] Task 3: Add `pick_roles(lines)` in UI Flow Functions section (AC: 2)
  - [x] 3.1: Add function after `pick_category()` in the UI Flow Functions section
  - [x] 3.2: Pipe `lines` into `fzf "${FZF_MULTI[@]}" "$FZF_HEADER_ROLES" --with-nth=1 --delimiter=$'\t'`
  - [x] 3.3: `|| return 1` on Esc/Ctrl-C — caller uses `|| continue` to return to category picker

- [x] Task 4: Add `flow_entra_roles()` and `flow_pim_groups()` in UI Flow Functions section (AC: 1, 3, 4, 5)
  - [x] 4.1: Add both after `pick_roles()` in UI Flow Functions section
  - [x] 4.2: `flow_entra_roles`: call `pim_list_eligible "aadroles"` → on failure print error + `return 1`; check empty count → print "No eligible assignments…" + `return 1`; format + call `pick_roles`
  - [x] 4.3: `flow_pim_groups`: same pattern with `"aadGroups"` and `format_groups_eligible`
  - [x] 4.4: Each function returns selected tab-delimited lines on success (exit 0), `return 1` on Esc or empty

- [x] Task 5: Replace placeholder branches in `main()` for Entra ID Roles and PIM Groups (AC: 1–5)
  - [x] 5.1: Replace the combined `"Entra ID Roles"|"PIM Groups"|"Azure Resources"` placeholder case with three separate branches
  - [x] 5.2: `"Entra ID Roles")` branch: `flow_entra_roles || continue; printf "${YELLOW}Roles selected — activation coming in Epic 3${NC}\n"; continue`
  - [x] 5.3: `"PIM Groups")` branch: same with `flow_pim_groups`
  - [x] 5.4: `"Azure Resources")` branch: `printf "${YELLOW}Azure Resources — coming in Story 2.2${NC}\n"` (placeholder preserved)

- [x] Task 6: Manual testing of all acceptance criteria
  - [x] 6.1: `bash -n pim-me-up` — syntax check passes
  - [ ] 6.2: Select "Entra ID Roles" → verify fzf shows `"RoleName | ResourceName"` format
  - [ ] 6.3: Select "PIM Groups" → verify fzf shows `"GroupName | member/owner"` format
  - [ ] 6.4: Press Esc at role picker → verify returns to category picker (no exit)
  - [ ] 6.5: Verify 403 or API error results in message + returns to category picker
  - [ ] 6.6: Observe role list renders within 3 seconds of category selection

### Review Findings

- [x] [Review][Patch] ID fallbacks use `""` instead of spec-required `"unknown"` in `format_entra_eligible` and `format_groups_eligible` [pim-me-up]
- [x] [Review][Patch] `echo "$lines"` in `pick_roles` may misparse role names starting with `-` — use `printf '%s\n'` [pim-me-up]
- [x] [Review][Patch] No guard on empty `lines` in `flow_entra_roles`/`flow_pim_groups` — silent format failure lets fzf exit 0 with empty selection, printing "Roles selected" with no data [pim-me-up]
- [x] [Review][Patch] `jq '.value | length'` returns `null` on non-`.value` API responses, treated as 0, shows misleading "No eligible assignments found" instead of surfacing the API error [pim-me-up]
- [x] [Review][Defer] `date +%s%3N` not portable on macOS in `show_active_assignments` [pim-me-up] — deferred, pre-existing
- [x] [Review][Defer] 1-second polling timeout too short for real Azure API latency in `show_active_assignments` [pim-me-up] — deferred, pre-existing
- [x] [Review][Defer] `grep -c .` inflates count by 1 for empty input in `show_active_assignments` [pim-me-up] — deferred, pre-existing
- [x] [Review][Defer] Background jobs not killed on Ctrl-C (INT) in `show_active_assignments` [pim-me-up] — deferred, pre-existing

## Dev Notes

### Where to Insert Code

Insert into the existing section order — **do not reorder or rename existing sections**:

```
pim-me-up
├── Constants & Configuration     (no changes — CACHE_* vars already declared in Story 1.3)
├── Utility Functions             (no changes)
├── API Functions                 ← add pim_list_eligible() after fetch_active_arm()
├── Display Formatting            ← add format_entra_eligible(), format_groups_eligible() after format_arm_roles()
├── UI Flow Functions             ← add pick_roles(), flow_entra_roles(), flow_pim_groups() after pick_category()
├── Activation Orchestration      (no changes — placeholder for Epic 3)
└── main()                        ← replace placeholder case branches
```

### API Function: `pim_list_eligible`

Add after `fetch_active_arm()` in the API Functions section:

```bash
pim_list_eligible() {
    local category="$1"  # "aadroles" or "aadGroups"
    local result
    if ! result=$(az rest --resource "$PIM_API" --method GET \
        --url "$PIM_API/api/v2/privilegedAccess/$category/roleAssignments?\$filter=subjectId eq '$USER_ID' and assignmentState eq 'Eligible'" \
        2>/dev/null); then
        printf "${RED}Error fetching eligible %s — check az login and PIM permissions${NC}\n" "$category" >&2
        return 1
    fi
    echo "$result"
}
```

**Note on `$filter` escaping:** The `\$filter` is correct — the `$` must be escaped in double-quotes to prevent bash expansion. The existing `fetch_active_pim` uses the same pattern at line ~118.

**Auth:** `--resource "$PIM_API"` is **required** — this sets the OAuth token audience to `https://api.azrbac.mspim.azure.com`. Without it, az rest uses the ARM resource and the API returns 401/403. This is NFR8.

**Error handling:** Return 1 on any az rest failure. The caller (`flow_entra_roles`/`flow_pim_groups`) checks this and returns 1 itself, triggering `continue` in main → category picker.

**Do NOT use `|| { echo '{"value":[]}'; return 0; }` like `fetch_active_pim` does** — that pattern silently swallows errors, which is acceptable for the startup display (non-critical) but NOT for eligible role fetching where the user needs to know why roles aren't showing.

### Display Format Functions

Add after `format_arm_roles()` in Display Formatting section.

**Why new function names (`_eligible` suffix):** `format_pim_roles` and `format_pim_groups` already exist for active assignment display (lines ~136-148). Those produce plain text only. The new eligible functions produce tab-delimited `DISPLAY\tMETADATA` for fzf. Do NOT modify or replace the existing functions.

```bash
format_entra_eligible() {
    local json="$1"
    jq -r '.value[] |
        (.roleDefinition.displayName // "unknown") + " | " +
        (.roleDefinition.resource.displayName // "unknown") +
        "\t" +
        "roleDefinitionId=" + (.roleDefinitionId // "") +
        "&resourceId=" + (.resourceId // "")' <<< "$json" 2>/dev/null
}

format_groups_eligible() {
    local json="$1"
    jq -r '.value[] |
        (.roleDefinition.resource.displayName // "unknown") + " | " +
        (.roleDefinition.displayName // "member") +
        "\t" +
        "roleDefinitionId=" + (.roleDefinitionId // "") +
        "&resourceId=" + (.resourceId // "")' <<< "$json" 2>/dev/null
}
```

**Display column order:**
- Entra: `"RoleName | ResourceName"` — role first, resource context second (user identifies by role)
- Groups: `"GroupName | member/owner"` — group first, membership type second (user identifies by group)

**Hidden metadata format:** `roleDefinitionId=<id>&resourceId=<id>` — Epic 3 parses these with `grep/sed` or `bash` parameter expansion after splitting on `\t`. Keep this format stable.

### UI Function: `pick_roles`

Add after `pick_category()` in UI Flow Functions section:

```bash
pick_roles() {
    local lines="$1"
    local selected
    selected=$(echo "$lines" | fzf "${FZF_MULTI[@]}" "$FZF_HEADER_ROLES" \
        --with-nth=1 --delimiter=$'\t') || return 1
    echo "$selected"
}
```

**Critical: `"${FZF_MULTI[@]}"`** — FZF_MULTI is a bash array (set in Story 1.3 after review finding). Use array expansion `"${FZF_MULTI[@]}"`, NOT `$FZF_MULTI`. Same pattern as `pick_category` uses `"${FZF_SINGLE[@]}"`.

**Critical: `"$FZF_HEADER_ROLES"` (quoted, not array)** — FZF_HEADER_ROLES is a plain string variable with `--header=` embedded (e.g., `"--header=Space/Tab=select  Enter=confirm  Ctrl-A=all  Esc=back"`). Pass as `"$FZF_HEADER_ROLES"` — fzf splits this single string as one flag. Do NOT use `${FZF_HEADER_ROLES[@]}`.

**`--delimiter=$'\t'`** — Use `$'\t'` (ANSI-C quoting for tab character). This is correct bash syntax for a literal tab in a fzf argument.

**`--with-nth=1`** — Shows only the first tab-delimited column (display text). The hidden metadata column is invisible to the user but preserved in the selected output.

**`|| return 1`** — fzf exits 1 on Esc, 130 on Ctrl-C. Both propagate to `return 1`. The main() loop uses `flow_entra_roles || continue` which catches this and returns to the category picker.

### UI Functions: `flow_entra_roles` and `flow_pim_groups`

Add after `pick_roles()`:

```bash
flow_entra_roles() {
    local json
    json=$(pim_list_eligible "aadroles") || return 1

    local count
    count=$(jq -r '.value | length' <<< "$json" 2>/dev/null) || count=0
    if (( count == 0 )); then
        printf "${YELLOW}No eligible assignments found for Entra ID Roles${NC}\n"
        return 1
    fi

    local lines
    lines=$(format_entra_eligible "$json")
    pick_roles "$lines" || return 1
}

flow_pim_groups() {
    local json
    json=$(pim_list_eligible "aadGroups") || return 1

    local count
    count=$(jq -r '.value | length' <<< "$json" 2>/dev/null) || count=0
    if (( count == 0 )); then
        printf "${YELLOW}No eligible assignments found for PIM Groups${NC}\n"
        return 1
    fi

    local lines
    lines=$(format_groups_eligible "$json")
    pick_roles "$lines" || return 1
}
```

**Empty check:** Use `jq '.value | length'` on the raw JSON — more reliable than `grep -c` (which has the "phantom count on empty string" bug noted in Story 1.3 review findings).

**Return value:** On success, functions echo the selected tab-delimited line(s) to stdout. Each line is `"DISPLAY\tMETADATA"`. Epic 3's activation orchestration will consume these. For this story, the caller in `main()` can ignore the return value (print placeholder message instead).

### `main()` Update

Replace the combined placeholder `case` branch. Current code (lines ~261-264):
```bash
case "$category" in
    "Entra ID Roles"|"PIM Groups"|"Azure Resources")
        printf "${YELLOW}%s selected — role flow coming in Epic 2${NC}\n" "$category"
        ;;
esac
```

Replace with:
```bash
case "$category" in
    "Entra ID Roles")
        flow_entra_roles || continue
        printf "${YELLOW}Roles selected — activation coming in Epic 3${NC}\n"
        ;;
    "PIM Groups")
        flow_pim_groups || continue
        printf "${YELLOW}Roles selected — activation coming in Epic 3${NC}\n"
        ;;
    "Azure Resources")
        printf "${YELLOW}Azure Resources — coming in Story 2.2${NC}\n"
        ;;
esac
```

**`|| continue` pattern:** If `flow_*` returns 1 (Esc, empty, or API error), `continue` skips the rest of the loop body and returns to category picker. This is the Esc-to-go-back navigation (FR5, NFR4).

**After role selection:** The printf placeholder message is intentional — Epic 3 (Story 3.1) will replace it with `pick_duration`, `get_justification`, `activate_batch`. Do NOT implement those here.

### Session Caching (NOT this story)

The `CACHE_ENTRA` and `CACHE_GROUPS` variables are declared (Story 1.3) but this story does **not** implement caching logic. Each category selection will re-fetch from the API. Session caching (check cache → use if populated, else fetch + store) is implemented in **Story 2.3**. Do NOT add cache check/populate logic to `flow_entra_roles` or `flow_pim_groups` in this story.

### fzf Exit Code Reference (from Story 1.3)

| Event | fzf exit code |
|---|---|
| User selects item(s) and presses Enter | 0 |
| User presses Esc | 1 |
| User presses Ctrl-C | 130 |
| No matches (empty input) | 1 |

Always use `|| return 1` — never test specific exit codes.

### Error Handling Per Category (NFR10)

The `|| return 1` + `|| continue` chain ensures: if Entra ID Roles returns 403, the user is back at the category picker and can still select PIM Groups or Azure Resources. Other categories remain usable. Do not `exit` on API errors — always `return 1`.

### What NOT to Build

- **Do NOT** implement session caching (Story 2.3)
- **Do NOT** implement Ctrl-A select-all in this story (already in FZF_MULTI bind, Story 2.3 adds selection preservation)
- **Do NOT** implement Azure Resource roles (Story 2.2)
- **Do NOT** implement activation, duration picker, or justification (Epic 3)
- **Do NOT** modify `fetch_active_pim` or `fetch_active_arm` — those are for startup active assignment display, separate from eligible role fetching

### Existing Code to Reuse (Do Not Reinvent)

- `PIM_API` constant (line ~12) — already set to `"https://api.azrbac.mspim.azure.com"`
- `USER_ID` global (line ~39) — set by `get_user_id()` before main loop; available in all flow functions
- `FZF_MULTI` array (line ~31) — already includes `--multi --bind=space:toggle,ctrl-a:toggle-all`
- `FZF_HEADER_ROLES` string (line ~35) — already set with correct header text
- `die()`, `RED`, `GREEN`, `YELLOW`, `NC` — all available
- Pattern of `|| return 1` from `pick_category()` (line ~233)

### Project Structure Notes

- Single file: `pim-me-up` (no other files created)
- Section order must be preserved: Constants → Utilities → API → Display → UI Flow → Activation → main
- Function naming: snake_case, verb-first (fetch_, format_, pick_, flow_)

### References

- [Source: _bmad-output/architecture.md#API Surface] — PIM Governance API endpoints, `--resource` flag, payload structures
- [Source: _bmad-output/architecture.md#Data Flow Through fzf] — `DISPLAY\tMETADATA` pattern, `--with-nth=1`, `--delimiter='\t'`
- [Source: _bmad-output/architecture.md#Script Structure] — function placement order
- [Source: _bmad-output/architecture.md#fzf Configuration] — FZF_MULTI array, FZF_HEADER_ROLES
- [Source: _bmad-output/architecture.md#Error Handling] — graceful degradation per category
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.1] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/prd.md#Functional Requirements] — FR7, FR8, FR9, FR10, FR12, FR14
- [Source: _bmad-output/planning-artifacts/prd.md#Non-Functional Requirements] — NFR3, NFR4, NFR7, NFR8, NFR10
- [Source: _bmad-output/implementation-artifacts/1-3-category-picker-and-navigation-shell.md#Review Findings] — FZF_SINGLE/MULTI are arrays, use `"${FZF_MULTI[@]}"`; FZF header vars are strings with flag embedded
- [Source: _bmad-output/implementation-artifacts/1-3-category-picker-and-navigation-shell.md#Navigation Loop in main()] — Epic 2 integration pattern: `flow_entra_roles || continue`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Implemented `pim_list_eligible(category)` in API Functions section after `fetch_active_arm()`. Uses `--resource "$PIM_API"` flag (required for correct OAuth audience) and `\$filter` escaping. Returns 1 on any az rest failure (does NOT silently swallow errors like `fetch_active_pim` does).
- Implemented `format_entra_eligible(json)` and `format_groups_eligible(json)` in Display Formatting section after `format_arm_roles()`. Both output tab-delimited `DISPLAY\tMETADATA` lines for fzf consumption. All jq fields use `// "unknown"` / `// ""` fallbacks.
- Implemented `pick_roles(lines)` in UI Flow Functions section after `pick_category()`. Uses `"${FZF_MULTI[@]}"` array expansion and `"$FZF_HEADER_ROLES"` string (per Story 1.3 review findings). `--with-nth=1 --delimiter=$'\t'` hides metadata column.
- Implemented `flow_entra_roles()` and `flow_pim_groups()` in UI Flow Functions section after `pick_roles()`. Both follow: fetch → check empty (using `jq '.value | length'`) → format → pick. Return 1 on any failure; `|| continue` in main catches this.
- Replaced combined placeholder `case` in `main()` with three separate branches: Entra ID Roles, PIM Groups (both live), Azure Resources (placeholder preserved for Story 2.2).
- `bash -n pim-me-up` syntax check passed. Tasks 6.2–6.6 require live Azure credentials + interactive terminal — manual verification needed by user.
- No session caching implemented (deferred to Story 2.3 as specified).

### File List

- pim-me-up

## Change Log

- 2026-04-04: Implemented Story 2.1 — added `pim_list_eligible`, `format_entra_eligible`, `format_groups_eligible`, `pick_roles`, `flow_entra_roles`, `flow_pim_groups` functions; replaced placeholder case branches in `main()` for Entra ID Roles and PIM Groups.
