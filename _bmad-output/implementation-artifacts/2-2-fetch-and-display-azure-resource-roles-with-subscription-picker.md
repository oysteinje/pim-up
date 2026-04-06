# Story 2.2: Fetch & Display Azure Resource Roles with Subscription Picker

Status: review

## Story

As a platform engineer,
I want to pick subscriptions and see eligible Azure resource roles scoped to them,
so that I can discover and activate resource-level roles.

## Acceptance Criteria

1. **Given** the user selects "Azure Resources" from the category picker, **When** the subscription picker appears, **Then** it shows available subscriptions from `az account list` in fzf with multi-select.

2. **Given** the user selects one or more subscriptions, **When** the tool fetches eligible resource roles, **Then** it calls the ARM API for each selected subscription and aggregates the results.

3. **Given** eligible resource roles are returned, **When** the role list is displayed, **Then** each line shows "RoleName | Scope" with hidden metadata (roleDefinitionId, scope).

4. **Given** no eligible resource roles exist for the selected subscriptions, **When** the API returns empty, **Then** the tool shows "No eligible assignments found" and returns to the category picker.

## Tasks / Subtasks

- [x] Task 1: Add `FZF_HEADER_SUBS` constant to Constants section (AC: 1)
  - [x] 1.1: Add after `FZF_HEADER_DURATION` in Constants section
  - [x] 1.2: Value: `"--header=Select subscriptions (Space=toggle  Ctrl-A=all  Esc=back)"`

- [x] Task 2: Add `arm_list_eligible(sub_id)` in API Functions section (AC: 2, 4)
  - [x] 2.1: Add after `pim_list_eligible()` in the API Functions section
  - [x] 2.2: Call ARM API scoped to subscription: `$ARM_API/subscriptions/$sub_id/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?$filter=asTarget() and status eq 'Provisioned'&api-version=2020-10-01`
  - [x] 2.3: No `--resource` flag (ARM is default az rest token resource — NFR9)
  - [x] 2.4: On failure, print error to stderr and `return 1`
  - [x] 2.5: Echo raw JSON on success

- [x] Task 3: Add `format_arm_eligible(json)` in Display Formatting section (AC: 3)
  - [x] 3.1: Add after `format_groups_eligible()` in Display Formatting section
  - [x] 3.2: jq outputs `"RoleName | ScopeDisplayName\troleDefinitionId=X&scope=Y"` per eligible item
  - [x] 3.3: Use `.properties.expandedProperties.roleDefinition.displayName` for role name
  - [x] 3.4: Use `.properties.expandedProperties.scope.displayName` for scope display
  - [x] 3.5: Use `.properties.roleDefinitionId` (full path) and `.properties.scope` for hidden metadata
  - [x] 3.6: Use `// "unknown"` jq fallbacks on display fields; `// ""` on metadata fields; suppress jq errors with `2>/dev/null`

- [x] Task 4: Add `pick_subscriptions()` in UI Flow Functions section (AC: 1)
  - [x] 4.1: Add after `pick_roles()` in UI Flow Functions section
  - [x] 4.2: Call `az account list --output json` — returns JSON array (NOT `.value[]` — it's a top-level array)
  - [x] 4.3: Handle empty subscription list — print message and `return 1`
  - [x] 4.4: Format lines with jq: `"Sub Name (sub_id)\tsub_id"` using `.name` and `.id`
  - [x] 4.5: Pipe to `fzf "${FZF_MULTI[@]}" "$FZF_HEADER_SUBS" --with-nth=1 --delimiter=$'\t'` — uses `printf '%s\n' "$lines"` (not echo)
  - [x] 4.6: Guard for empty selection (Enter with nothing selected) — `return 1`
  - [x] 4.7: Extract and echo selected sub IDs from second tab column via `cut -d$'\t' -f2`

- [x] Task 5: Add `flow_azure_resources()` in UI Flow Functions section (AC: 1–4)
  - [x] 5.1: Add after `flow_pim_groups()` in UI Flow Functions section
  - [x] 5.2: Call `pick_subscriptions` → `|| return 1` on Esc/empty
  - [x] 5.3: Loop over each sub ID (read from multi-line output): call `arm_list_eligible "$sub_id"` — on failure, print stderr warning and `continue` (graceful degradation per NFR10)
  - [x] 5.4: Aggregate non-empty formatted results into `all_lines`
  - [x] 5.5: If `all_lines` is empty after all subs: print "No eligible assignments found for Azure Resources" and `return 1`
  - [x] 5.6: Call `pick_roles "$all_lines"` → `|| return 1`

- [x] Task 6: Replace Azure Resources placeholder in `main()` (AC: 1–4)
  - [x] 6.1: Replace `printf "${YELLOW}Azure Resources — coming in Story 2.2${NC}\n"` with:
    ```bash
    "Azure Resources")
        flow_azure_resources || continue
        printf "${YELLOW}Roles selected — activation coming in Epic 3${NC}\n"
        ;;
    ```

- [x] Task 7: Manual testing
  - [x] 7.1: `bash -n pim-me-up` — syntax check passes
  - [ ] 7.2: Select "Azure Resources" → verify subscription picker appears with fzf multi-select
  - [ ] 7.3: Select subscriptions → verify role list shows "RoleName | Scope" format
  - [ ] 7.4: Press Esc at subscription picker → verify returns to category picker
  - [ ] 7.5: Press Esc at role picker → verify returns to category picker
  - [ ] 7.6: Select subscriptions with no eligible roles → verify "No eligible assignments found" + category picker
  - [ ] 7.7: Observe role list renders within 3 seconds (NFR3)

## Dev Notes

### Where to Insert Code

Insert into the existing section order — **do not reorder or rename existing sections**:

```
pim-me-up
├── Constants & Configuration     ← add FZF_HEADER_SUBS after FZF_HEADER_DURATION (line ~36)
├── Utility Functions             (no changes)
├── API Functions                 ← add arm_list_eligible() after pim_list_eligible() (line ~141)
├── Display Formatting            ← add format_arm_eligible() after format_groups_eligible() (line ~180)
├── UI Flow Functions             ← add pick_subscriptions() after pick_roles() (~line 275)
│                                 ← add flow_azure_resources() after flow_pim_groups() (~line 315)
├── Activation Orchestration      (no changes)
└── main()                        ← replace Azure Resources placeholder (~line 348)
```

### New Constant

Add after `FZF_HEADER_DURATION` in Constants section:

```bash
FZF_HEADER_SUBS="--header=Select subscriptions (Space=toggle  Ctrl-A=all  Esc=back)"
```

**Why a constant (not inline):** Consistent with FZF_HEADER_CATEGORY, FZF_HEADER_ROLES, FZF_HEADER_DURATION — all headers are string constants in the Constants section. Pass as `"$FZF_HEADER_SUBS"` (quoted string, NOT array expansion).

### API Function: `arm_list_eligible`

Add after `pim_list_eligible()` in the API Functions section:

```bash
arm_list_eligible() {
    local sub_id="$1"
    local result
    if ! result=$(az rest --method GET \
        --url "$ARM_API/subscriptions/$sub_id/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?\$filter=asTarget() and status eq 'Provisioned'&api-version=2020-10-01" \
        2>/dev/null); then
        printf "${RED}Error fetching eligible ARM roles for subscription %s${NC}\n" "$sub_id" >&2
        return 1
    fi
    echo "$result"
}
```

**No `--resource` flag:** ARM is the default `az rest` token resource (`https://management.azure.com`). Do NOT add `--resource` — that would override to PIM API token. This is NFR9.

**Subscription-scoped URL:** `/subscriptions/$sub_id/providers/...` — scopes the result to the selected subscription. The architecture sub-flow explicitly calls this per subscription. This is more efficient than the global endpoint and respects the user's subscription selection.

**`\$filter` escaping:** The `$` must be escaped in double-quotes to prevent bash from treating `$filter` as a variable. Same pattern used in `pim_list_eligible` and `fetch_active_arm`.

**`status eq 'Provisioned'`:** Filters to only active eligibilities (not pending/expired). The space in the filter value is fine — `az rest` handles URL encoding.

**Return 1 on failure:** Caller (`flow_azure_resources`) prints a warning and continues to the next subscription (graceful degradation, NFR10). Do NOT use `|| { echo '{"value":[]}'; return 0; }` — that silently swallows errors.

**ARM response structure:** `roleEligibilityScheduleInstances` returns the same JSON shape as `roleAssignmentScheduleInstances` (used by `fetch_active_arm`):
```json
{
  "value": [
    {
      "properties": {
        "roleDefinitionId": "/subscriptions/.../providers/Microsoft.Authorization/roleDefinitions/<guid>",
        "scope": "/subscriptions/<sub_id>/resourceGroups/<rg_name>",
        "expandedProperties": {
          "roleDefinition": { "displayName": "Contributor", ... },
          "scope": { "displayName": "rg-name", "id": "/subscriptions/..." }
        }
      }
    }
  ]
}
```
No `$expand` query parameter needed — ARM schedule instances include `expandedProperties` by default.

### Display Format Function: `format_arm_eligible`

Add after `format_groups_eligible()` in Display Formatting section:

```bash
format_arm_eligible() {
    local json="$1"
    jq -r '.value[] |
        (.properties.expandedProperties.roleDefinition.displayName // "unknown") + " | " +
        (.properties.expandedProperties.scope.displayName // "unknown") +
        "\t" +
        "roleDefinitionId=" + (.properties.roleDefinitionId // "") +
        "&scope=" + (.properties.scope // "")' <<< "$json" 2>/dev/null
}
```

**Do NOT modify `format_arm_roles`:** That function is for active assignment display (startup) and outputs plain text without tab-delimited metadata. The `_eligible` suffix signals this is the fzf-ready, metadata-carrying version — same naming convention as `format_entra_eligible` / `format_groups_eligible`.

**Metadata format:** `roleDefinitionId=<full_path>&scope=<scope_path>` — Epic 3's ARM activation constructs: `PUT {scope}/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/{guid}` with `roleDefinitionId` in the payload. Keep this format stable.

**Display column order:** `"RoleName | ScopeDisplayName"` — role first (what the user is activating), scope context second. Consistent with Entra/Groups pipe separator.

### UI Function: `pick_subscriptions`

Add after `pick_roles()` in UI Flow Functions section:

```bash
pick_subscriptions() {
    local subs_json
    if ! subs_json=$(az account list --output json 2>/dev/null); then
        printf "${RED}Error fetching subscriptions — check az login${NC}\n" >&2
        return 1
    fi

    local count
    count=$(jq 'length' <<< "$subs_json" 2>/dev/null) || count=0
    if (( count == 0 )); then
        printf "${YELLOW}No subscriptions found${NC}\n"
        return 1
    fi

    local lines
    lines=$(jq -r '.[] | (.name // "unknown") + " (" + (.id // "") + ")" + "\t" + (.id // "")' \
        <<< "$subs_json" 2>/dev/null)

    local selected
    selected=$(printf '%s\n' "$lines" | fzf "${FZF_MULTI[@]}" "$FZF_HEADER_SUBS" \
        --with-nth=1 --delimiter=$'\t') || return 1

    if [[ -z "$selected" ]]; then
        return 1
    fi

    printf '%s\n' "$selected" | cut -d$'\t' -f2
}
```

**`az account list` returns a top-level JSON array:** NOT `{"value": [...]}`. Use `jq 'length'` (not `jq '.value | length'`) for the empty check. Use `.[]` (not `.value[]`) in the format jq.

**`printf '%s\n' "$lines"` not `echo "$lines"`:** Fixes the `-` prefix bash flag interpretation bug (Story 2.1 review finding). Same pattern used in `pick_roles`.

**Empty selection guard:** fzf `--multi` exits 0 when user presses Enter with no items toggled, producing empty output. Guard `[[ -z "$selected" ]] && return 1` handles this. fzf returns 1 on Esc, 130 on Ctrl-C — both caught by `|| return 1`.

**Output:** Echoes selected subscription IDs one per line (second tab column via `cut`). Caller reads these with `while IFS= read -r sub_id`.

**`"${FZF_MULTI[@]}"`** — FZF_MULTI is a bash array. Use array expansion. Pass `"$FZF_HEADER_SUBS"` as quoted string.

### UI Function: `flow_azure_resources`

Add after `flow_pim_groups()` in UI Flow Functions section:

```bash
flow_azure_resources() {
    local sub_ids
    sub_ids=$(pick_subscriptions) || return 1

    local all_lines=""
    while IFS= read -r sub_id; do
        [[ -z "$sub_id" ]] && continue
        local json
        if ! json=$(arm_list_eligible "$sub_id"); then
            continue  # warning already printed to stderr by arm_list_eligible
        fi

        local count
        count=$(jq -r 'if .value then (.value | length) else 0 end' <<< "$json" 2>/dev/null) || count=0
        (( count == 0 )) && continue

        local lines
        lines=$(format_arm_eligible "$json")
        [[ -z "$lines" ]] && continue

        if [[ -z "$all_lines" ]]; then
            all_lines="$lines"
        else
            all_lines="${all_lines}"$'\n'"${lines}"
        fi
    done <<< "$sub_ids"

    if [[ -z "$all_lines" ]]; then
        printf "${YELLOW}No eligible assignments found for Azure Resources${NC}\n"
        return 1
    fi

    pick_roles "$all_lines" || return 1
}
```

**Per-subscription graceful degradation (NFR10):** If `arm_list_eligible` returns 1 for a subscription, `continue` skips it and tries the next. The error message was already printed to stderr inside `arm_list_eligible`. Other subscriptions remain usable — do NOT `return 1` on individual sub failure.

**Aggregation pattern:** `$'\n'` literal newline concatenation. Avoids subshell or array complexity. The resulting `all_lines` is a newline-separated list of `DISPLAY\tMETADATA` lines — same format `pick_roles` expects.

**Deduplication:** Not needed — each eligible role has a unique scope path. Same role definition in two subscriptions appears as two distinct entries with different scopes.

**`|| continue` after `arm_list_eligible` (not `|| return 1`):** This implements graceful degradation. If Esc was pressed in `pick_subscriptions`, we never reach the loop (caught by the first `|| return 1`).

**`pick_roles "$all_lines"` reuse:** Do NOT create a new fzf invocation. `pick_roles` already exists and handles `"${FZF_MULTI[@]}"`, `"$FZF_HEADER_ROLES"`, `--with-nth=1`, `--delimiter=$'\t'`, and `|| return 1`. Reuse it exactly as Entra/Groups flows do.

**`jq 'if .value then (.value | length) else 0 end'` pattern:** Copied from Story 2.1's fixed implementation — handles API responses without `.value` key without treating null as 0 (prevents misleading "No eligible assignments" on API errors).

### `main()` Update

Replace the Azure Resources placeholder in `main()`. Current code (~line 347):
```bash
"Azure Resources")
    printf "${YELLOW}Azure Resources — coming in Story 2.2${NC}\n"
    ;;
```

Replace with:
```bash
"Azure Resources")
    flow_azure_resources || continue
    printf "${YELLOW}Roles selected — activation coming in Epic 3${NC}\n"
    ;;
```

**`|| continue` pattern:** Same as Entra ID Roles and PIM Groups. If `flow_azure_resources` returns 1 (Esc at any step, no subs, no roles, API error), `continue` returns to category picker.

**After role selection:** Placeholder message is intentional — Epic 3 (Story 3.1) replaces it with `pick_duration`, `get_justification`, `activate_batch`. Do NOT implement those here.

### Existing Code to Reuse (Do Not Reinvent)

- `ARM_API` constant (line ~13) — `"https://management.azure.com"`
- `USER_ID` global (not used in arm_list_eligible — ARM's `asTarget()` filter uses the authenticated token implicitly)
- `FZF_MULTI` array (line ~31) — `--multi --bind=space:toggle,ctrl-a:toggle-all`
- `FZF_HEADER_ROLES` string (line ~35) — reused by `pick_roles` for the ARM role list
- `pick_roles()` function (line ~269) — reuse for ARM role selection (same function as Entra/Groups)
- `die()`, `RED`, `GREEN`, `YELLOW`, `NC` — all available
- `|| return 1` pattern from `pick_category()`, `pick_roles()`

### What NOT to Build

- **Do NOT** implement session caching for subscriptions (`CACHE_SUBS`) or ARM roles (`CACHE_ARM`) — Story 2.3
- **Do NOT** implement back-navigation from role picker to subscription picker — Story 2.3 (current Esc at role picker goes to category picker, consistent with Entra/Groups)
- **Do NOT** implement activation, duration picker, or justification — Epic 3
- **Do NOT** modify `fetch_active_arm` — that is the startup active assignment display, not eligible role fetching
- **Do NOT** implement `arm_activate` — Epic 3

### Project Structure Notes

- Single file: `pim-me-up` (no other files created)
- Section order preserved: Constants → Utilities → API → Display → UI Flow → Activation → main
- Function naming: snake_case, verb-first (`arm_list_eligible`, `format_arm_eligible`, `pick_subscriptions`, `flow_azure_resources`)

### References

- [Source: _bmad-output/architecture.md#API Surface] — ARM eligible endpoint, no `--resource` flag, activation URL structure
- [Source: _bmad-output/architecture.md#Azure Resources Sub-flow] — per-subscription fetch, aggregate, deduplicate, pick_roles
- [Source: _bmad-output/architecture.md#Data Flow Through fzf] — `DISPLAY\tMETADATA`, `--with-nth=1`, `--delimiter='\t'`
- [Source: _bmad-output/architecture.md#Script Structure] — function placement order, `pick_subscriptions` in UI flow
- [Source: _bmad-output/architecture.md#fzf Configuration] — FZF_MULTI array, header vars are strings
- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/prd.md#Functional Requirements] — FR11 (subscription picker), FR13 (ARM API fetch)
- [Source: _bmad-output/planning-artifacts/prd.md#Non-Functional Requirements] — NFR3, NFR9, NFR10
- [Source: _bmad-output/implementation-artifacts/2-1-fetch-and-display-entra-id-roles-and-pim-groups.md#Dev Notes] — `"${FZF_MULTI[@]}"` array expansion; `printf '%s\n'` not echo; `jq 'if .value then (.value | length) else 0 end'`; `|| return 1` pattern; `|| continue` in main
- [Source: _bmad-output/implementation-artifacts/2-1-fetch-and-display-entra-id-roles-and-pim-groups.md#Review Findings] — empty lines guard after format; FZF header as string not array

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

(none)

### Completion Notes List

- Added `FZF_HEADER_SUBS` constant after `FZF_HEADER_DURATION` in Constants section
- Added `arm_list_eligible(sub_id)` after `pim_list_eligible()` in API Functions — subscription-scoped ARM eligible endpoint, no `--resource` flag (NFR9), `\$filter` dollar-escaped in double-quotes, returns raw JSON on success / stderr + return 1 on failure
- Added `format_arm_eligible(json)` after `format_groups_eligible()` in Display Formatting — outputs `"RoleName | ScopeDisplayName\troleDefinitionId=X&scope=Y"` using expandedProperties fields, `// "unknown"` fallbacks on display, `// ""` on metadata, `2>/dev/null`
- Added `pick_subscriptions()` after `pick_roles()` in UI Flow — `az account list` top-level array, jq 'length' check, `printf '%s\n'` (not echo), fzf multi-select with `FZF_HEADER_SUBS`, empty selection guard, echoes sub IDs from tab column 2
- Added `flow_azure_resources()` after `flow_pim_groups()` in UI Flow — picks subs, loops per sub calling `arm_list_eligible`, graceful degradation on failure (continue, NFR10), aggregates into `all_lines`, shows "No eligible assignments found" if empty, reuses `pick_roles`
- Replaced Azure Resources placeholder in `main()` — `flow_azure_resources || continue` pattern consistent with Entra/Groups
- `bash -n pim-me-up` syntax check: PASS

Manual interactive tests (7.2–7.7) require a live Azure session — marked for reviewer.

### File List

- pim-me-up

## Change Log

- 2026-04-04: Story 2.2 implemented — Azure Resources flow with subscription picker, ARM eligible fetch, and role display (Date: 2026-04-04)
