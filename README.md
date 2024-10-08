# regtest

## Prerequisite

- docker/docker-compose
- go 1.23
- node lts
- jq

## Steps

### Init

```
git clone --recurse-submodules https://github.com/GOATNetwork/goat-regtest.git
cd goat-regtest
make init
```

### Create genesis

Create eth genesis

```
cp regtest.json submodule/contracts/ignition
cd submodule/contracts
rm -rf ignition/deployments
npm run genesis -- --force true
cp ./ignition/genesis/regtest.json ../../data/geth
cd -
./build/geth init --datadir ./data/geth ./data/geth/regtest.json
```

Create goat geneis

```sh
./build/goatd init --home ./data/goat regtest
./build/goatd modgen validator --home ./data/goat --pubkey $(jq -r '.pub_key.value' ./data/goat/config/priv_validator_key.json)
./build/goatd modgen relayer append --home ./data/goat --key.tx $(jq -r '.voter.TxPubkey' config.json) --key.vote $(jq -r '.voter.VotePubkey' config.json) $(jq -r '.voter.Address' config.json)
./build/goatd modgen goat --home ./data/goat ./data/geth/regtest.json
./build/goatd modgen bitcoin --home ./data/goat --min-deposit 1000000 --pubkey $(jq -r '.relayer.pubkey' config.json)
```

### Start

```
./build/geth --datadir ./data/geth --nodiscover
./build/goatd start --home ./data/goat --goat.geth ./data/geth/geth.ipc
```

### Cleanup

```sh
make clean
```
