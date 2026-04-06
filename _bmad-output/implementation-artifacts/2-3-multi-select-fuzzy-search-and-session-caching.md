# Story 2.3: Multi-Select, Fuzzy Search & Session Caching

Status: ready-for-dev

## Story

As a platform engineer,
I want to fuzzy-search roles, multi-select with Space, and not re-fetch on back-navigation,
so that the selection experience is fast and fluid.

## Acceptance Criteria

1. **Given** a role list is displayed in fzf, **When** the user types a search term, **Then** the list filters by fuzzy match in real time.

2. **Given** a role list is displayed in fzf, **When** the user presses Space (or Tab) on a role, **Then** the role is toggled for selection and multiple roles can be selected.

3. **Given** a role list is displayed in fzf, **When** the user presses Ctrl-A, **Then** all visible roles are toggled for selection.

4. **Given** the user has previously fetched eligible roles for a category, **When** the user navigates back to that category via Esc, **Then** the cached results are displayed instantly without re-fetching from the API.

5. **Given** the user navigates back from role selection to the category picker, **When** they re-enter the same category, **Then** their previous selections are preserved.

## Tasks / Subtasks

- [ ] Task 1: Add `space:toggle` to `FZF_MULTI` binding (AC: 2)
  - [ ] 1.1: Update `FZF_MULTI` from `--bind=tab:toggle,ctrl-a:toggle-all` to `--bind=space:toggle,tab:toggle,ctrl-a:toggle-all`
  - [ ] 1.2: Update `FZF_HEADER_ROLES` to reflect both Space and Tab work: `"--header=Space/Tab=select  Enter=confirm  Ctrl-A=all  Esc=back"`

- [ ] Task 2: Verify session caching is correct for all three categories (AC: 4)
  - [ ] 2.1: Confirm `CACHE_ENTRA` is populated on first fetch and reused in `flow_entra_roles()` — no change needed if correct
  - [ ] 2.2: Confirm `CACHE_GROUPS` is populated on first fetch and reused in `flow_pim_groups()` — no change needed if correct
  - [ ] 2.3: Confirm `CACHE_ARM` is populated after sub+role fetch and reused in `flow_azure_resources()` — no change needed if correct
  - [ ] 2.4: Confirm `CACHE_SUBS` caches selected subscription IDs so sub picker is skipped on back-navigation — no change needed if correct

- [ ] Task 3: Verify previous selection restoration is correct (AC: 5)
  - [ ] 3.1: Confirm `pick_roles()` accepts `prev_selections` and reorders matched lines to top — no change needed if correct
  - [ ] 3.2: Confirm fzf `start:` binding pre-toggles previously selected items — no change needed if correct
  - [ ] 3.3: Confirm all three flow functions (`flow_entra_roles`, `flow_pim_groups`, `flow_azure_resources`) pass `prev_selections` through to `pick_roles`

- [ ] Task 4: Run syntax check
  - [ ] 4.1: `bash -n pim-me-up` — must pass

- [ ] Task 5: Manual testing
  - [ ] 5.1: Type a search term in the role picker — verify list filters in real time
  - [ ] 5.2: Press Space on a role — verify it toggles (tick appears)
  - [ ] 5.3: Press Tab on a role — verify it toggles
  - [ ] 5.4: Press Ctrl-A — verify all visible roles toggle
  - [ ] 5.5: Select a category, fetch roles, press Esc back to category picker, re-enter same category — verify roles appear instantly (no spinner/delay)
  - [ ] 5.6: Select roles, press Esc back, re-enter same category — verify previously selected roles appear pre-toggled at the top of the list

## Dev Notes

### Current State — Most of This Story is Already Implemented

The "quick implement all stories" commit (`86de203`) already implemented session caching and previous selection restoration. This story is primarily **verification + one fix (space:toggle)**.

**What's already in the script and correct:**

- Session cache variables (script top, ~line 43):
  ```bash
  CACHE_ENTRA=""     # cached eligible Entra ID Roles JSON
  CACHE_GROUPS=""    # cached eligible PIM Groups JSON
  CACHE_ARM=""       # cached eligible Azure Resource roles lines (formatted, not JSON)
  CACHE_SUBS=""      # cached subscription IDs (newline-separated)
  CACHE_SUB_LOOKUP="" # used by lookup_subscription_name, not session cache
  ```

- `flow_entra_roles(prev_selections)` — checks `[[ -z "$CACHE_ENTRA" ]]`, fetches once, stores JSON, reuses
- `flow_pim_groups(prev_selections)` — checks `[[ -z "$CACHE_GROUPS" ]]`, fetches once, stores JSON, reuses
- `flow_azure_resources(prev_selections)` — checks `[[ -n "$CACHE_ARM" ]]` first, skips subscription picker and API entirely; `CACHE_SUBS` skips sub picker on second entry even if roles aren't cached
- `pick_roles(lines, prev_selections)` — complex selection restoration logic (see below)
- `FZF_MULTI` has `ctrl-a:toggle-all` — AC 3 already satisfied

**The one gap:** `FZF_MULTI` binding is `--bind=tab:toggle,ctrl-a:toggle-all` — `space:toggle` is absent. Commit `ad414a6 replace space with tab` deliberately changed `space:toggle` → `tab:toggle`, but AC 2 requires "Space (or Tab)". Add `space:toggle` back alongside `tab:toggle`.

### FZF_MULTI Fix (Task 1)

Current (`~line 31`):
```bash
FZF_MULTI=("${FZF_COMMON[@]}" --multi --bind=tab:toggle,ctrl-a:toggle-all)
```

Replace with:
```bash
FZF_MULTI=("${FZF_COMMON[@]}" --multi --bind=space:toggle,tab:toggle,ctrl-a:toggle-all)
```

And update `FZF_HEADER_ROLES` (`~line 35`):
```bash
# Current:
FZF_HEADER_ROLES="--header=Tab=select  Enter=confirm  Ctrl-A=all  Esc=back"
# New:
FZF_HEADER_ROLES="--header=Space/Tab=select  Enter=confirm  Ctrl-A=all  Esc=back"
```

**Why this is safe:** `space:toggle` and `tab:toggle` are independent bindings — they don't conflict. Both call the same `toggle` action. `ctrl-a:toggle-all` is unchanged.

### Session Caching Pattern (Verify, Don't Change)

`CACHE_ARM` stores the **formatted lines** (not raw JSON), because the ARM flow aggregates across multiple subscriptions. If you need to change this, be careful — `CACHE_ENTRA` and `CACHE_GROUPS` store **raw JSON** (consumed by format functions at pick time). Do NOT unify them — the difference is intentional.

`CACHE_SUBS` stores newline-separated subscription IDs from the `pick_subscriptions()` output. On back-nav to Azure Resources, if `CACHE_ARM` is populated, both the sub picker and API calls are skipped entirely. If only `CACHE_SUBS` is populated (shouldn't happen in normal flow), only the sub picker is skipped.

Cache variables are **global bash variables** — they persist across the main loop iterations. They are NOT reset between category selections. This is the correct behavior (FR14: cache per session for back-navigation).

### Previous Selection Restoration Pattern (Verify, Don't Change)

`pick_roles(lines, prev_selections)` in the current script (~line 449):
1. Reads `$lines` line by line
2. Splits into `matched_lines` (in `prev_selections`) and `other_lines` (not in `prev_selections`)
3. Puts matched lines first, then others — so previously selected items float to the top
4. Generates a fzf `--bind=start:<toggle+down+toggle...>` sequence to pre-toggle the first N matched items
5. Passes `$bind_arg` as an extra argument to fzf

The fzf `start:` event fires when fzf initializes — it executes the toggle sequence before the user sees anything. This makes previously selected items appear pre-checked immediately.

**Key constraint:** The `prev_selections` variable passed into each flow function is the raw multi-line fzf output from `pick_roles` — each line is `"DisplayText\tMETADATA"`. The comparison uses `grep -qxF` (exact line match, no regex). This means the full `DISPLAY\tMETADATA` string must match exactly for restoration to work. This is correct — the metadata makes each line unique.

The main loop passes selected roles through correctly:
```bash
# main() inner loop
local selected_roles=""   # prev selections accumulate here
...
"roles")
    new_roles=$(flow_entra_roles "$selected_roles") || break
    selected_roles="$new_roles"
    step="duration"
    ;;
```
On back-navigation (Esc at duration picker → `step="roles"`), the next `flow_*` call receives the previously selected roles.

### What NOT to Build

- **Do NOT** add persistent caching (file-based) — session caching in bash variables is the scope of this story (FR14 explicitly says "per session")
- **Do NOT** add deduplication to ARM results — already handled (unique scope paths)
- **Do NOT** change the `CACHE_ARM` format from lines to JSON — the aggregation across subscriptions makes JSON awkward
- **Do NOT** reset caches between category selections — caches persist for the full session (correct behavior)
- **Do NOT** implement any activation logic — that's Epic 3

### Existing Code to Reuse (Do Not Reinvent)

- `FZF_MULTI` array (~line 31) — **modify this** (add `space:toggle`)
- `FZF_HEADER_ROLES` string (~line 35) — **modify this** (add Space to header)
- `pick_roles()` (~line 449) — **do not change** — verify it works
- `flow_entra_roles()` (~line 547) — **do not change** — verify it works
- `flow_pim_groups()` (~line 572) — **do not change** — verify it works
- `flow_azure_resources()` (~line 597) — **do not change** — verify it works
- `CACHE_ENTRA/GROUPS/ARM/SUBS` (~line 43) — **do not change** — verify scope

### Project Structure Notes

- Single file: `pim-me-up` — only file modified
- Section order is unchanged: Constants → Utilities → API → Display → UI Flow → Activation → main
- The two changes are in Constants section only (`FZF_MULTI` and `FZF_HEADER_ROLES`)

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.3] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/prd.md#Functional Requirements] — FR7 (state preservation), FR8 (fuzzy search), FR9 (multi-select Tab), FR14 (session caching)
- [Source: _bmad-output/planning-artifacts/prd.md#Non-Functional Requirements] — NFR4 (Esc back is instantaneous)
- [Source: _bmad-output/architecture.md#fzf Configuration] — FZF_MULTI array; space:toggle, tab:toggle, ctrl-a:toggle-all
- [Source: _bmad-output/implementation-artifacts/2-2-fetch-and-display-azure-resource-roles-with-subscription-picker.md#Dev Notes] — `"${FZF_MULTI[@]}"` array expansion pattern; confirmed working patterns
- [Source: git commit ad414a6] — "replace space with tab" — context for why space:toggle was removed

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

(none)

### Completion Notes List

### File List

- pim-me-up
