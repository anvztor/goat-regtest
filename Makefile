init:
	mkdir -p build data/regtest data/goat data/geth
	make -C submodule/geth geth
	cp submodule/geth/build/bin/geth build
	make -C submodule/goat build
	cp submodule/goat/build/goatd build
	npm ci --prefix submodule/contracts

clean:
	rm -rf build
	rm -rf data/regtest data/goat data/geth
	rm -rf submodule/contracts/node_modules
