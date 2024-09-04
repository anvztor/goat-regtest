# regtest

## Prerequisite

- docker/docker-compose
- go 1.22+
- node lts

## Steps

### clone repostiory & compile

```
git clone --recurse-submodules https://github.com/GOATNetwork/goat-regtest.git
cd goat-regtest
./init.sh
```

### generate key

```console
./build/goatd modgen keygen --home ./data/goat --tx --vote
secp256k1 prvkey 522afed335d0e13e644ef35a4bac3d4e745a707ad258fd3a87e4bfa03c3d470c
secp256k1 pubkey 027c0437de7e4d21149d8f96265294d055193879696ec2fba0c57f7c171128d83d
goat address goat1vrrrqdhu7dy70472lmkgr0xt5ueg9kzy26289m
eth address 0xac4379f7067B2fd257184462129c806dDEF96D77
btc address bcrt1qvrrrqdhu7dy70472lmkgr0xt5ueg9kzyqjxqmy
bls12-381 prvkey 680e85e4eac1a3e4f54b6535e35c7e5308a483859b1c2fe2e0a1c04e777c38b0
bls12-381 pubkey a58045662032b85f75dcc503d622411fb7ef88d89c200155e45dd9c6c02fcdd25dc6d0def64ddc1da74a07e515a577f5176654411068215cae073e37dd8318a4d8f6c851a06def606d9403763c948892e8ce48d13a6114a87fce7b6fa60d12fe
```

### Create genesis

start bitcoin regtest network

```
docker-compose up -d
```

generate bitcoin blocks

```
docker-compose exec node bitcoin-cli generatetoaddress 101 bcrt1qvrrrqdhu7dy70472lmkgr0xt5ueg9kzyqjxqmy
```

get bitcoin block hash(with little endian) on block 100

```
cd submodule/contracts
npx hardhat btc:getblockhash --height 100 --canonical true
0x789b744b2a246e27c88c19a6666430dcf5b1adec47949373d35de411494eca55
```

Add new config file to `submodule/contracts/ignition/regtest.json`

```json
{
  "Genesis": {
    "btc.height": 100,
    "btc.hash": "0x789b744b2a246e27c88c19a6666430dcf5b1adec47949373d35de411494eca55",
    "btc.network": "0x6fc4046263727407726567746573740000000000000000000000000000000000",
    "goat.owner": "0xac4379f7067B2fd257184462129c806dDEF96D77"
  }
}
```

Create eth genesis file

```
cd submodule/contracts
rm -rf ignition/deployments
npm run genesis
cp ./ignition/genesis/regtest.json ../../data/geth
cd -
./build/geth init --datadir ./data/geth ./data/geth/regtest.json
./build/genesis -genesis ./data/geth/regtest.json | tee -a ./data/goat/eth.json
```

Init goat node files

```console
$ ./build/goatd init --home ./data/goat regtest
{
 "moniker": "regtest",
 "chain_id": "goat",
 "node_id": "b6598e518284b8c3536722394ecd3cd9116a1270",
 "validator": "4B87CBD9CB8B2FB8E457869B0139EFEA24415651"
}
```

Add relayer module genesis

```
./build/goatd modgen relayer append --home ./data/goat
--key.tx 027c0437de7e4d21149d8f96265294d055193879696ec2fba0c57f7c171128d83d \
--key.vote \
a58045662032b85f75dcc503d622411fb7ef88d89c200155e45dd9c6c02fcdd25dc6d0def64ddc1da74a07e515a577f5176654411068215cae073e37dd8318a4d8f6c851a06def606d9403763c948892e8ce48d13a6114a87fce7b6fa60d12fe \
--threshold 1 goat1vrrrqdhu7dy70472lmkgr0xt5ueg9kzy26289m
```

Add bitcoin module genesis

```console
$ cd submodule/contracts
$ npx hardhat btc:getblockhash --height 100 --canonical false
0x55ca4e4911e45dd373939447ecadb1f5dc306466a6198cc8276e242a4b749b78
$ cd -
$ ./build/goatd modgen bitcoin --network regtest --deposit-magic-prefix GTT0 --min-deposit 1000000 --pubkey 027c0437de7e4d21149d8f96265294d055193879696ec2fba0c57f7c171128d83d --home ./data/goat 100 0x55ca4e4911e45dd373939447ecadb1f5dc306466a6198cc8276e242a4b749b78
```

Add goat module genesis

```
./build/goatd modgen goat ./data/goat/eth.json --home ./data/goat
```

Add validator

```
./build/goatd modgen validator --home ./data/goat --pubkey $(jq -r '.pub_key.value' data/goat/config/priv_validator_key.json)
```

### Start

```
./build/geth --datadir ./data/geth --nodiscover
```

```
./build/goatd start --home ./data/goat --goat.geth ./data/geth/geth.ipc
```
