#!/bin/bash
# ralph installer — install or update ralph-init from this volume
#
# Usage:
#   ./install.sh              # Install to default ~/.ralph
#   ./install.sh /path/to    # Install to custom location
#   RALPH_HOME=/path ./install.sh  # Alternative custom location

set -euo pipefail

# Source location (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target location
DEFAULT_RALPH_HOME="${HOME}/.ralph"
RALPH_HOME="${RALPH_HOME:-${1:-$DEFAULT_RALPH_HOME}}"

echo "Ralph Installer"
echo "==============="
echo "Source:  ${SCRIPT_DIR}"
echo "Target:  ${RALPH_HOME}"
echo ""

# Detect if this is a fresh install or update
if [[ -d "${RALPH_HOME}" ]]; then
    MODE="update"
    echo "Existing installation found — updating..."
else
    MODE="install"
    echo "Fresh installation..."
fi

# Create target directory
mkdir -p "${RALPH_HOME}"

# Files and directories to sync
SYNC_ITEMS=(
    "ralph_init"
    "templates"
    "pyproject.toml"
    "README.md"
    "CLAUDE.md"
    "ROADMAP.md"
)

# Optional items (only sync if they exist)
OPTIONAL_ITEMS=(
    "files"
    "references"
)

echo ""
echo "Syncing files..."

# Sync core items
for item in "${SYNC_ITEMS[@]}"; do
    src="${SCRIPT_DIR}/${item}"
    if [[ -e "${src}" ]]; then
        echo "  → ${item}"
        if [[ -d "${src}" ]]; then
            rsync -a --delete "${src}/" "${RALPH_HOME}/${item}/"
        else
            cp -f "${src}" "${RALPH_HOME}/${item}"
        fi
    else
        echo "  ! ${item} not found (skipping)"
    fi
done

# Sync optional items
for item in "${OPTIONAL_ITEMS[@]}"; do
    src="${SCRIPT_DIR}/${item}"
    if [[ -e "${src}" ]]; then
        echo "  → ${item} (optional)"
        if [[ -d "${src}" ]]; then
            rsync -a --delete "${src}/" "${RALPH_HOME}/${item}/"
        else
            cp -f "${src}" "${RALPH_HOME}/${item}"
        fi
    fi
done

echo ""
echo "Installing ralph-init CLI..."

# Install in editable mode so updates take effect immediately
cd "${RALPH_HOME}"

# Check if pip/pip3 is available
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
else
    echo "Error: pip not found. Please install Python 3.10+ with pip."
    exit 1
fi

# Install/reinstall the package
${PIP_CMD} install -e . --quiet --break-system-packages 2>/dev/null || \
${PIP_CMD} install -e . --quiet || {
    echo "Error: pip install failed"
    echo "Try running: ${PIP_CMD} install -e ${RALPH_HOME}"
    exit 1
}

# Verify installation
if command -v ralph-init &> /dev/null; then
    INSTALLED_PATH=$(which ralph-init)
    echo "  Installed: ${INSTALLED_PATH}"
else
    echo "  Warning: ralph-init not in PATH"
    echo "  You may need to add pip's bin directory to your PATH"
fi

# Record installation metadata
cat > "${RALPH_HOME}/.install-info" << EOF
installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
source_path=${SCRIPT_DIR}
mode=${MODE}
EOF

echo ""
echo "Done!"
echo ""

if [[ "${MODE}" == "install" ]]; then
    echo "Ralph installed to ${RALPH_HOME}"
    echo ""
    echo "Quick start:"
    echo "  cd your-project"
    echo "  ralph-init js --desc 'Your project description'"
    echo ""
    echo "Run 'ralph-init' for full usage information."
else
    echo "Ralph updated from ${SCRIPT_DIR}"
fi

echo ""
echo "To update later, run this script again from:"
echo "  ${SCRIPT_DIR}/install.sh"
