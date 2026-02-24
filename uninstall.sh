#!/bin/bash
# ralph uninstaller — remove ralph-init from this machine
#
# Usage:
#   ./uninstall.sh              # Uninstall from default ~/.ralph
#   ./uninstall.sh /path/to    # Uninstall from custom location

set -euo pipefail

DEFAULT_RALPH_HOME="${HOME}/.ralph"
RALPH_HOME="${RALPH_HOME:-${1:-$DEFAULT_RALPH_HOME}}"

echo "Ralph Uninstaller"
echo "================="
echo "Target: ${RALPH_HOME}"
echo ""

if [[ ! -d "${RALPH_HOME}" ]]; then
    echo "No installation found at ${RALPH_HOME}"
    exit 0
fi

# Uninstall the pip package
echo "Removing ralph-init from pip..."
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
else
    echo "Warning: pip not found, skipping package removal"
    PIP_CMD=""
fi

if [[ -n "${PIP_CMD}" ]]; then
    ${PIP_CMD} uninstall -y ralph-init 2>/dev/null || true
fi

# Remove the installation directory
echo "Removing ${RALPH_HOME}..."
rm -rf "${RALPH_HOME}"

echo ""
echo "Done! Ralph has been uninstalled."
