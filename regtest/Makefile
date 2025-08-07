.PHONY: compose-init compose-clean

compose-init:
for n in 01 02 03; do \
		mkdir -p data/node-$$n/{db,p2p}; \
		cp ../submodule/relayer/env.example data/node-$$n/.env; \
		touch data/node-$$n/config.yaml; \
	done
compose-clean:
	rm -rf ./data
	rm .env