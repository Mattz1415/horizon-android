#!/usr/bin/env bash
# scripts/build_horizon_facts.sh
# Automates running horizon-prepare on a PC/Linux machine with a JDK
# and packages the generated tables into horizon-facts-26.3.zip for Android.

set -euo pipefail

VERSION="26.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HORIZON_RUST_DIR="${HORIZON_RUST_DIR:-${ROOT_DIR}/../horizon}"
SERVER_JAR="${1:-server.jar}"
OUTPUT_ZIP="${ROOT_DIR}/app/src/main/assets/horizon-facts-${VERSION}.zip"

echo "========================================================"
echo "Horizon 26.3 Facts & Tables Builder for Android"
echo "========================================================"

if [ ! -f "${SERVER_JAR}" ]; then
    echo "Downloading Minecraft ${VERSION} server.jar..."
    MANIFEST_URL="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
    VERSION_URL=$(curl -s "${MANIFEST_URL}" | grep -o 'https://[^"]*'"${VERSION}"'[^"]*\.json' | head -n 1 || true)
    if [ -z "${VERSION_URL}" ]; then
        echo "Error: Could not locate version ${VERSION} in Mojang manifest."
        echo "Usage: $0 [path/to/server.jar]"
        exit 1
    fi
    SERVER_URL=$(curl -s "${VERSION_URL}" | grep -A 4 '"server":' | grep -o 'https://[^"]*\.jar')
    echo "Fetching server.jar from: ${SERVER_URL}"
    curl -L -o "${SERVER_JAR}" "${SERVER_URL}"
fi

echo "Verifying Horizon Rust codebase directory at: ${HORIZON_RUST_DIR}"
if [ ! -d "${HORIZON_RUST_DIR}" ]; then
    echo "Error: Horizon Rust repository not found at ${HORIZON_RUST_DIR}"
    exit 1
fi

echo "Running horizon-prepare to generate registries, blocks, and worldgen bundles..."
cd "${HORIZON_RUST_DIR}"
cargo run -p horizon-prepare -- --root "${HORIZON_RUST_DIR}" --prepare --server-jar "$(realpath "${SERVER_JAR}")"

PREPARED_DIR="${HORIZON_RUST_DIR}/.local/horizon-client/${VERSION}"
if [ ! -d "${PREPARED_DIR}" ]; then
    echo "Error: Expected output directory ${PREPARED_DIR} was not created."
    exit 1
fi

echo "Creating assets directory in Android project..."
mkdir -p "$(dirname "${OUTPUT_ZIP}")"

echo "Packaging generated facts into ${OUTPUT_ZIP}..."
rm -f "${OUTPUT_ZIP}"
cd "${PREPARED_DIR}"
zip -r "${OUTPUT_ZIP}" . -x "client.jar" -x "*.partial" -x "downloads/*"

echo "========================================================"
echo "Successfully generated: ${OUTPUT_ZIP}"
echo "Size: $(du -h "${OUTPUT_ZIP}" | cut -f1)"
echo "You can now build the Android APK and the facts will be bundled directly!"
echo "========================================================"
