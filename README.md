# pim-me-up

Fast Azure PIM elevation from your terminal using fzf (within the limits of the PIM API, which can be quite slow).

Activate Entra ID roles, PIM groups, and Azure resource roles — all with fuzzy search and multi-select.

## Features

- **Four menu categories**: Active Assignments, Entra ID Roles, PIM Groups, Azure Resources
- **Azure Resources split view**: Choose `Subscriptions` or `Management Groups`
- **Fuzzy search**: Find roles instantly with fzf
- **Multi-select**: Activate multiple roles at once (Space to select)
- **Duration picker**: 1h / 2h / 4h / 8h
- **Batch activation**: Reports success/failure per role
- **Zero config**: Uses your existing `az login` session

## Dependencies

- [fzf](https://github.com/junegunn/fzf)
- [jq](https://jqlang.github.io/jq/)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- `curl`

## Install

```bash
# Quick install (user-local)
curl -fsSL https://raw.githubusercontent.com/qbits/pim-me-up/main/install.sh | bash

# System-wide install
curl -fsSL https://raw.githubusercontent.com/qbits/pim-me-up/main/install.sh | bash -s -- --system

# Manual install
git clone https://github.com/qbits/pim-me-up.git
install -m 755 pim-me-up/pim-me-up ~/.local/bin/pim-me-up
```

## Usage

```bash
# Make sure you're logged in
az login

# Run it
pim-me-up
```

1. Select category (`Active Assignments`, `Entra ID Roles`, `PIM Groups`, or `Azure Resources`)
2. If you choose `Azure Resources`, pick `Subscriptions` or `Management Groups`
3. If you choose `Active Assignments`, the tool shows your current assignments and returns you to the category picker
4. If you choose an activation category, search and select roles (Space for multi-select, Enter to confirm)
5. Pick duration
6. Enter justification
7. Done

## How it works

- **Entra ID Roles**: Queries Microsoft Graph API for eligible directory role assignments
- **PIM Groups**: Queries Graph API for eligible group memberships (member/owner)
- **Azure Subscriptions**: Select subscription(s), then query ARM API for eligible resource roles at subscription scope, including inherited management-group roles that can be activated against the chosen subscription
- **Azure Management Groups**: Select management group(s), then query ARM API for eligible management-group-scoped roles

Authentication piggybacks on your Azure CLI session (`az account get-access-token`). No extra credentials or service principals needed.

# Roadmap (TBA)

- Activate multiple roles in parallell for effiency

# Known bugs 

- Azure resources are not shown in active assignments 

## License

MIT
