init: precheck clean goat geth contracts
	cp example.json config.json
	sh ./init.sh
	command -v pm2 || npm install pm2 -g

start:
	pm2 start ./build/geth -- --datadir ./data/geth --gcmode=archive --goat.preset=rpc --nodiscover
	pm2 start ./build/goatd -- start --home ./data/goat --regtest --goat.geth ./data/geth/geth.ipc

stop:
	pm2 delete all || echo "stopped"
	pm2 flush

logs:
	pm2 logs all

goat:
	mkdir -p build data/goat
	make -C submodule/goat build
	cp submodule/goat/build/goatd build

geth:
	mkdir -p build data/geth
	make -C submodule/geth geth
	cp submodule/geth/build/bin/geth build

contracts:
	npm ci --engine-strict --prefix submodule/contracts
	npm --prefix submodule/contracts --engine-strict run compile

clean: stop
	rm -rf build
	rm -rf data/goat data/geth
	rm -rf config.json
	rm -rf submodule/contracts/artifacts
	rm -rf submodule/contracts/cache
	rm -rf submodule/contracts/genesis/regtest-config.json
	rm -rf submodule/contracts/genesis/regtest.json
	rm -rf submodule/contracts/typechain-types
	rm -rf submodule/contracts/node_modules
	rm -rf submodule/goat/build
	rm -rf submodule/geth/build/bin

web3:
	@./build/geth attach --datadir ./data/geth

precheck:
	node --version
	go version
	docker --version
	docker compose version
	jq --version

update:
	git submodule update

docker-goat:
	cp Makefile.goat submodule/goat/Makefile.goat
	make -f Makefile.goat -C submodule/goat docker-build-all || true
	rm submodule/goat/Makefile.goat

docker-geth:
	cp Makefile.geth submodule/geth/Makefile.geth
	make -f Makefile.geth -C submodule/geth docker-build-all || true
	rm submodule/geth/Makefile.geth

docker-relayer:
	cp Makefile.relayer submodule/relayer/Makefile.relayer
	make -f Makefile.relayer -C submodule/relayer docker-build-all || true
	rm submodule/relayer/Makefile.relayer

reinit-genesis:
	rm -rf ./initialized/geth ./initialized/goat
	./init
	mv ./data/* ./initialized/
	sed -i '' 's/address = "localhost:9090"/address = "0.0.0.0:9090"/' ./initialized/goat/config/app.toml
	sed -i '' 's|node = "tcp://localhost:26657"|node = "tcp://0.0.0.0:26657"|' ./initialized/goat/config/client.toml
	sed -i '' 's|laddr = "tcp://127.0.0.1:26657"|laddr = "tcp://0.0.0.0:26657"|' ./initialized/goat/config/config.toml
