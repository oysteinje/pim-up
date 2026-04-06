---
stepsCompleted: [1, 2, 3]
inputDocuments: []
session_topic: 'CLI tool for simplified Azure PIM elevation across resources, Entra ID groups, and Entra ID roles'
session_goals: 'Unified discoverable PIM activation with search, selection, and duration control from the terminal'
selected_approach: 'ai-recommended'
techniques_used: ['question-storming', 'analogical-thinking']
ideas_generated: []
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Oystein
**Date:** 2026-03-31

## Session Overview

**Topic:** CLI tool for simplified Azure PIM elevation across resources, Entra ID groups, and Entra ID roles
**Goals:** Unified discoverable PIM activation with search, selection, and duration control from the terminal

### Session Setup

- Platform engineer focused on Azure
- Pain point: PIM activation is cumbersome across three categories (resources, groups, roles)
- Discoverability problem: hard to know what's available
- Target: Initially terminal-based CLI, but form factor is open for exploration
- Key features: search, select, choose duration, activate

## Technique Selection

**Approach:** AI-Recommended Techniques
**Analysis Context:** Azure PIM tooling with focus on discoverability and unified activation UX

**Recommended Techniques:**

- **Question Storming:** Map the full problem space before jumping to solutions
- **Analogical Thinking:** Draw parallels from tools that nail discoverability + quick-action UX
- **Constraint Mapping:** Skipped — existing tool discovery changed direction

## Technique Execution Results

### Question Storming (50 questions explored)

**Key Problem Clusters Identified:**

1. **Daily friction:** 30+ min/day on PIM activation + context switching cost, multiple times daily
2. **Discoverability gap:** Developers don't know what they're eligible for; onboarding takes too long
3. **Multi-activation pain:** One-by-one activation of common role combos across subscriptions
4. **Portal slowness:** Pages slow, search slow, multiple tabs open
5. **Cross-tool gap:** Oystein has PowerShell scripts but developers don't use PowerShell — scripts didn't spread despite LinkedIn interest from platform engineers
6. **Scope complexity:** Resources have hierarchy (mgmt group → subscription → resource group → resource), groups and roles are flat — hard to unify in one UI
7. **Security reality:** PIM friction is by design; developers want permanent access but need a middle ground
8. **Productivity killer:** Users sometimes stop working rather than re-PIM at end of day

**Open Design Tensions:**
- Flat search vs. hierarchical Azure reality
- Multi-select across different "shapes" of assignments
- Discovery mode vs. speed mode — same tool, different needs
- AI as optional layer, not a lock-in

### Analogical Thinking

**Key Analogies Explored:**

- **fzf:** Fuzzy search, instant narrowing, multi-select with Tab — Oystein's preferred interaction style
- **ripgrep/Slack/VS Code command palette:** Optional type prefixes (grp:, role:, res:) for power users, global search by default
- **kubectx:** Context switching as first-class operation
- **gh CLI:** Single binary, piggybacks on existing auth, replaced slow web UI
- **lazygit/lazydocker:** TUI wrappers — discoverability of GUI with speed of terminal

**Key Insight:** Discoverability and speed are two modes of the same tool, not conflicting requirements.

### Existing Tool Discovery

During analogical thinking, Oystein discovered **pim-tui** (github.com/seb07-cloud/pim-tui):

- Go + Bubble Tea TUI, single binary
- Tabs for Entra ID roles, PIM groups, Azure RBAC (Lighthouse)
- Multi-select, batch activation, fuzzy search
- Vim keybindings, duration presets (1-4 keys)
- Security tier awareness with color coding
- Piggybacks on `az login`
- MIT licensed, open source

**This tool covers ~80-90% of the brainstormed requirements.**

## Session Outcome & Decision (Updated 2026-04-02)

**Decision:** After evaluating pim-tui for several days, Oystein decided to build his own tool: **a bash script with fzf**.

**Rationale for building own tool:**
- Simpler — bash + fzf, no compilation, no Go dependency
- Lighter weight than a full TUI framework
- More accessible to the target audience (platform engineers and developers)
- Easier to install (single script vs. compiled binary)

### Early Prototype Spike (2026-04-02)

A quick implementation spike was done before architecture. Key technical learnings:

**API Surface — Three distinct APIs required:**

| Category | API | Token Resource | Activate Method |
|---|---|---|---|
| Entra ID Roles | Graph v1.0 `/roleManagement/directory/` | graph.microsoft.com | POST, action: selfActivate |
| PIM Groups | Graph v1.0 `/identityGovernance/privilegedAccess/group/` | graph.microsoft.com | POST, action: selfActivate |
| Azure Resources | ARM `/Microsoft.Authorization/` | management.azure.com | PUT with new GUID, requestType: SelfActivate |

**Key Technical Findings:**
1. **`az rest` > raw curl** — using `az rest` handles token management and scoping better than manual `az account get-access-token` + curl
2. **PIM Groups permission issue** — The Azure CLI's first-party app registration may lack `PrivilegedAccess.Read.AzureADGroup` permission in many tenants, causing 403 errors. Needs admin consent or alternative auth approach.
3. **fzf `--height=~50%`** — dynamic height syntax requires fzf 0.30+; need to handle older versions
4. **ARM API quirks** — resource role activation uses PUT (not POST) and requires a client-generated UUID in the URL path
5. **Role name resolution** — Entra roles support `$expand=roleDefinition` for display names; PIM groups and ARM roles require separate API calls to resolve human-readable names
6. **Scope hierarchy** — Azure resource roles can be scoped at management group, subscription, resource group, or resource level — scope must be shown in UI for disambiguation

### Auth Discovery — MSAL vs Azure CLI (2026-04-02)

Oystein's existing `~/pim_group_activate.py` reveals a critical auth insight:

**The Azure CLI app ID cannot access PIM Groups.** The solution is to use the **Microsoft Graph PowerShell public client ID** (`14d82eec-204b-4c2f-b7e8-296a70dab67e`) — a well-known first-party Microsoft app that already has tenant-wide consent for PIM scopes in most orgs. No app registration needed.

**How it works:**
- MSAL `PublicClientApplication` with device code flow
- Scopes: `PrivilegedAccess.ReadWrite.AzureADGroup` (and likely `RoleManagement.ReadWrite.Directory` for Entra roles)
- User authenticates once via browser, token is cached
- Uses Graph **beta** API, not v1.0

**Initial assumption (wrong):** MSAL device code flow needed for PIM Groups.

**Corrected finding:** pim-tui source code reveals that PIM Groups (and Entra roles) use the **PIM Governance API** (`api.azrbac.mspim.azure.com`), NOT Microsoft Graph. This API works with standard `AzureCLICredential` — no special permissions or MSAL flow needed.

**Implications for architecture:**
- Auth is simple: `azidentity.NewAzureCLICredential()` — piggybacks on `az login`
- No MSAL, no device code flow, no special client IDs needed
- Two API surfaces only: PIM Governance API + ARM API
- Go binary just needs user to have run `az login` first

**Architecture questions raised by the spike (to resolve in proper architecture):**
- How to handle the PIM Groups permission gap across different tenants?
- Should the three API categories be handled by a unified abstraction or kept separate?
- What's the right fzf interaction pattern for multi-step flows (subscription → roles)?
- How to support both discovery mode and speed mode in a single script?
- Error handling strategy — fail fast vs. graceful degradation per category?
- **Language choice:** Pure bash + fzf, Python + fzf subprocess, Go + fzf, or hybrid?
- **Auth strategy:** Single MSAL flow for everything, or dual auth (MSAL for Graph + az cli for ARM)?
- **Distribution:** Single script (Python) vs. compiled binary (Go) vs. bash + helper?

### Language Decision (2026-04-02) — REVISED

**Final decision: Bash + fzf + jq + az cli**

Evolution of decision:
1. Started with bash + fzf, hit 403 on PIM Groups via Microsoft Graph API
2. Pivoted to Go (MSAL for auth)
3. Discovered pim-tui uses PIM Governance API, not Graph → works with AzureCLICredential
4. Tested `az rest --resource https://api.azrbac.mspim.azure.com` → returns token
5. Tested PIM Governance API for groups via `az rest` → returns all eligible groups
6. **Bash is back** — no Go, no Python, no MSAL needed

**Confirmed working API surface:**

| Category | API Base | Resource for token |
|---|---|---|
| Entra ID Roles | `api.azrbac.mspim.azure.com/.../aadroles/` | `https://api.azrbac.mspim.azure.com` |
| PIM Groups | `api.azrbac.mspim.azure.com/.../aadGroups/` | `https://api.azrbac.mspim.azure.com` |
| Azure Resources | `management.azure.com/.../Microsoft.Authorization/` | `https://management.azure.com` |

**Dependencies:** bash, fzf, jq, az cli — nothing else.

**Key lesson:** The Microsoft Graph API requires special delegated permissions for PIM operations that the Azure CLI app doesn't have. The PIM Governance API (`api.azrbac.mspim.azure.com`) provides the same functionality and works with standard `az rest` tokens. This was discovered by reading pim-tui's source code.
