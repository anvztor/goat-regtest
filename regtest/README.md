This is a regtest setup only for testing.

# bitcoin-regtest
```
docker-compose -f docker-compose-bitcoin.yml up -d
docker exec -it bitcoin-regtest /bin/bash

# load wallet
bitcoin-wallet -regtest -wallet=demo create
mkdir -p /home/bitcoin/.bitcoin/regtest/wallets/demo/
cp /root/.bitcoin/regtest/wallets/demo/wallet.dat /home/bitcoin/.bitcoin/regtest/wallets/demo/wallet.dat
cd /home/bitcoin/.bitcoin/regtest/wallets/
chmod 777 -R demo/
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test loadwallet demo

# generate blocks
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test -generate 100
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test -generate 1

# v0
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test sendtoaddress bcrt1q8kqj8j03apl542ftnqdc8hwrge6tyymwnd0sr7f0e57mxwpjl2eqadm5rh 1
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test getrawtransaction cf54bbc18fee0d5e78535df561412fbde2b002616e6cbb724a6eb713e0afde14

# v1
bitcoin-cli -regtest -rpcuser=test -rpcpassword=test sendtoaddress bcrt1qtrwz2jnxuhwn7uvtdaa5924mtpqm260ee3lflv 1


```

# relayer-regtest

`docker-compose -f docker-compose-relayer.yml up -d`

# goat-geth-regtest

`docker-compose -f docker-compose-goat-geth-init.yml up -d`

`docker-compose -f docker-compose-goat-geth.yml up -d`

# frontend-regtest

TODO