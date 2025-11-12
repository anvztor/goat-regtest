#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FOUNDRY_PROJECT="${PROJECT_ROOT}/data/deploy-contract"
OUTPUT_DIR="${PROJECT_ROOT}/data/relayer"

BRIDGE_ARTIFACT="${FOUNDRY_PROJECT}/out/DogecoinBridge.sol/DogecoinBridge.json"
ENTRY_ARTIFACT="${FOUNDRY_PROJECT}/out/EntryPointUpgradeable.sol/EntryPointUpgradeable.json"
MERGED_ABI="${OUTPUT_DIR}/abi.json"

if ! command -v forge >/dev/null 2>&1; then
  echo "[generate_relater_abi] forge not found in PATH" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "[generate_relater_abi] jq not found in PATH" >&2
  exit 1
fi

forge install --root "${FOUNDRY_PROJECT}" --no-git >/dev/null
forge build --root "${FOUNDRY_PROJECT}" >/dev/null

if [[ ! -f "${BRIDGE_ARTIFACT}" ]]; then
  echo "[generate_relater_abi] missing artifact ${BRIDGE_ARTIFACT}" >&2
  exit 1
fi
if [[ ! -f "${ENTRY_ARTIFACT}" ]]; then
  echo "[generate_relater_abi] missing artifact ${ENTRY_ARTIFACT}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

jq -s '.[0].abi + .[1].abi | unique_by(.type + "|" + (.name // "") + "|" + (if has("inputs") then (.inputs | map(.type) | join(",")) else "" end))' \
  "${BRIDGE_ARTIFACT}" "${ENTRY_ARTIFACT}" > "${MERGED_ABI}"

for node in node1 node2 node3; do
  node_dir="${OUTPUT_DIR}/${node}/db"
  mkdir -p "${node_dir}"
  cp "${MERGED_ABI}" "${node_dir}/abi.json"
done

echo "[generate_relayer_abi] generated ABI at ${MERGED_ABI}"
