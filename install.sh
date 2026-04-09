#!/usr/bin/env bash
set -euo pipefail

REPO_RAW_BASE="https://raw.githubusercontent.com/oysteinje/pim-me-up"
REF="main"
TARGET_DIR="${HOME}/.local/bin"
SYSTEM_INSTALL=0
SCRIPT_NAME="pim-me-up"

usage() {
    cat <<'EOF'
Usage: install.sh [--system] [--dir PATH] [--ref GIT_REF]

Options:
  --system      Install to /usr/local/bin (uses sudo when needed)
  --dir PATH    Install to a custom directory
  --ref REF     Install from a specific branch/tag/commit (default: main)
  -h, --help    Show this help
EOF
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Error: missing required command: %s\n' "$1" >&2
        exit 1
    }
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --system)
            SYSTEM_INSTALL=1
            TARGET_DIR="/usr/local/bin"
            shift
            ;;
        --dir)
            [[ $# -ge 2 ]] || {
                printf 'Error: --dir requires a value\n' >&2
                exit 1
            }
            TARGET_DIR="$2"
            shift 2
            ;;
        --ref)
            [[ $# -ge 2 ]] || {
                printf 'Error: --ref requires a value\n' >&2
                exit 1
            }
            REF="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Error: unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

require_cmd curl
require_cmd chmod
require_cmd mktemp

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

SCRIPT_URL="${REPO_RAW_BASE}/${REF}/${SCRIPT_NAME}"
printf 'Downloading %s...\n' "$SCRIPT_URL"
curl -fsSL "$SCRIPT_URL" -o "$TMP_FILE"
chmod +x "$TMP_FILE"

if [[ "$SYSTEM_INSTALL" -eq 1 ]]; then
    if [[ -w "$TARGET_DIR" ]]; then
        mv "$TMP_FILE" "${TARGET_DIR}/${SCRIPT_NAME}"
    else
        require_cmd sudo
        sudo mkdir -p "$TARGET_DIR"
        sudo mv "$TMP_FILE" "${TARGET_DIR}/${SCRIPT_NAME}"
    fi
else
    mkdir -p "$TARGET_DIR"
    mv "$TMP_FILE" "${TARGET_DIR}/${SCRIPT_NAME}"
fi

printf 'Installed %s to %s/%s\n' "$SCRIPT_NAME" "$TARGET_DIR" "$SCRIPT_NAME"

if ! command -v "$SCRIPT_NAME" >/dev/null 2>&1; then
    printf 'Note: ensure %s is in your PATH\n' "$TARGET_DIR"
fi
