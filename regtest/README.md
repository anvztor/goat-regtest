# This is a regtest setup only for testing.

## Quickstart

### Start All-in-One Regtest
```
make compose-init
docker compose up -d
```

### Stop & Clean
```
docker compose down
make compose-clean
```

## Create network

`docker network create --driver bridge --subnet 192.168.10.0/24 goat_network`

## Bitcoin-regtest

`docker-compose -f docker-compose-bitcoin.yml up -d`

`docker exec -it bitcoin-regtest /bin/bash`

#### Generate Deposits
```
# Make deposits (e.g. 1 btc to evmAddress 0x70997970C51812dc3A010C7d01b50e0d17dc79C8)
## V0: Send btc to p2wsh address bcrt1q8kqj8j03apl542ftnqdc8hwrge6tyymwnd0sr7f0e57mxwpjl2eqadm5rh
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test sendtoaddress bcrt1q8kqj8j03apl542ftnqdc8hwrge6tyymwnd0sr7f0e57mxwpjl2eqadm5rh 1
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test getrawtransaction 5a5b2bf8bfb1d485a6ac2096f8eeeac83dacb3d7874e5e45a1f4d0702f9b98d2

## V1: Send btc to p2wpkh address: bcrt1qjav7664wdt0y8tnx9z558guewnxjr3wllz2s9u
## Get txid, vout from rawtransaction, and fill selectedUTXOs, run sendBtcByP2WPKHToP2PKH.js
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test sendtoaddress bcrt1qjav7664wdt0y8tnx9z558guewnxjr3wllz2s9u 1
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test getrawtransaction d8fcc7e201f5b7766d5c50eadc799e3a474035dd46ca33aa8c6635f0367c3d0a
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test decoderawtransaction 02000000000101d2989b2f70d0f4a1455e4e87d7b3ac3dc8eaeef89620aca685d4b1bff82b5b5a0100000000fdffffff02a8af151e01000000160014f0530796e40f8fc8b482c213506688dc7ae263a500e1f5050000000016001458dc254a66e5dd3f718b6f7b42aabb5841b569f9014021e301735978dd2b007d14f40076b374acda5e5578c3c2c1933dbd34b19ef6e143f5ca855c2e9f977918db74687b06cc610dc45568fc3a40b0e2fc9054e7e4e265000000
```

## Goat-geth-regtest

`docker-compose -f docker-compose-goat-geth.yml up -d`

## Relayer-regtest

`docker-compose -f docker-compose-relayer.yml up -d`

## Frontend-regtest

`docker-compose -f docker-compose-front.yml up -d`

## Subgraph-regtest

`docker-compose -f docker-compose-subgraph.yml up -d`