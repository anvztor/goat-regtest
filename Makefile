init: goat geth contracts
images: docker-goat docker-geth docker-relayer

goat:
	mkdir -p build data/goat
	make -C submodule/goat build
	cp submodule/goat/build/goatd build

geth:
	mkdir -p build data/geth
	make -C submodule/geth geth
	cp submodule/geth/build/bin/geth build

docker-goat:
	cp Makefile.goat submodule/goat/Makefile.goat
	make -f Makefile.goat -C submodule/goat docker-build-all || true
	rm submodule/goat/Makefile

docker-geth:
	cp Makefile.geth submodule/goat-geth/Makefile.geth
	make -f Makefile.geth -C submodule/goat-geth docker-build-all || true
	rm submodule/goat-geth/Makefile

docker-relayer:
	make -C submodule/relayer docker-build-all

contracts:
	npm ci --prefix submodule/contracts
	npm --prefix submodule/contracts run compile

clean:
	rm -rf build
	rm -rf data/regtest data/goat data/geth
