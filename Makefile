init: precheck clean
	cp example.json config.json
	sh ./init.sh
	command -v pm2 || npm install pm2 -g

start:
	pm2 start geth -- --dev --http --http.api=personal,eth,net,web3

stop:
	pm2 delete all || echo "stopped"
	pm2 flush

logs:
	pm2 logs all




clean: stop
	rm -rf build
	rm -rf data/geth
	rm -rf config.json
		
web3:
	@geth attach --datadir ./data/geth

precheck:
	node --version
	go version
	docker --version
	docker compose version
	jq --version

update:
	git submodule update



docker-relayer:
	cp Makefile.relayer submodule/relayer/Makefile.relayer
	make -f Makefile.relayer -C submodule/relayer docker-build-all || true
	rm submodule/relayer/Makefile.relayer

