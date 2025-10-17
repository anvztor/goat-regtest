# This is a regtest setup only for testing.

## Quickstart

### Start All-in-One Regtest
```
git submodule update --init --recursive   # fetch relay & contract code
make compose-init   # requires forge & jq in PATH to build ABI artifacts
docker compose up -d
```

### Doge Deposit & Withdrawal Testing

The following steps demonstrate how to test Dogecoin→EVM deposits (bridge-in) and EVM→Dogecoin withdrawals (bridge-out) using the integrated `docker compose` environment and included scripts/deployment artifacts.

#### Prerequisites
- Ensure the All-in-One environment above is running: `docker compose up -d`
- Ensure `make compose-init` (to generate contract ABI and initialize data dir) has been run
- Your local machine needs: `python3`, `jq`, and `sqlite3`

#### 1) Deposit (Doge → EVM)
Deposit works by sending a Dogecoin regtest transaction with OP_RETURN data to the bridge watch address. The OP_RETURN should contain the target EVM address. The project provides a script to initiate a "magic deposit" in one click.

1. Run the deposit script (you can specify amount, EVM address, and magic bytes):
```bash
# Usage: ./regtest/scripts/send_magic_deposit.sh [DOGE_AMOUNT] [TARGET_EVM_ADDRESS] [magic-hex]
# Example: Send 100 DOGE to the default watch address for EVM address 0x7099...79C8, with magic deadbeef
bash ./regtest/scripts/send_magic_deposit.sh 100 0x70997970c51812dc3a010c7d01b50e0d17dc79c8 deadbeef
```

2. What the script does (automated):
- Uses `dogecoin-cli -regtest` to create a raw transaction with:
  - Output 1: Sends to the bridge's watch address (`DEPOSIT_WATCH_ADDR`, default `n46CVK...`)
  - Output 2: OP_RETURN with data `[magic][20 bytes EVM address]`
- Automatically sends change to `DOGE_CHANGE_ADDR` (default: same as miner address)
- Signs and broadcasts the transaction, then mines 1 block for confirmation
- Polls the relayer DB to ensure the deposit is indexed

3. Verify deposit result:
The script prints a record from the deposits table. You can check manually:
```bash
sqlite3 ./regtest/data/relayer/node1/db/relayer.db \
  "SELECT id, tx_id, amount, address, status, evm_tx_hash FROM deposits ORDER BY id DESC LIMIT 5;"
```
The EVM balance (`DogeToken`) should also increase. You can verify using your preferred tool over local RPC, or use the frontend/scripts provided later.

Available environment variables (optional):
- `DEPOSIT_WATCH_ADDR`: Bridge watch address (Dogecoin P2PKH)
- `DOGE_CHANGE_ADDR`: Change address
- `DOGE_MINER_ADDR`: Mining reward address (for confirmation block)
- `RELAYER_DB_PATH`: Relayer SQLite DB path

#### 2) Withdrawal (EVM → Doge)
Withdrawals are a two-step process:
1) The user calls `DogecoinBridge.bridgeOut` on the EVM side to submit a withdrawal request (emitting `BridgeOutProposed` event) and locks an equivalent amount of `DogeToken` (after fee);
2) The relayer, after aggregating tasks, generates and submits a `bridgeOutFinish` transaction, which is verified on-chain and burns the corresponding tokens. The process is completed with a `BridgeOutFinished` event.

A. Get contract address
```bash
jq -r '.transactions[] | select(.contractName=="DogecoinBridge") | .contractAddress' \
  ./regtest/data/deploy-contract/broadcast/Deploy.s.sol/1337/run-latest.json | tail -n 1
```

B. Initiate bridgeOut on EVM (example)
You can use any EVM script/console to call the contract. Parameters:
- `amount`: Use 18 decimals (contracts currently use 18 decimals internally; will convert to 8 decimals for Doge later; must be greater than fee);
- `destDogecoinAddress`: The Dogecoin target address's public key hash (20 bytes, `bytes20`, i.e., P2PKH `hash160`).

Example (ethers.js snippet, for illustration only):
```js
const bridge = new ethers.Contract(bridgeAddr, bridgeAbi, signer);
// Convert Base58 address to hash160(bytes20) as per your toolchain
const destPKH = "0x059ce0647de86cf966dfa4656a08530eb8f26772"; // example
const amount = ethers.parseUnits("50", 18);
const tx = await bridge.bridgeOut(amount, destPKH);
await tx.wait();
```

C. Observe relayer & completion events
- The relayer listens for `BridgeOutProposed` events, selects tasks, and creates the Dogecoin withdrawal transaction. The related `bridgeOutFinish` calldata is composed and submitted on-chain.
- Completion is signaled by the `BridgeOutFinished(uint256[] taskIds)` event.

You can verify as follows:
```bash
# Observe relayer logs (container may be named dogecoin-relayer-01)
docker compose logs -f dogecoin-relayer-01 | sed -n 's/.*\(BridgeOut\|withdraw\).*/\0/p'

# (optional) Query EVM node for events or use block explorer/scripts directly
```

Note: The current contract leaves the 18 ↔ 8 decimals conversion as a TODO. The sample setup uses it as-is; for production usage you should implement and test proper decimal conversion logic.

### Stop & Clean
```
docker compose down
make compose-clean
```
