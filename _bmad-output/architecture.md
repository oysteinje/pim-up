# pim-me-up — Architecture

## Overview

A single bash script that provides fast Azure PIM elevation from the terminal. Users fuzzy-search eligible roles across three PIM categories, multi-select, pick a duration, and activate — all without leaving the shell.

**Stack:** bash + fzf + jq + az cli (+ curl for activation calls)

## High-Level Flow

```
az login (prerequisite)
       │
       ▼
┌─────────────┐
│  pim-me-up  │
└──────┬──────┘
       │
       ▼
┌──────────────────┐     fzf
│ Category picker   │◄──────────  "Entra ID Roles / PIM Groups / Azure Resources"
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Fetch eligible    │──── az rest ──► PIM Governance API / ARM API
│ assignments       │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐     fzf --multi
│ Role selector     │◄──────────  fuzzy search, Tab multi-select
└──────┬───────────┘
       │
       ▼
┌──────────────────┐     fzf
│ Duration picker   │◄──────────  1h / 2h / 4h / 8h
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Justification     │◄──────────  read -p (free text, or default)
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Activate (batch)  │──── az rest / curl ──► API per role
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Results report    │──── stdout: ✓ role / ✗ role (error)
└──────────────────┘
```

## API Surface

Two API backends serve three PIM categories:

### PIM Governance API (`api.azrbac.mspim.azure.com`)

Used for Entra ID Roles and PIM Groups. Works with standard `az rest` tokens — no special permissions or MSAL needed.

| Category | List Eligible | Activate |
|---|---|---|
| Entra ID Roles | `GET /api/v2/privilegedAccess/aadroles/roleAssignments?$filter=subjectId eq '{userId}' and assignmentState eq 'Eligible'` | `POST /api/v2/privilegedAccess/aadroles/roleAssignmentRequests` |
| PIM Groups | `GET /api/v2/privilegedAccess/aadGroups/roleAssignments?$filter=subjectId eq '{userId}' and assignmentState eq 'Eligible'` | `POST /api/v2/privilegedAccess/aadGroups/roleAssignmentRequests` |

**Token resource:** `https://api.azrbac.mspim.azure.com`

**Activation payload (both categories):**
```json
{
  "roleDefinitionId": "<roleDefinitionId>",
  "resourceId": "<resourceId>",
  "subjectId": "<userId>",
  "assignmentState": "Active",
  "type": "UserAdd",
  "reason": "<justification>",
  "schedule": {
    "type": "Once",
    "startDateTime": "<now ISO8601>",
    "duration": "PT<N>H"
  }
}
```

### ARM API (`management.azure.com`)

Used for Azure resource roles (subscriptions, resource groups, resources).

| Operation | Endpoint |
|---|---|
| List eligible | `GET /providers/Microsoft.Authorization/roleEligibilityScheduleInstances?$filter=asTarget() and status eq 'Provisioned'&api-version=2020-10-01` |
| Activate | `PUT /{scope}/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/{new-guid}?api-version=2020-10-01` |

**Token resource:** `https://management.azure.com` (default for `az rest`)

**Activation payload:**
```json
{
  "properties": {
    "principalId": "<userId>",
    "roleDefinitionId": "<roleDefinitionId>",
    "requestType": "SelfActivate",
    "justification": "<justification>",
    "scheduleInfo": {
      "startDateTime": "<now ISO8601>",
      "expiration": {
        "type": "AfterDuration",
        "duration": "PT<N>H"
      }
    }
  }
}
```

**Key difference:** ARM uses PUT with a client-generated UUID, not POST.

## Script Structure

Single file `pim-me-up`, organized as functions:

```
pim-me-up
├── Constants & configuration
│   ├── PIM_API="https://api.azrbac.mspim.azure.com"
│   ├── ARM_API="https://management.azure.com"
│   └── DURATION_OPTIONS, COLORS, etc.
│
├── Utility functions
│   ├── die()              — print error + exit
│   ├── check_deps()       — verify fzf, jq, az are available
│   ├── get_user_id()      — az ad signed-in-user show → objectId
│   ├── gen_uuid()         — cat /proc/sys/kernel/random/uuid (or uuidgen)
│   └── iso_now()          — date -u +%Y-%m-%dT%H:%M:%SZ
│
├── API functions
│   ├── pim_list_eligible(category)    — GET eligible assignments
│   ├── pim_activate(category, payload) — POST activation request
│   ├── arm_list_eligible()             — GET eligible resource roles
│   └── arm_activate(scope, payload)    — PUT activation request
│
├── Display formatting
│   ├── format_entra_roles(json)  — jq → "RoleName | ResourceName"
│   ├── format_pim_groups(json)   — jq → "GroupName | Type(member/owner)"
│   └── format_arm_roles(json)    — jq → "RoleName | Scope"
│
├── UI flow functions
│   ├── pick_category()       — fzf single-select
│   ├── pick_roles(lines)     — fzf --multi
│   ├── pick_duration()       — fzf single-select
│   ├── get_justification()   — read -p with default
│   └── pick_subscriptions()  — fzf --multi (for Azure Resources only)
│
├── Activation orchestration
│   ├── activate_batch(selections, duration, justification)
│   │   └── loops over selections, calls appropriate API
│   └── report_results(results)
│
└── main()
    ├── check_deps
    ├── get_user_id
    ├── pick_category
    ├── fetch eligible → format → pick_roles
    ├── pick_duration
    ├── get_justification
    ├── activate_batch
    └── report_results
```

## Data Flow Through fzf

Each fzf selection line carries structured data so we can map the display back to API parameters:

```
# Format: DISPLAY_TEXT \t HIDDEN_METADATA
# fzf shows DISPLAY_TEXT, we parse HIDDEN_METADATA after selection

# Entra ID Roles:
"Global Reader | Entra ID\troleDefId=abc&resourceId=def"

# PIM Groups:
"SG-Prod-Admin | member\troleDefId=abc&resourceId=def"

# Azure Resources:
"Contributor | sub-name/rg-name\troleDefId=abc&scope=/subscriptions/..."
```

Using fzf's `--with-nth=1` and `--delimiter='\t'` to show only the display column. After selection, split on `\t` and parse the metadata.

## Azure Resources Sub-flow

Azure resource roles require an extra step — subscription selection — because the ARM eligible role list is scoped per subscription (or can be fetched globally but is slow).

```
pick_category → "Azure Resources"
       │
       ▼
pick_subscriptions()          ◄── az account list → fzf --multi
       │
       ▼
for each subscription:
  arm_list_eligible(sub_id)   ◄── ARM API
       │
       ▼
aggregate & deduplicate
       │
       ▼
pick_roles (unified list with scope shown)
```

## Auth Strategy

**Single auth method:** `az rest` handles all token management.

- PIM Governance API: `az rest --resource https://api.azrbac.mspim.azure.com --method GET --url ...`
- ARM API: `az rest --method GET --url ...` (ARM is the default resource)

**Prerequisite:** User must have run `az login`. The script checks this at startup via `az ad signed-in-user show` — if it fails, print a message and exit.

**No MSAL, no device code flow, no app registrations, no special client IDs.**

## Error Handling

| Scenario | Strategy |
|---|---|
| Missing dependency (fzf/jq/az) | `check_deps` at startup, list what's missing, exit 1 |
| Not logged in | `get_user_id` fails → "Run `az login` first", exit 1 |
| API returns empty eligible list | Show "No eligible assignments found for <category>", return to category picker |
| Individual activation fails | Continue batch, collect errors, report at end |
| 403 on a category | Report the error, suggest the category may not be enabled in the tenant |
| Network timeout | `az rest` has built-in retry; if it still fails, report per-role |
| User cancels fzf (Esc/Ctrl-C) | fzf exits non-zero → script exits cleanly |

**Philosophy:** Fail fast on prerequisites, graceful degradation per-role during activation.

## fzf Configuration

```bash
FZF_COMMON="--height=~50% --border --margin=1,2"
FZF_SINGLE="$FZF_COMMON --no-multi"
FZF_MULTI="$FZF_COMMON --multi --bind='space:toggle,ctrl-a:toggle-all'"
FZF_HEADER_CATEGORY="--header='Select PIM category'"
FZF_HEADER_ROLES="--header='Space=select, Enter=confirm, Ctrl-A=all'"
FZF_HEADER_DURATION="--header='Select activation duration'"
```

**fzf version note:** `--height=~50%` (dynamic height) requires fzf 0.30+. Fall back to `--height=50%` on older versions, or just don't set it.

## Future Considerations (Not in v1)

These are explicitly **out of scope** for the initial implementation but noted as natural extensions:

- **Favorites / profiles** — save common role combos to a config file, activate with one command
- **`--activate <profile>` flag** — speed mode, skip all fzf prompts
- **Status check** — show currently active PIM assignments
- **Deactivation** — deactivate roles early
- **Notifications** — alert when activation is about to expire
- **Parallel activation** — background `az rest` calls with `&` + `wait`

## Dependencies & Distribution

| Dependency | Min Version | Check |
|---|---|---|
| bash | 4.0+ | arrays, associative arrays |
| fzf | 0.20+ | `--multi`, `--with-nth` (0.30+ for `--height=~`) |
| jq | 1.5+ | standard filters |
| az cli | 2.40+ | `az rest --resource` support |
| curl | any | fallback if `az rest` insufficient |

**Distribution:** Single script file. Clone repo or copy `pim-me-up` to `$PATH`. No compilation, no package manager, no runtime dependencies beyond the above.
