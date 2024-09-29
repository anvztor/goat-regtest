init: goat geth contracts
images: goat-image geth-image relayer-image

goat:
	mkdir -p build data/goat
	make -C submodule/goat build
	cp submodule/goat/build/goatd build

geth:
	mkdir -p build data/geth
	make -C submodule/geth geth
	cp submodule/geth/build/bin/geth build

goat-image:
	make -C submodule/goat docker-build-all

geth-image:
	make -C submodule/geth docker-build-all

relayer-image:
	make -C submodule/relayer docker-build-all

contracts:
	npm ci --prefix submodule/contracts
	npm --prefix submodule/contracts run compile

clean:
	rm -rf build
	rm -rf data/regtest data/goat data/geth
