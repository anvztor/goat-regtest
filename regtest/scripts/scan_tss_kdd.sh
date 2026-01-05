#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scan_tss_kdd.sh <recovered_address> [nodes_csv] [start_kdd] [end_kdd]
# Examples:
#   scan_tss_kdd.sh 0xE8C43f2F62A8c36E725d43e61Cb69E0c9847e0e5 goat-network-tss-node1 0 10
#   scan_tss_kdd.sh 0xE8C43f2F62A8c36E725d43e61Cb69E0c9847e0e5 "goat-network-tss-node1" 0 10

RECOVERED="${1:-${RECOVERED:-}}"
NODES_CSV="${2:-${TSS_NODES:-goat-network-tss-node1}}"
START_KDD="${3:-${START_KDD:-0}}"
END_KDD="${4:-${END_KDD:-10}}"
TSS_PORT="${TSS_PORT:-8180}"
TIMEOUT="${TIMEOUT:-5}"

if [[ -z "${RECOVERED}" ]]; then
  echo "ERR: missing recovered address. Usage: $0 <recovered_address> [nodes_csv] [start_kdd] [end_kdd]" >&2
  exit 1
fi

norm_hex() {
  local v="${1#0x}"
  echo "0x$(echo -n "$v" | tr 'A-F' 'a-f')"
}

REC_N=$(norm_hex "${RECOVERED}")
IFS=',' read -r -a NODES <<< "${NODES_CSV}"

echo "Scanning TSS EVM addresses via POST /api/v1/common/address"
echo "Recovered: ${REC_N}"
echo "Nodes: ${NODES_CSV}"
echo "Range: [${START_KDD}, ${END_KDD}]"
echo

extract_addr() {
  local body="$1"
  if command -v jq >/dev/null 2>&1; then
    local a
    a=$(echo -n "${body}" | jq -r '.address // empty' 2>/dev/null || true)
    if [[ -n "${a}" && "${a}" != "null" ]]; then
      echo "${a}"
      return
    fi
  fi
  echo -n "${body}" | sed -n 's/.*\(0x[0-9a-fA-F]\{40\}\).*/\1/p' | head -n1
}

found=0

for node in "${NODES[@]}"; do
  echo "== Node: ${node}:${TSS_PORT} =="
  printf "%-6s %-12s %-6s  %s\n" "kdd" "skipPath" "match" "address"
  
  # Scan normal range
  for ((k=${START_KDD}; k<=${END_KDD}; k++)); do
    # Try skipPath=false (default/existing logic)
    req_false=$(cat <<JSON
{"curve":"secp256k1","coinType":60,"account":${k},"index":0,"chainType":"evm","skipPath":false}
JSON
)
    body_false=$(curl -sS --max-time "${TIMEOUT}" -X POST -H "Content-Type: application/json" --data "${req_false}" "http://${node}:${TSS_PORT}/api/v1/common/address" || true)
    addr_false=$(extract_addr "${body_false}")
    ADDR_FALSE_N=$(norm_hex "${addr_false}" 2>/dev/null || echo "")

    match_false="no"
    if [[ "${ADDR_FALSE_N}" == "${REC_N}" ]]; then match_false="YES"; found=1; fi
    
    printf "%-6s %-12s %-6s  %s\n" "${k}" "false" "${match_false}" "${ADDR_FALSE_N}"

    # Try skipPath=true (proposed fix test)
    req_true=$(cat <<JSON
{"curve":"secp256k1","coinType":60,"account":${k},"index":0,"chainType":"evm","skipPath":true}
JSON
)
    body_true=$(curl -sS --max-time "${TIMEOUT}" -X POST -H "Content-Type: application/json" --data "${req_true}" "http://${node}:${TSS_PORT}/api/v1/common/address" || true)
    addr_true=$(extract_addr "${body_true}")
    ADDR_TRUE_N=$(norm_hex "${addr_true}" 2>/dev/null || echo "")

    match_true="no"
    if [[ "${ADDR_TRUE_N}" == "${REC_N}" ]]; then match_true="YES"; found=1; fi
    
    printf "%-6s %-12s %-6s  %s\n" "${k}" "true" "${match_true}" "${ADDR_TRUE_N}"
  done
  echo
done

if [[ "${found}" -eq 0 ]]; then
  echo "No match found for recovered=${REC_N}."
  exit 2
else
  echo "Match found!"
fi
