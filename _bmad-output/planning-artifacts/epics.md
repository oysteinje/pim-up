---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories']
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/architecture.md'
---

# pim-me-up - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for pim-me-up, decomposing the requirements from the PRD and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

FR1: User can see dependency check results at startup (fzf, jq, az cli presence and az login state)
FR2: User can see currently active PIM assignments on startup (across all three categories)
FR3: System skips active assignment display if it would exceed 1 second latency
FR4: User can select a PIM category (Entra ID Roles, PIM Groups, Azure Resources)
FR5: User can press Esc at any step to return to the previous step
FR6: User can press Ctrl-C to exit the tool at any point
FR7: System preserves selection state when navigating back via Esc
FR8: User can fuzzy-search eligible roles within a selected category
FR9: User can multi-select roles using Tab in fzf
FR10: User can see human-readable role names and context (role name + scope/group/resource)
FR11: User can select subscriptions when in the Azure Resources category (before seeing roles)
FR12: System fetches eligible assignments from PIM Governance API (Entra Roles, PIM Groups)
FR13: System fetches eligible assignments from ARM API (Azure Resources)
FR14: System caches eligible assignments per category for the session (no re-fetch on back-navigation)
FR15: User can select an activation duration (1h / 2h / 4h / 8h)
FR16: User can enter a justification reason or accept a default
FR17: System activates selected roles in batch (one API call per role)
FR18: User can see per-role activation results (success with green checkmark, failure with red cross and error message)
FR19: System uses PIM Governance API for Entra Role and PIM Group activations (POST)
FR20: System uses ARM API for Azure Resource activations (PUT with client-generated UUID)

### NonFunctional Requirements

NFR1: Startup to first fzf prompt (including active assignment display) completes in under 2 seconds
NFR2: Active assignment fetch completes in under 1 second, or is skipped entirely
NFR3: Eligible role list appears within 3 seconds of category selection (API fetch + fzf render)
NFR4: Esc-to-go-back navigation is instantaneous (uses cached data, no re-fetch)
NFR5: The tool never stores, caches, or logs authentication tokens — all token management is delegated to az rest / az cli
NFR6: No credentials, secrets, or tokens appear in stdout output or error messages
NFR7: The tool works with any Azure tenant where the user has PIM eligible assignments and has run az login
NFR8: PIM Governance API calls use az rest --resource https://api.azrbac.mspim.azure.com for token scoping
NFR9: ARM API calls use default az rest token scoping (https://management.azure.com)
NFR10: The tool degrades gracefully if one API category fails (e.g., 403 on PIM Groups) — other categories remain usable

### Additional Requirements

- Single bash script structure with defined function organization (constants, utilities, API, display, UI flow, orchestration, main)
- fzf data flow pattern: DISPLAY_TEXT\tHIDDEN_METADATA with --with-nth=1 and --delimiter='\t'
- Auth via az rest exclusively — no MSAL, no app registrations
- Azure Resources requires subscription sub-flow before role selection
- Specific API endpoints and payload structures for both PIM Governance API and ARM API
- UUID generation via /proc/sys/kernel/random/uuid or uuidgen
- fzf configuration constants (FZF_COMMON, FZF_SINGLE, FZF_MULTI) as defined in architecture
- Dependencies: bash 4.0+, fzf 0.20+, jq 1.5+, az cli 2.40+, curl
- Error handling: fail fast on prerequisites, graceful degradation per-role during activation
- Lazy loading strategy: fetch eligible roles on category selection (not preloaded), cache per session for back-navigation

### UX Design Requirements

N/A — CLI tool with no UI design document.

### FR Coverage Map

FR1: Epic 1 - Dependency check at startup
FR2: Epic 1 - Active assignment display
FR3: Epic 1 - 1s timeout on active display
FR4: Epic 1 - Category picker
FR5: Epic 1 - Esc-to-go-back
FR6: Epic 1 - Ctrl-C exit
FR7: Epic 2 - State preservation on back-nav
FR8: Epic 2 - Fuzzy search roles
FR9: Epic 2 - Multi-select with Tab
FR10: Epic 2 - Human-readable role display
FR11: Epic 2 - Subscription picker (Azure Resources)
FR12: Epic 2 - PIM Governance API fetch
FR13: Epic 2 - ARM API fetch
FR14: Epic 2 - Session caching
FR15: Epic 3 - Duration picker
FR16: Epic 3 - Justification prompt
FR17: Epic 3 - Batch activation
FR18: Epic 3 - Per-role result reporting
FR19: Epic 3 - PIM Gov API activation
FR20: Epic 3 - ARM API activation

## Epic List

### Epic 1: Script Foundation & Startup
The user can run pim-me-up, see that all prerequisites are met, view currently active PIM assignments, and navigate the category picker. This delivers the "launch and orient" experience — the user knows the tool works and can see what's already active.
**FRs covered:** FR1, FR2, FR3, FR4, FR5, FR6
**NFRs addressed:** NFR1, NFR2, NFR5, NFR6

### Epic 2: Role Discovery & Selection
The user can browse and select eligible roles within any PIM category. This covers fetching from both APIs, formatting human-readable output, subscription scoping for Azure Resources, fuzzy search, multi-select, and session caching. After this epic, the user can discover and choose roles — the core value of the tool.
**FRs covered:** FR7, FR8, FR9, FR10, FR11, FR12, FR13, FR14
**NFRs addressed:** NFR3, NFR4, NFR7, NFR8, NFR9, NFR10

### Epic 3: Activation & Results
The user can configure and execute activations — pick duration, enter justification, batch-activate, and see per-role success/failure. This completes the end-to-end flow. After this epic, the tool fully replaces the PIM portal.
**FRs covered:** FR15, FR16, FR17, FR18, FR19, FR20

## Epic 1: Script Foundation & Startup

The user can run pim-me-up, see that all prerequisites are met, view currently active PIM assignments, and navigate the category picker.

### Story 1.1: Dependency Check & Script Bootstrap

As a platform engineer,
I want the script to verify all required tools are present and I'm logged in,
So that I get a clear error message instead of cryptic failures.

**Acceptance Criteria:**

**Given** the user runs `pim-me-up`
**When** fzf, jq, or az cli is not installed
**Then** the script prints which dependencies are missing and exits with code 1

**Given** the user runs `pim-me-up`
**When** all dependencies are present but `az login` has not been run
**Then** the script prints "Run `az login` first" and exits with code 1

**Given** the user runs `pim-me-up`
**When** all dependencies are present and `az login` is active
**Then** the script retrieves the user's object ID and proceeds to the next step

**Given** the user is logged in
**When** the startup sequence runs
**Then** the current tenant/organization name is clearly displayed so the user can confirm they're in the right context

### Story 1.2: Active Assignment Display

As a platform engineer,
I want to see my currently active PIM assignments when the tool starts,
So that I know what's already elevated before selecting new roles.

**Acceptance Criteria:**

**Given** the user passes dependency checks
**When** active assignments can be fetched within 1 second
**Then** a summary of active assignments across all three categories is displayed

**Given** the user passes dependency checks
**When** the active assignment fetch exceeds 1 second
**Then** the display is skipped and the tool proceeds to the category picker

**Given** the user has no active assignments
**When** the tool starts
**Then** a brief "No active assignments" message is shown (or the section is omitted)

### Story 1.3: Category Picker & Navigation Shell

As a platform engineer,
I want to select a PIM category and navigate back with Esc,
So that I can move between steps without restarting the tool.

**Acceptance Criteria:**

**Given** active assignment display completes (or is skipped)
**When** the category picker appears
**Then** the user sees three options: "Entra ID Roles", "PIM Groups", "Azure Resources"

**Given** the user is at any fzf step beyond the category picker
**When** the user presses Esc
**Then** the tool returns to the previous step

**Given** the user is at the category picker
**When** the user presses Esc or Ctrl-C
**Then** the tool exits cleanly with exit code 0

**Given** the startup sequence completes
**When** the category picker is displayed
**Then** the total time from command launch to fzf prompt is under 2 seconds

## Epic 2: Role Discovery & Selection

The user can browse and select eligible roles within any PIM category, with fuzzy search, multi-select, subscription scoping, and session caching.

### Story 2.1: Fetch & Display Entra ID Roles and PIM Groups

As a platform engineer,
I want to see my eligible Entra ID Roles and PIM Groups with human-readable names,
So that I can quickly find and select the roles I need.

**Acceptance Criteria:**

**Given** the user selects "Entra ID Roles" or "PIM Groups" from the category picker
**When** the tool fetches eligible assignments
**Then** it calls the PIM Governance API with the correct endpoint for the selected category and `az rest --resource https://api.azrbac.mspim.azure.com`

**Given** eligible assignments are returned
**When** the role list is displayed in fzf
**Then** each line shows human-readable format: "RoleName | ResourceName" (Entra) or "GroupName | member/owner" (Groups)
**And** hidden metadata (roleDefinitionId, resourceId) is carried via tab-delimited field

**Given** no eligible assignments exist for the selected category
**When** the API returns an empty list
**Then** the tool shows "No eligible assignments found for <category>" and returns to the category picker

**Given** the API returns a 403 or other error
**When** the fetch fails
**Then** the tool reports the error and returns to the category picker (other categories remain usable)

**Given** the user selects a category
**When** the role list appears
**Then** it renders within 3 seconds of category selection

### Story 2.2: Fetch & Display Azure Resource Roles with Subscription Picker

As a platform engineer,
I want to pick subscriptions and see eligible Azure resource roles scoped to them,
So that I can discover and activate resource-level roles.

**Acceptance Criteria:**

**Given** the user selects "Azure Resources" from the category picker
**When** the subscription picker appears
**Then** it shows available subscriptions from `az account list` in fzf with multi-select

**Given** the user selects one or more subscriptions
**When** the tool fetches eligible resource roles
**Then** it calls the ARM API for each selected subscription and aggregates the results

**Given** eligible resource roles are returned
**When** the role list is displayed
**Then** each line shows "RoleName | Scope" with hidden metadata (roleDefinitionId, scope)

**Given** no eligible resource roles exist for the selected subscriptions
**When** the API returns empty
**Then** the tool shows "No eligible assignments found" and returns to the category picker

### Story 2.3: Multi-Select, Fuzzy Search & Session Caching

As a platform engineer,
I want to fuzzy-search roles, multi-select with Space, and not re-fetch on back-navigation,
So that the selection experience is fast and fluid.

**Acceptance Criteria:**

**Given** a role list is displayed in fzf
**When** the user types a search term
**Then** the list filters by fuzzy match in real time

**Given** a role list is displayed in fzf
**When** the user presses Space (or Tab) on a role
**Then** the role is toggled for selection and multiple roles can be selected

**Given** a role list is displayed in fzf
**When** the user presses Ctrl-A
**Then** all visible roles are toggled for selection

**Given** the user has previously fetched eligible roles for a category
**When** the user navigates back to that category via Esc
**Then** the cached results are displayed instantly without re-fetching from the API

**Given** the user navigates back from role selection to the category picker
**When** they re-enter the same category
**Then** their previous selections are preserved

## Epic 3: Activation & Results

The user can configure and execute activations — pick duration, enter justification, batch-activate, and see per-role success/failure results.

### Story 3.1: Duration Picker & Justification Prompt

As a platform engineer,
I want to pick an activation duration and enter a justification,
So that I can configure my elevation before activating.

**Acceptance Criteria:**

**Given** the user has selected one or more roles
**When** the duration picker appears
**Then** it shows four options via fzf: 1h, 2h, 4h, 8h

**Given** the user selects a duration
**When** the justification prompt appears
**Then** the user can type a custom reason or press Enter to accept a default value

**Given** the user is at the duration picker or justification prompt
**When** the user presses Esc
**Then** the tool returns to the previous step (role selection or duration picker respectively)

### Story 3.2: Batch Activation & Result Reporting

As a platform engineer,
I want all my selected roles activated in batch with clear success/failure feedback,
So that I know exactly which roles are active and can act on any failures.

**Acceptance Criteria:**

**Given** the user has selected roles, duration, and justification
**When** the selected roles are Entra ID Roles or PIM Groups
**Then** the tool sends a POST to the PIM Governance API with the correct payload (roleDefinitionId, resourceId, subjectId, assignmentState, reason, schedule with PT<N>H duration)

**Given** the user has selected Azure Resource roles
**When** activation is triggered
**Then** the tool sends a PUT to the ARM API with a client-generated UUID and the correct payload (principalId, roleDefinitionId, requestType=SelfActivate, justification, scheduleInfo)

**Given** multiple roles are selected
**When** activation runs
**Then** each role is activated individually (one API call per role) and results are collected

**Given** activation completes for all selected roles
**When** results are displayed
**Then** each successful role shows a green checkmark with the role name
**And** each failed role shows a red cross with the role name and error message

**Given** one role activation fails
**When** more roles remain in the batch
**Then** the tool continues activating remaining roles (does not abort the batch)
