# pim-me-up

Fast Azure PIM elevation from your terminal using fzf.

Activate Entra ID roles, PIM groups, and Azure resource roles — all with fuzzy search and multi-select.

## Features

- **Four menu categories**: Active Assignments, Entra ID Roles, PIM Groups, Azure Resources
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
# Clone and symlink to PATH
git clone https://github.com/qbits/pim-me-up.git
ln -s "$(pwd)/pim-me-up/pim-me-up" ~/.local/bin/pim-me-up

# Or just copy it
cp pim-me-up /usr/local/bin/
```

## Usage

```bash
# Make sure you're logged in
az login

# Run it
pim-me-up
```

1. Select category (`Active Assignments`, `Entra ID Roles`, `PIM Groups`, or `Azure Resources`)
2. If you choose an activation category, search and select roles (Space for multi-select, Enter to confirm)
3. Pick duration
4. Enter justification
5. Done

## How it works

- **Entra ID Roles**: Queries Microsoft Graph API for eligible directory role assignments
- **PIM Groups**: Queries Graph API for eligible group memberships (member/owner)
- **Azure Subscriptions**: Select subscription(s), then queries ARM API for eligible resource roles

Authentication piggybacks on your Azure CLI session (`az account get-access-token`). No extra credentials or service principals needed.

# Improvements (TBA)

- Activate multiple roles in parallell for effiency

# Known bugs 

- Azure resources are not shown in active assignments 

## License

MIT
