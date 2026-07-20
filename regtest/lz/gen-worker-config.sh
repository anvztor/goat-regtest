#!/usr/bin/env bash
# Generate the oh-my-lazier worker config for the regtest OFT pathway:
#   chain A = EVM-regtest  (lz-anvil-a, chainId 31337, eid 90101)  -> source, GOATED supply
#   chain B = GOAT-regtest (goat-geth,  chainId 48815, eid 90102)  -> destination
#
# It drives oh-my-lazier's e2e:deploy-local against the *running* regtest RPCs
# (lz-anvil-a + goat-geth) instead of the default anvil-a/anvil-b, deploys the
# LayerZero stack + TestOFT + OpenExecutor/OpenDVN/OpenPriceFeed on both chains,
# wires both directions, and copies the generated worker.container.yaml (plus the
# keystore + kms.json the worker container needs) into this directory so
# docker-compose-lz.yml's lz-worker can mount them.
#
# For the *GOATED* token specifically, swap in dev-bugfix's deploy (goated-lz-bridge)
# and replace the OFT addresses in the emitted worker.container.yaml; the worker
# config schema is identical.
#
# PENDING DEPENDENCY (see _coord/regtest-ops.status.json): oh-my-lazier's
# e2e-local-deploy.ts asserts the live RPC chainId == the hardcoded spec.chainId
# (31338 for chain B) and only lets env override the RPC URLs, not the chainId/eid.
# goat-geth is chainId 48815, so this script needs dev-bugfix to add an
# E2E_CHAIN_B_CHAIN_ID (and E2E_CHAIN_B_EID) override. Until then, chain B falls
# back to a stand-in anvil (chainId 31338) and the goat-geth repoint is a one-line
# change here.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OHMYLAZIER="${OHMYLAZIER:-$(cd "${SCRIPT_DIR}/../../../oh-my-lazier" && pwd)}"

# Regtest RPC wiring (host + in-container views).
export E2E_TMP_DIR="${OHMYLAZIER}/tmp/regtest"
export E2E_CHAIN_A_HOST_RPC_URL="${E2E_CHAIN_A_HOST_RPC_URL:-http://127.0.0.1:18545}"
export E2E_CHAIN_A_CONTAINER_RPC_URL="${E2E_CHAIN_A_CONTAINER_RPC_URL:-http://lz-anvil-a:8545}"
export E2E_CHAIN_B_HOST_RPC_URL="${E2E_CHAIN_B_HOST_RPC_URL:-http://127.0.0.1:8545}"
export E2E_CHAIN_B_CONTAINER_RPC_URL="${E2E_CHAIN_B_CONTAINER_RPC_URL:-http://goat-regtest-geth-node:8545}"

# Chain B chainId/eid override (consumed once dev-bugfix adds support to
# e2e-local-config.ts; harmless env vars until then).
export E2E_CHAIN_B_CHAIN_ID="${E2E_CHAIN_B_CHAIN_ID:-48815}"
export E2E_CHAIN_B_EID="${E2E_CHAIN_B_EID:-90102}"

# Signers / keys (throwaway regtest keys — see _coord/regtest-ops.status.json).
export E2E_DEPLOYER_PRIVATE_KEY="${E2E_DEPLOYER_PRIVATE_KEY:-0xd2777e91170f8377f52d4537f8370bd28d4d508d0424f768874ef1ea53202df0}"
export E2E_WORKER_PRIVATE_KEY="${E2E_WORKER_PRIVATE_KEY:-0xd090a562853ed3592bbf7413e305bca83bb0e602ba12191f5369e02737854e1d}"
export E2E_KEYSTORE_PASSWORD="${E2E_KEYSTORE_PASSWORD:-local-e2e-password}"
export E2E_KMS_REGION="${E2E_KMS_REGION:-us-east-1}"
export E2E_KMS_HOST_ENDPOINT="${E2E_KMS_HOST_ENDPOINT:-http://127.0.0.1:4566}"
export E2E_KMS_CONTAINER_ENDPOINT="${E2E_KMS_CONTAINER_ENDPOINT:-http://lz-localstack:4566}"
export AWS_ACCESS_KEY_ID="${E2E_AWS_ACCESS_KEY_ID:-test}"
export AWS_SECRET_ACCESS_KEY="${E2E_AWS_SECRET_ACCESS_KEY:-test}"
export AWS_REGION="${E2E_KMS_REGION}"
export AWS_EC2_METADATA_DISABLED=true

echo ">> oh-my-lazier: ${OHMYLAZIER}"
echo ">> chain A (EVM-regtest):  ${E2E_CHAIN_A_HOST_RPC_URL}  (container ${E2E_CHAIN_A_CONTAINER_RPC_URL})"
echo ">> chain B (GOAT-regtest): ${E2E_CHAIN_B_HOST_RPC_URL}  (container ${E2E_CHAIN_B_CONTAINER_RPC_URL}), chainId ${E2E_CHAIN_B_CHAIN_ID}"

cd "${OHMYLAZIER}"
rm -rf "${E2E_TMP_DIR}"
mkdir -p "${E2E_TMP_DIR}"

echo ">> generating KMS key -> kms.json"
go run ./go/cmd/e2ekmskey -out "${E2E_TMP_DIR}/kms.json"

echo ">> deploying LZ stack + OFT + workers (both directions)"
npm run e2e:deploy-local

echo ">> generating worker keystore"
go run ./go/cmd/e2ekeystore -out "${E2E_TMP_DIR}/worker-keystore.json"

echo ">> validating generated config"
go run ./go/cmd/configcheck -config "${E2E_TMP_DIR}/worker.host.yaml"

echo ">> copying artifacts into ${SCRIPT_DIR}"
cp "${E2E_TMP_DIR}/worker.container.yaml" "${SCRIPT_DIR}/worker.container.yaml"
cp "${E2E_TMP_DIR}/worker-keystore.json"  "${SCRIPT_DIR}/worker-keystore.json"
cp "${E2E_TMP_DIR}/kms.json"              "${SCRIPT_DIR}/kms.json"
cp "${E2E_TMP_DIR}/deployments.json"      "${SCRIPT_DIR}/deployments.json"

echo ">> done. Bring up the worker:"
echo "   docker compose -f docker-compose.yml -f docker-compose-lz.yml up -d lz-worker"
