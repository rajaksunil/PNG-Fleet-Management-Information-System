#!/usr/bin/env bash
# Phase 1 (fms-framework-migration) — setup + DRY RUN helper for AWS Transform Custom.
# Run this INSIDE the WSL Ubuntu shell. It installs the toolchain if missing,
# then performs a DRY RUN only (no -x) so nothing in the repo is modified.
#
# After reviewing the dry-run output, run the real execution manually (see end of file).

set -euo pipefail

REPO="/mnt/d/PoC_ProjectCode/FMS_Code/png-fleet-management-information-system-main/png-fleet-management-information-system-main"
TD_NAME="fms-framework-migration-execution"
MCP_CONFIG="$REPO/transformation_definitions/mcp.json"

echo "==> 1. Checking toolchain"

# --- .NET 8 SDK ---
if ! command -v dotnet >/dev/null 2>&1; then
  echo "Installing .NET 8 SDK..."
  sudo apt-get update
  sudo apt-get install -y dotnet-sdk-8.0 || {
    # Fallback to Microsoft install script if the distro feed lacks the package
    curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 8.0
    export PATH="$HOME/.dotnet:$PATH"
  }
fi
echo "dotnet: $(dotnet --version)"

# --- Node.js 22+ ---
if ! command -v node >/dev/null 2>&1 || [ "$(node -v | sed 's/v\([0-9]*\).*/\1/')" -lt 22 ]; then
  echo "Installing Node.js 22..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
echo "node: $(node -v)"

# --- Git ---
command -v git >/dev/null 2>&1 || sudo apt-get install -y git
echo "git: $(git --version)"

# --- ATX CLI ---
if ! command -v atx >/dev/null 2>&1; then
  echo "Installing AWS Transform (ATX) CLI..."
  curl -fsSL https://transform-cli.awsstatic.com/install.sh | bash
fi
echo "atx: $(atx --version 2>/dev/null || echo 'installed (version flag may differ)')"

echo
echo "==> 2. Pre-flight checks"

# AWS credentials (needs AWSTransformCustomFullAccess)
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "!! AWS credentials not configured. Run 'aws configure' first (needs AWSTransformCustomFullAccess)."
  exit 1
fi
echo "AWS identity OK."

# Clean git tree (transformation edits code in place)
if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
  echo "!! Working tree is NOT clean. Commit or stash before executing (dry run is safe, real run is not)."
  git -C "$REPO" status --short
fi

# CAST MCP reachability from inside WSL (localhost on Windows != localhost in WSL)
echo "Checking CAST MCP reachability from WSL..."
if ! curl -fsS -m 5 http://localhost:8282/mcp >/dev/null 2>&1; then
  echo "!! Could not reach CAST MCP at localhost:8282 from WSL."
  echo "   From WSL, the Windows host is usually reachable via the host IP, not localhost."
  echo "   Try:  curl http://\$(ip route | awk '/default/ {print \$3}'):8282/mcp"
  echo "   Then edit the url in: $MCP_CONFIG"
fi

echo
echo "==> 3. DRY RUN (no -x; previews changes, modifies nothing)"
echo "    TD:   $TD_NAME"
echo "    Repo: $REPO"
echo

atx custom def exec \
  -n "$TD_NAME" \
  -p "$REPO" \
  -t \
  --mcp-config "$MCP_CONFIG"

echo
echo "==> Dry run complete. Review the output above."
echo "    To EXECUTE FOR REAL (edits the repo in place), on a clean git tree run:"
echo
echo "    atx custom def exec \\"
echo "      -n \"$TD_NAME\" \\"
echo "      -p \"$REPO\" \\"
echo "      -x -t \\"
echo "      --mcp-config \"$MCP_CONFIG\""
