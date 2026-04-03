# Story 1.2: Active Assignment Display

Status: review

## Story

As a platform engineer,
I want to see my currently active PIM assignments when the tool starts,
so that I know what's already elevated before selecting new roles.

## Acceptance Criteria

1. **Given** the user passes dependency checks, **When** active assignments can be fetched within 1 second, **Then** a summary of active assignments across all three categories is displayed.

2. **Given** the user passes dependency checks, **When** the active assignment fetch exceeds 1 second, **Then** the display is skipped and the tool proceeds to the category picker.

3. **Given** the user has no active assignments, **When** the tool starts, **Then** a brief "No active assignments" message is shown (or the section is omitted).

## Tasks / Subtasks

- [x] Task 1: Implement `fetch_active_pim()` API function for PIM Governance API categories (AC: 1)
  - [x] 1.1: Create function that takes a category path (`aadroles` or `aadGroups`) and queries active assignments via `az rest --resource $PIM_API`
  - [x] 1.2: Filter: `subjectId eq '{userId}' and assignmentState eq 'Active'`
  - [x] 1.3: Return JSON array of active assignments (or empty on failure/timeout)
- [x] Task 2: Implement `fetch_active_arm()` API function for Azure Resource active assignments (AC: 1)
  - [x] 2.1: Query ARM API for active role assignment schedule instances: `GET /providers/Microsoft.Authorization/roleAssignmentScheduleInstances?$filter=asTarget()&api-version=2020-10-01`
  - [x] 2.2: Use default `az rest` token scoping (ARM is default)
  - [x] 2.3: Return JSON array (or empty on failure/timeout)
- [x] Task 3: Implement `show_active_assignments()` orchestrator with 1-second timeout (AC: 1, 2, 3)
  - [x] 3.1: Launch all three fetches (Entra Roles, PIM Groups, Azure Resources) as background jobs (`&`)
  - [x] 3.2: Use `wait -n` or a timed wait loop — if all complete within 1 second, collect results; if not, kill remaining jobs and skip display
  - [x] 3.3: Parse results: count active assignments per category, extract role/group names
  - [x] 3.4: If total count > 0, display formatted summary (category: count + names); if 0, show "No active assignments"
  - [x] 3.5: If timeout hit, silently skip (no error message — just proceed)
- [x] Task 4: Implement display formatting for active assignments (AC: 1, 3)
  - [x] 4.1: Format Entra Roles: extract `roleName` from each assignment's `roleDefinition.resource.displayName` or similar
  - [x] 4.2: Format PIM Groups: extract group name from assignment data
  - [x] 4.3: Format Azure Resources: extract role name and scope
  - [x] 4.4: Use colored output — YELLOW header, role names in normal text
- [x] Task 5: Wire `show_active_assignments()` into `main()` after `get_user_id()` (AC: all)
  - [x] 5.1: Call `show_active_assignments` between `get_user_id` and the future category picker placeholder
- [x] Task 6: Manual testing of all three acceptance criteria scenarios

## Dev Notes

### API Endpoints for Active Assignments

**PIM Governance API** (Entra ID Roles and PIM Groups):

```bash
# Entra ID Roles — active assignments
az rest --resource "$PIM_API" --method GET \
  --url "$PIM_API/api/v2/privilegedAccess/aadroles/roleAssignments?\$filter=subjectId eq '$USER_ID' and assignmentState eq 'Active'"

# PIM Groups — active assignments
az rest --resource "$PIM_API" --method GET \
  --url "$PIM_API/api/v2/privilegedAccess/aadGroups/roleAssignments?\$filter=subjectId eq '$USER_ID' and assignmentState eq 'Active'"
```

Response structure (PIM Governance):
```json
{
  "value": [
    {
      "id": "...",
      "resourceId": "...",
      "roleDefinitionId": "...",
      "subjectId": "...",
      "assignmentState": "Active",
      "roleDefinition": {
        "displayName": "Global Reader",
        "resource": {
          "displayName": "Entra ID"
        }
      }
    }
  ]
}
```

**ARM API** (Azure Resources):

```bash
# Azure Resources — active role assignment schedule instances
az rest --method GET \
  --url "$ARM_API/providers/Microsoft.Authorization/roleAssignmentScheduleInstances?\$filter=asTarget()&api-version=2020-10-01"
```

Response structure (ARM):
```json
{
  "value": [
    {
      "properties": {
        "roleDefinitionId": "/providers/Microsoft.Authorization/roleDefinitions/...",
        "scope": "/subscriptions/.../resourceGroups/...",
        "expandedProperties": {
          "roleDefinition": { "displayName": "Contributor" },
          "scope": { "displayName": "my-resource-group" }
        }
      }
    }
  ]
}
```

### 1-Second Timeout Strategy

Use bash background jobs for parallel fetching:

```bash
show_active_assignments() {
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" RETURN

    # Launch all three fetches in background
    fetch_active_pim "aadroles" > "$tmpdir/entra" 2>/dev/null &
    local pid_entra=$!
    fetch_active_pim "aadGroups" > "$tmpdir/groups" 2>/dev/null &
    local pid_groups=$!
    fetch_active_arm > "$tmpdir/arm" 2>/dev/null &
    local pid_arm=$!

    # Wait up to 1 second
    local deadline=$((SECONDS + 1))
    for pid in $pid_entra $pid_groups $pid_arm; do
        local remaining=$((deadline - SECONDS))
        if [[ $remaining -le 0 ]]; then
            kill $pid_entra $pid_groups $pid_arm 2>/dev/null || true
            wait $pid_entra $pid_groups $pid_arm 2>/dev/null || true
            return 0  # silently skip
        fi
        timeout "$remaining" tail --pid="$pid" -f /dev/null 2>/dev/null || true
    done

    # All completed in time — parse and display
    ...
}
```

**Important:** The `timeout` + `tail --pid` trick may not be available everywhere. A simpler approach: use a 1-second `sleep` in a subshell as a deadline, and `wait -n` (bash 4.3+) to collect completions. OR use the `timeout` command to wrap the entire function:

```bash
# Simplest approach — wrap the whole block in timeout
if ! timeout 1 bash -c 'source_and_run_fetch_active'; then
    # Timed out — silently skip
fi
```

**Recommended approach:** Use background jobs with a simple polling loop checking `SECONDS`. This is portable and clear.

### Where to Place Functions in the Script

Following the architecture section order established in Story 1.1:

1. `fetch_active_pim()` and `fetch_active_arm()` → **API Functions** section (after line ~102)
2. Display formatting logic → **Display Formatting** section (after line ~108)
3. `show_active_assignments()` → **UI Flow Functions** section (after line ~114) — it orchestrates API calls + display

### Graceful Degradation (NFR10)

Each API fetch must be independently fault-tolerant:
- If one category fails (403, network error, etc.), the others still display
- Use `2>/dev/null` and `|| true` to suppress per-fetch errors
- Only the categories that return data are shown in the summary

### Security (NFR5, NFR6)

- Use `az rest` for all API calls — no manual token handling
- PIM API calls require `--resource $PIM_API` for correct token scoping
- ARM API calls use default `az rest` scoping
- Never log or echo raw API responses that might contain tokens

### Display Format

```
Active PIM Assignments:
  Entra ID Roles (2): Global Reader, Security Reader
  PIM Groups (1): SG-Prod-Admin
  Azure Resources (3): Contributor (sub-a/rg-1), Reader (sub-b/rg-2), ...
```

Or if none: `No active PIM assignments`

Keep it compact — this is informational only, shown briefly at startup.

### Previous Story Learnings (from 1.1)

- Script structure is established with section headers — insert functions in the correct sections
- `USER_ID` is a global set by `get_user_id()` — available for API filter parameters
- `die()`, color constants (`RED`, `GREEN`, `YELLOW`, `NC`) are available
- fzf version detection is in place (FZF_COMMON adapts to version)
- `gen_uuid()` and `iso_now()` are available but not needed for this story
- Review feedback: `USER_ID` is unsanitized for URL interpolation — noted in deferred-work.md, address in Epic 2
- Review feedback: tenant name retrieval uses Graph API with `az account show` fallback — working pattern for `az rest`

### What NOT To Build

- Do NOT implement the category picker — that's Story 1.3
- Do NOT implement eligible role fetching — that's Epic 2
- Do NOT implement activation — that's Epic 3
- Do NOT cache these active assignments — this is display-only at startup
- Do NOT add `--status` flag or non-interactive mode — not in MVP
- Do NOT block startup if active assignment fetch fails — always proceed

### Testing Approach

Manual testing (consistent with Story 1.1 — no test framework):
1. Run with active PIM assignments → verify summary displays correctly
2. Run with no active assignments → verify "No active assignments" message
3. Simulate slow API by temporarily pointing to unreachable endpoint → verify 1-second timeout triggers and tool proceeds
4. Run with one category failing (e.g., no PIM Groups access) → verify other categories still display

### References

- [Source: _bmad-output/architecture.md#API Surface] — PIM Governance API and ARM API endpoints
- [Source: _bmad-output/architecture.md#Auth Strategy] — az rest token scoping for both APIs
- [Source: _bmad-output/architecture.md#Error Handling] — graceful degradation per category
- [Source: _bmad-output/architecture.md#Script Structure] — function organization order
- [Source: _bmad-output/planning-artifacts/prd.md#Functional Requirements] — FR2 (active display), FR3 (1s timeout)
- [Source: _bmad-output/planning-artifacts/prd.md#Non-Functional Requirements] — NFR1 (2s startup), NFR2 (1s active fetch), NFR5/NFR6 (security)
- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2] — acceptance criteria
- [Source: _bmad-output/implementation-artifacts/1-1-dependency-check-and-script-bootstrap.md] — previous story learnings and script structure

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6

### Debug Log References

- Fixed `grep -c . || echo 0` double-output bug — changed to `grep -c . || var=0` pattern

### Completion Notes List

- Implemented `fetch_active_pim()` in API Functions section — queries PIM Governance API for aadroles/aadGroups with Active filter, returns empty JSON on failure
- Implemented `fetch_active_arm()` in API Functions section — queries ARM roleAssignmentScheduleInstances, returns empty JSON on failure
- Implemented `show_active_assignments()` in UI Flow Functions section — launches 3 background fetches, polls with SECONDS-based deadline (1s timeout), kills stragglers and silently skips on timeout
- Implemented `format_pim_roles()`, `format_pim_groups()`, `format_arm_roles()` in Display Formatting section — extracts display names via jq
- Wired `show_active_assignments` into `main()` between `get_user_id` and future category picker
- Display format: YELLOW header, category counts with comma-separated names, or "No active PIM assignments" when none
- Graceful degradation: each fetch independently fault-tolerant via `|| { echo empty; return 0; }`
- Testing: manual testing per story spec (no test framework, consistent with Story 1.1)

### File List

- pim-me-up (modified) — added fetch_active_pim, fetch_active_arm, format_pim_roles, format_pim_groups, format_arm_roles, show_active_assignments; updated main()

### Change Log

- 2026-04-03: Implemented Story 1.2 — active assignment display with 1-second timeout, parallel fetching, and graceful degradation
