#!/usr/bin/env bash
# Simplified Dogecoin regtest miner entrypoint.
#   • NO mnemonic / Python dependencies.
#   • Generates (or uses provided) legacy P2PKH address + WIF directly via dogecoin-cli.
#   • One-time premine followed by timed block generation.

set -euo pipefail

# ----------------------------------------------------------------------------
# Configuration (overridable via docker-compose environment variables)
# ----------------------------------------------------------------------------
RPC_USER=${rpcuser:-gigawallet}
RPC_PASS=${rpcpassword:-gigawallet}
RPC_PORT=${rpcport:-22555}
INTERVAL=${MINING_INTERVAL:-30}         # seconds per block after premine
PREMINE_BLOCKS=${PREMINE_BLOCKS:-200}   # one-time blocks on first start

# Optional: provide your own credentials
MINER_ADDRESS=${MINER_ADDRESS:-}
MINER_WIF=${MINER_WIF:-}

ADDRESS_FILE=/root/mining_address.txt
WIF_FILE=/root/mining_wif.txt
PREMINE_FLAG=/root/premine_done

# ----------------------------------------------------------------------------
wait_for_rpc() {
  echo "Waiting for Dogecoin node RPC (${RPC_USER}@127.0.0.1:${RPC_PORT}) …"
  until dogecoin-cli -regtest -rpcuser="${RPC_USER}" -rpcpassword="${RPC_PASS}" \
                     -rpcport="${RPC_PORT}" getblockchaininfo &> /dev/null; do
    sleep 2
  done
  echo "Dogecoin RPC ready."
}

# ----------------------------------------------------------------------------
# Ensure we have ADDRESS & WIF (either provided or generated)
# ----------------------------------------------------------------------------
init_wallet() {
  if [[ -n "${MINER_ADDRESS}" && -n "${MINER_WIF}" ]]; then
    ADDRESS="${MINER_ADDRESS}"
    WIF="${MINER_WIF}"
    echo "Using address / WIF supplied via environment variables."
  elif [[ -s "${ADDRESS_FILE}" && -s "${WIF_FILE}" ]]; then
    ADDRESS=$(<"${ADDRESS_FILE}")
    WIF=$(<"${WIF_FILE}")
    echo "Loaded existing mining address: ${ADDRESS}"
  else
    echo "Creating new legacy address via dogecoin-cli …"
    ADDRESS=$(dogecoin-cli -regtest -rpcuser="${RPC_USER}" -rpcpassword="${RPC_PASS}" -rpcport="${RPC_PORT}" getnewaddress)
    WIF=$(dogecoin-cli -regtest -rpcuser="${RPC_USER}" -rpcpassword="${RPC_PASS}" \
                       -rpcport="${RPC_PORT}" dumpprivkey "${ADDRESS}")

    echo "Generated ADDRESS: ${ADDRESS}"
    echo "Generated  WIF  : ${WIF}"

    # Persist for container restarts
    echo "${ADDRESS}" > "${ADDRESS_FILE}"
    echo "${WIF}"     > "${WIF_FILE}"
  fi

  # Ensure key is imported (importprivkey is idempotent)
  dogecoin-cli -regtest -rpcuser="${RPC_USER}" -rpcpassword="${RPC_PASS}" -rpcport="${RPC_PORT}" \
    importprivkey "${WIF}" "miner" false
}

# ----------------------------------------------------------------------------
# Premine & continuous mining
# ----------------------------------------------------------------------------
start_mining() {
  if [[ ! -f "${PREMINE_FLAG}" ]]; then
    echo "Premining ${PREMINE_BLOCKS} blocks to ${ADDRESS} …"
    dogecoin-cli -regtest -rpcuser="${RPC_USER}" -rpcpassword="${RPC_PASS}" -rpcport="${RPC_PORT}" \
      generatetoaddress "${PREMINE_BLOCKS}" "${ADDRESS}"
    touch "${PREMINE_FLAG}"
  fi

  echo "Starting timed mining every ${INTERVAL}s …"
  while true; do
    dogecoin-cli -regtest -rpcuser="${RPC_USER}" -rpcpassword="${RPC_PASS}" -rpcport="${RPC_PORT}" \
      generatetoaddress 1 "${ADDRESS}"
    sleep "${INTERVAL}"
  done
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
wait_for_rpc
init_wallet
start_mining
