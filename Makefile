init: clean goat geth contracts

goat:
	mkdir -p build data/goat
	make -C submodule/goat build
	cp submodule/goat/build/goatd build

geth:
	mkdir -p build data/geth
	make -C submodule/geth geth
	cp submodule/geth/build/bin/geth build

contracts:
	npm ci --prefix submodule/contracts
	npm --prefix submodule/contracts run compile

clean:
	rm -rf build
	rm -rf data/goat data/geth

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