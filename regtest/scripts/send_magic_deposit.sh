#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default parameters (can be overridden via env or CLI)
DEPOSIT_AMOUNT_DOGE="${1:-100}"
TARGET_EVM_ADDR="${2:-0x70997970c51812dc3a010c7d01b50e0d17dc79c8}"
MAGIC_HEX="${3:-deadbeef}"

WATCH_ADDR="${DEPOSIT_WATCH_ADDR:-n46CVKhdq21FWm7fCwmtUZVadvEMPEDqE2}"
CHANGE_ADDR="${DOGE_CHANGE_ADDR:-n3b32Dihkz8XVrUz6PmiD9xz8PLEnFnrSJ}"
MINER_ADDR="${DOGE_MINER_ADDR:-n3b32Dihkz8XVrUz6PmiD9xz8PLEnFnrSJ}"

RELAYER_CONTAINER="${RELAYER_CONTAINER:-dogecoin-relayer-01}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
RELAYER_DB_PATH="${RELAYER_DB_PATH:-${PROJECT_ROOT}/regtest/data/relayer/node1/db/relayer.db}"

EVM_HEX="${TARGET_EVM_ADDR#0x}"
if [[ ${#EVM_HEX} -ne 40 ]]; then
  echo "[ERR] Invalid EVM address: ${TARGET_EVM_ADDR}" >&2
  exit 1
fi

MAGIC_CLEAN="${MAGIC_HEX#0x}"
if [[ ! ${MAGIC_CLEAN} =~ ^[0-9a-fA-F]+$ ]]; then
  echo "[ERR] Magic bytes must be hex, got: ${MAGIC_HEX}" >&2
  exit 1
fi

COMPOSE="docker compose -f ${PROJECT_ROOT}/regtest/docker-compose.yml"

RPC=(${COMPOSE} exec dogecoin-node dogecoin-cli -regtest -rpcconnect=127.0.0.1 -rpcport=22555 -rpcuser=gigawallet -rpcpassword=gigawallet)

echo "[1/6] Crafting raw transaction with OP_RETURN payload..."
RAW_TX="$(${RPC[@]} createrawtransaction '[]' "{\"${WATCH_ADDR}\":${DEPOSIT_AMOUNT_DOGE},\"data\":\"${MAGIC_CLEAN}${EVM_HEX}\"}")"

echo "[2/6] Funding transaction and adding change output..."
FUND_JSON="$(${RPC[@]} fundrawtransaction "${RAW_TX}" "{\"changeAddress\":\"${CHANGE_ADDR}\",\"changePosition\":2}" | tr -d '\r')"
FUND_HEX=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["hex"])' "${FUND_JSON}")

echo "[3/6] Signing transaction..."
SIGN_JSON="$(${RPC[@]} signrawtransaction "${FUND_HEX}" | tr -d '\r')"
SIGNED_HEX=$(python3 -c 'import json,sys; data=json.loads(sys.argv[1]);
assert data.get("complete"), "signrawtransaction returned incomplete signature";
print(data["hex"])' "${SIGN_JSON}")

echo "[4/6] Broadcasting transaction..."
TXID="$(${RPC[@]} sendrawtransaction "${SIGNED_HEX}")"
TXID="${TXID//$'\r'/}" # strip CR if present
echo "      Broadcast txid: ${TXID}"

echo "[5/6] Mining 1 block to confirm..."
${RPC[@]} generatetoaddress 1 "${MINER_ADDR}" >/dev/null

echo "[6/6] Waiting for relayer to index deposit..."
START_TS=$(date +%s)
FOUND=0
while true; do
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TS))
  if (( ELAPSED > WAIT_SECONDS )); then
    break
  fi
  if [[ ! -f "${RELAYER_DB_PATH}" ]]; then
    sleep 2
    continue
  fi
  COUNT=$(sqlite3 "${RELAYER_DB_PATH}" "SELECT COUNT(*) FROM deposits WHERE tx_id='${TXID}';" 2>/dev/null || echo 0)
  if [[ "${COUNT}" == "1" ]]; then
    FOUND=1
    break
  fi
  sleep 2
done

if [[ ${FOUND} -ne 1 ]]; then
  echo "[ERR] Deposit ${TXID} not indexed within ${WAIT_SECONDS}s" >&2
  exit 1
fi

echo "[OK] Deposit recorded by relayer. Summary:"
sqlite3 "${RELAYER_DB_PATH}" <<SQL
.mode column
SELECT id, tx_id, amount, address, status, evm_tx_hash
FROM deposits
WHERE tx_id='${TXID}';
SQL

echo
echo "Magic deposit complete." 
