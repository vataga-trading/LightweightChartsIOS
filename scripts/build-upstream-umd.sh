#!/bin/bash
# Reproducible build script for upstream lightweight-charts UMD artifact
# Usage: ./scripts/build-upstream-umd.sh [version]
# Example: ./scripts/build-upstream-umd.sh v5.2.0

set -e

# Version to build (defaults to v5.2.0)
VERSION=${1:-v5.2.0}
UPSTREAM_REPO=${LIGHTWEIGHT_CHARTS_REPO:-https://github.com/tradingview/lightweight-charts}
OUTPUT_FILE="Sources/LightweightCharts/Assets/lightweight-charts.js"

echo "Building lightweight-charts ${VERSION} UMD artifact..."
echo "Upstream source: ${UPSTREAM_REPO}"

# Resolve upstream source: local path or remote git URL
if [ -d "${UPSTREAM_REPO}" ]; then
    SOURCE_DIR="${UPSTREAM_REPO}"
    TEMP_CLONE=""
else
    TEMP_CLONE=$(mktemp -d)
    SOURCE_DIR="${TEMP_CLONE}/lightweight-charts"
    echo "Cloning upstream repo to temporary directory..."
    git clone --quiet "${UPSTREAM_REPO}" "${SOURCE_DIR}"

    # Clean up temporary clone on exit.
    trap 'rm -rf "${TEMP_CLONE}"' EXIT
fi

cd "${SOURCE_DIR}"

# Fetch tags and checkout exact version for reproducibility
echo "Fetching tags and checking out ${VERSION}..."
git fetch --tags
git checkout "${VERSION}"

# Install dependencies
echo "Installing dependencies..."
npm ci

# Clean previous build
echo "Cleaning previous build..."
npm run clean

# Build release artifacts (BUILD_TAG=release ensures clean version without timestamp)
echo "Building release artifacts..."
npm run build:release

# Verify artifact was built
ARTIFACT="${SOURCE_DIR}/dist/lightweight-charts.standalone.production.js"
if [ ! -f "${ARTIFACT}" ]; then
    echo "Error: Build artifact not found at ${ARTIFACT}"
    exit 1
fi

# Return to iOS wrapper directory
cd -

# Backup existing artifact
if [ -f "${OUTPUT_FILE}" ]; then
    echo "Backing up existing artifact..."
    cp "${OUTPUT_FILE}" "${OUTPUT_FILE}.backup"
fi

# Copy artifact
echo "Copying artifact to ${OUTPUT_FILE}..."
cp "${ARTIFACT}" "${OUTPUT_FILE}"

# Verify version in artifact
echo "Verifying artifact version..."
HEAD=$(head -5 "${OUTPUT_FILE}")
if echo "${HEAD}" | grep -q "Lightweight Charts.*${VERSION#v}"; then
    echo "✓ Artifact version confirmed: ${VERSION}"
else
    echo "Warning: Version mismatch in artifact header"
    echo "${HEAD}"
    exit 1
fi

# Show file size
SIZE=$(wc -c < "${OUTPUT_FILE}")
echo "✓ Build complete! Artifact size: ${SIZE} bytes"
