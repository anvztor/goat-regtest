#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Python version of detect.sh to reliably replay calls with cast and avoid shell quoting issues.

Steps:
 1) eth_call EntryPoint.verifyAndCall (bubbles nested revert if EntryPoint is updated)
 2) eth_call DogecoinBridge.bridgeIn directly (from EntryPoint) to see concrete revert
 3) Compute double-SHA256 txid from txBytes and check bridgeInTxids mapping

Inputs via env or edit defaults below:
  RPC:           http rpc url (default http://localhost:8545)
  EP:            EntryPoint address
  BR:            DogecoinBridge address
  FROM_PROPOSER: sender address (defaults to nextProposer() from chain)
  CALLDATA:      hex calldata for bridgeIn encoded inside verifyAndCall (0x...)
  SIG:           65-byte rsv signature (0x...)
  DEST:          dest evm address for direct bridgeIn (0x...)
  AMOUNT:        integer amount for direct bridgeIn
  TX_HEX:        txBytes hex without 0x prefix; must be full even-length hex
"""
import os
import sys
import subprocess
import hashlib
import binascii

def getenv(name, default=""):
    return os.environ.get(name, default)

def check_even_hex(h: str, field: str):
    s = h[2:] if h.startswith("0x") else h
    if len(s) == 0 or (len(s) % 2) != 0:
        print(f"[ERR] {field} must be full even-length hex, got length={len(s)}", file=sys.stderr)
        sys.exit(2)

def run_cast(args):
    try:
        p = subprocess.run(args, capture_output=True, text=True)
        out = p.stdout.strip()
        err = p.stderr.strip()
        rc = p.returncode
        return rc, out, err
    except FileNotFoundError:
        print("[ERR] cast not found in PATH", file=sys.stderr)
        sys.exit(127)

def main():
    RPC  = getenv("RPC", "http://localhost:8545")
    EP   = getenv("EP", "")
    BR   = getenv("BR", "")
    FROM = getenv("FROM_PROPOSER", "")
    CALLDATA = getenv("CALLDATA", "")
    SIG     = getenv("SIG", "")
    DEST    = getenv("DEST", "")
    AMOUNT  = getenv("AMOUNT", "")
    TX_HEX  = getenv("TX_HEX", "")

    if not EP or not BR:
        print("[ERR] EP and BR must be set (EntryPoint and Bridge addresses).", file=sys.stderr)
        sys.exit(2)
    if not CALLDATA or not SIG or not DEST or not AMOUNT or not TX_HEX:
        print("[ERR] CALLDATA, SIG, DEST, AMOUNT, TX_HEX must be provided via env.", file=sys.stderr)
        sys.exit(2)

    # Basic hex checks
    check_even_hex(CALLDATA, "CALLDATA")
    check_even_hex(SIG, "SIG")
    if DEST.lower().startswith("0x") and len(DEST) != 42:
        print(f"[ERR] DEST must be 20-byte address (0x + 40 hex), got: {DEST}", file=sys.stderr)
        sys.exit(2)
    # TX_HEX is without 0x
    if TX_HEX.startswith("0x"):
        TX_HEX = TX_HEX[2:]
    if (len(TX_HEX) % 2) != 0:
        print("[ERR] TX_HEX must be full even-length hex without 0x", file=sys.stderr)
        sys.exit(2)

    # Get proposer if missing
    if not FROM:
        rc, out, err = run_cast(["cast", "call", "--rpc-url", RPC, EP, "nextProposer()(address)"])
        if rc != 0:
            print("[WARN] failed to auto fetch nextProposer: ", err or out, file=sys.stderr)
            sys.exit(2)
        FROM = out.strip()

    print("1) EntryPoint.verifyAndCall (eth_call)")
    # Build calldata first to avoid cast arg parser edge cases with arrays
    rc0, encoded, err0 = run_cast([
        "cast", "calldata",
        "verifyAndCall(address[],bytes[],bytes)",
        f'[{BR}]',
        f'[{CALLDATA}]',
        SIG
    ])
    if rc0 != 0 or not encoded:
        print(err0 or encoded)
        print("verifyAndCall rc=1\n")
        encoded = ""
    args1 = ["cast", "call", "--rpc-url", RPC, "--from", FROM, EP, "--data", encoded] if encoded else []
    rc, out, err = run_cast(args1) if args1 else (1, "", "calldata encode failed")
    if rc == 0:
        print(out)
    else:
        print(err or out)
    print(f"verifyAndCall rc={rc}\n")

    print("2) Direct bridgeIn (simulate from EntryPoint) - eth_call")
    # Encode bridgeIn call data and then use --calldata to avoid parser issues
    bridge_param = f'[( {DEST}, {AMOUNT}, 0x{TX_HEX})]'
    rc2e, encoded2, err2e = run_cast([
        "cast", "calldata",
        "bridgeIn((address,uint256,bytes)[])",
        bridge_param
    ])
    if rc2e != 0 or not encoded2:
        print(err2e or encoded2)
        print("bridgeIn rc=1\n")
        encoded2 = ""
    args2 = ["cast", "call", "--rpc-url", RPC, "--from", EP, BR, "--data", encoded2] if encoded2 else []
    rc2, out2, err2 = run_cast(args2) if args2 else (1, "", "calldata encode failed")
    if rc2 == 0:
        print(out2)
    else:
        print(err2 or out2)
    print(f"bridgeIn rc={rc2}\n")

    print("3) Compute txid (double SHA256) and check duplication flag")
    raw = binascii.unhexlify(TX_HEX)
    txid = hashlib.sha256(hashlib.sha256(raw).digest()).digest().hex()
    print(f"txid=0x{txid}")
    args3 = [
        "cast", "call", "--rpc-url", RPC,
        BR, "bridgeInTxids(bytes32)(bool)",
        f"0x{txid}"
    ]
    rc3, out3, err3 = run_cast(args3)
    if rc3 == 0:
        print(out3)
    else:
        print(err3 or out3)

if __name__ == "__main__":
    main()
