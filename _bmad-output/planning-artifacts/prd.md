---
stepsCompleted: ['step-01-init', 'step-02-discovery', 'step-02b-vision', 'step-02c-executive-summary', 'step-03-success', 'step-04-journeys', 'step-05-domain-skipped', 'step-06-innovation-skipped', 'step-07-project-type', 'step-08-scoping', 'step-09-functional', 'step-10-nonfunctional', 'step-11-polish', 'step-12-complete']
inputDocuments:
  - '_bmad-output/brainstorming/brainstorming-session-2026-03-31-1540.md'
  - '_bmad-output/architecture.md'
documentCounts:
  briefs: 0
  research: 0
  brainstorming: 1
  projectDocs: 1
classification:
  projectType: cli_tool
  domain: general
  complexity: low
  projectContext: greenfield
workflowType: 'prd'
---

# Product Requirements Document - pim-me-up

**Author:** Oystein
**Date:** 2026-04-02

## Executive Summary

pim-me-up is a single bash script that replaces the slow, multi-step Azure PIM portal workflow with a fast terminal-based activation flow. The user runs one command, fuzzy-searches eligible roles across Entra ID Roles, PIM Groups, and Azure Resources, multi-selects, picks a duration, and activates — all in seconds. Built for a single user (the author) to eliminate ~30 minutes of daily PIM friction and context switching.

### What Makes This Special

Radical simplicity. No compiled binary, no framework, no runtime — just bash, fzf, jq, and az cli. The key technical insight is that the PIM Governance API (`api.azrbac.mspim.azure.com`) works with standard `az rest` tokens, eliminating the need for MSAL, device code flows, or special app registrations. This means the entire tool is a single readable script with zero opaque dependencies. The author trusts it because he can read every line. A future rewrite in Go remains an option if distribution becomes a goal.

## Project Classification

- **Project Type:** CLI tool — interactive terminal application with fzf-driven selection flows
- **Domain:** General (DevOps/Cloud Infrastructure tooling)
- **Complexity:** Low — no regulatory requirements, well-understood Azure APIs
- **Project Context:** Greenfield — new tool built from scratch
- **Target User:** Author (personal productivity tool)

## Success Criteria

### User Success

- **Daily driver:** The tool fully replaces the Azure PIM portal for role activation — the portal is never opened for PIM purposes.
- **Speed:** From command launch to activation complete in under 15 seconds for a typical single-role activation.
- **Discoverability:** Eligible roles are immediately visible and searchable — no guessing what's available.
- **Trust:** Every line of code is readable and understandable by the author.

### Business Success

Not applicable — personal productivity tool. Success = daily use and zero portal visits.

### Technical Success

- **Startup latency:** Active assignment display loads in under 1 second, or is skipped.
- **Activation reliability:** Activations succeed on first attempt (matching portal success rate).
- **Zero external dependencies:** No compilation, no package manager, no runtime beyond bash/fzf/jq/az cli.
- **Single file:** Entire tool lives in one script.

### Measurable Outcomes

- PIM portal not visited for activation in 30 consecutive days
- All three PIM categories (Entra ID Roles, PIM Groups, Azure Resources) functional
- Startup-to-first-fzf-prompt in under 2 seconds (including active assignment display)

## Product Scope

### MVP Strategy

**Approach:** Problem-solving MVP — the minimum that makes the PIM portal unnecessary for the author's daily work.
**Resource Requirements:** Single developer (the author). No dependencies on other people.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Morning PIM activation (Journey 1)
- Mid-day re-activation (Journey 2)
- Discovery of eligible roles (Journey 3)

**Must-Have Capabilities:**
- Dependency check at startup (fzf, jq, az cli, logged-in state)
- Active assignment display on startup (sub-1s constraint — skip if too slow)
- Category picker (Entra ID Roles / PIM Groups / Azure Resources)
- Subscription picker (Azure Resources category only)
- Eligible role fetching via PIM Governance API and ARM API
- fzf fuzzy search with multi-select (Tab)
- Duration picker (1h / 2h / 4h / 8h)
- Justification prompt with default value
- Batch activation with per-role success/failure reporting
- fzf navigation loop with Esc-to-go-back between steps

### Growth Features (Phase 2)

- Favorites / profiles — save common role combos to a config file
- `--activate <profile>` — skip fzf, activate a saved profile directly
- Status-only mode — show active assignments without entering activation flow
- Early deactivation of active roles

### Vision (Phase 3)

- Parallel activation (background `az rest` calls with `&` + `wait`)
- Expiry notifications
- Go rewrite for single-binary distribution
- Shell completion for flags/profiles

### Risk Mitigation

**Technical Risks:**
- PIM Governance API is undocumented/unofficial — if it changes, the tool breaks. Mitigation: the API has been stable for years (pim-tui depends on it too); monitor for breakage.
- `az rest` token caching behavior may vary across az cli versions. Mitigation: pin minimum az cli version (2.40+), test on the author's actual environment.
- fzf Esc-to-go-back loop adds state management complexity to a bash script. Mitigation: keep the navigation stack simple (variables, not data structures).

**Market Risks:** None — personal tool with audience of one.
**Resource Risks:** None — single developer, no deadlines, no dependencies.

## User Journeys

### Journey 1: Morning PIM Activation (Primary Flow)

**Oystein, platform engineer, start of workday.**

Opens terminal. Runs `pim-me-up`. A brief line shows what's already active — nothing yet, fresh morning. The category picker appears. He picks "PIM Groups", fzf instantly shows all eligible groups. He types "prod" to narrow it down, Tabs three groups he needs for today's work, hits Enter. Duration picker: 8h. Justification: hits Enter for the default. Three activations fire — all succeed. He's working within 15 seconds of running the command.

**Before:** Open portal, wait for it to load, navigate to PIM, click through each category tab, search, activate one by one, enter justification each time. 10+ minutes, multiple page loads, context destroyed.

**After:** One command, one flow, done. Never left the terminal.

### Journey 2: Mid-Day Re-Activation

**Oystein, 4 hours into the day, roles expiring.**

Runs `pim-me-up`. The startup display shows his morning roles are about to expire or already have. Picks the same category, sees familiar roles, re-selects, picks 4h this time. Activates. Back to work in seconds.

**Before:** Notices a 403 in some tool, realizes PIM expired, sighs, opens portal again. Sometimes just stops working instead.

**After:** Quick re-up, no friction, no context switch.

### Journey 3: Discovery — New Subscription

**Oystein, assigned to a new project, doesn't know what roles he has.**

Runs `pim-me-up`, picks "Azure Resources", picks the new subscription. fzf shows all eligible roles across resource groups. He scans the list, fuzzy-searches to explore, discovers he has Contributor on two resource groups he didn't know about. Selects what he needs, activates.

**Before:** Asks a colleague or digs through the portal trying to find what's assigned where.

**After:** Self-service discovery in seconds.

### Journey Requirements Summary

| Capability | Revealed By |
|---|---|
| Active assignment display on startup | Journey 1, 2 |
| Category picker → fzf role selection → duration → justification → activate | Journey 1, 2, 3 |
| Multi-select with batch activation | Journey 1 |
| Fuzzy search for discoverability | Journey 3 |
| Subscription scoping for Azure Resources | Journey 3 |
| Default justification for speed | Journey 1, 2 |

## CLI Tool Specific Requirements

### Command Structure

Single command `pim-me-up` with no subcommands or flags (MVP). The tool operates as an **fzf navigation loop**:

1. Active assignments display (startup, sub-1s)
2. Category picker (Entra ID Roles / PIM Groups / Azure Resources)
3. Role selector (fzf --multi, fuzzy search, Tab to multi-select)
4. Duration picker (1h / 2h / 4h / 8h)
5. Justification prompt (free text with default)
6. Activation (batch, with per-role result reporting)

**Esc at any step returns to the previous step.** Ctrl-C exits the tool entirely.

### Output Format

Human-readable stdout only. Colored terminal output:
- Success: green checkmark per activated role
- Failure: red cross with error message per role
- Startup: brief active assignment summary

No JSON or machine-readable output. No log files.

### Configuration

Zero-config. No config file, no environment variables (beyond `az login` state). All options are presented interactively via fzf. Durations are hardcoded. Default justification is inline.

### Scripting Support

Not in MVP. Future `--activate <profile>` flag planned for Growth scope.

### Implementation Considerations

- fzf loop requires tracking "navigation stack" state to support Esc-to-go-back
- Each fzf step must capture selection state so it can be restored on back-navigation
- `az rest` calls should only happen once per category (cache eligible assignments for the session)

## Functional Requirements

### Startup & Prerequisites

- FR1: User can see dependency check results at startup (fzf, jq, az cli presence and az login state)
- FR2: User can see currently active PIM assignments on startup (across all three categories)
- FR3: System skips active assignment display if it would exceed 1 second latency

### Navigation & Flow Control

- FR4: User can select a PIM category (Entra ID Roles, PIM Groups, Azure Resources)
- FR5: User can press Esc at any step to return to the previous step
- FR6: User can press Ctrl-C to exit the tool at any point
- FR7: System preserves selection state when navigating back via Esc

### Role Discovery & Selection

- FR8: User can fuzzy-search eligible roles within a selected category
- FR9: User can multi-select roles using Tab in fzf
- FR10: User can see human-readable role names and context (role name + scope/group/resource)
- FR11: User can select subscriptions when in the Azure Resources category (before seeing roles)
- FR12: System fetches eligible assignments from PIM Governance API (Entra Roles, PIM Groups)
- FR13: System fetches eligible assignments from ARM API (Azure Resources)
- FR14: System caches eligible assignments per category for the session (no re-fetch on back-navigation)

### Activation Configuration

- FR15: User can select an activation duration (1h / 2h / 4h / 8h)
- FR16: User can enter a justification reason or accept a default

### Activation Execution

- FR17: System activates selected roles in batch (one API call per role)
- FR18: User can see per-role activation results (success with green checkmark, failure with red cross and error message)
- FR19: System uses PIM Governance API for Entra Role and PIM Group activations (POST)
- FR20: System uses ARM API for Azure Resource activations (PUT with client-generated UUID)

## Non-Functional Requirements

### Performance

- NFR1: Startup to first fzf prompt (including active assignment display) completes in under 2 seconds
- NFR2: Active assignment fetch completes in under 1 second, or is skipped entirely
- NFR3: Eligible role list appears within 3 seconds of category selection (API fetch + fzf render)
- NFR4: Esc-to-go-back navigation is instantaneous (uses cached data, no re-fetch)

### Security

- NFR5: The tool never stores, caches, or logs authentication tokens — all token management is delegated to `az rest` / `az cli`
- NFR6: No credentials, secrets, or tokens appear in stdout output or error messages

### Integration

- NFR7: The tool works with any Azure tenant where the user has PIM eligible assignments and has run `az login`
- NFR8: PIM Governance API calls use `az rest --resource https://api.azrbac.mspim.azure.com` for token scoping
- NFR9: ARM API calls use default `az rest` token scoping (`https://management.azure.com`)
- NFR10: The tool degrades gracefully if one API category fails (e.g., 403 on PIM Groups) — other categories remain usable
