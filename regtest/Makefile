.PHONY: compose-init compose-clean

compose-init:
	for n in 01 02 03; do \
		mkdir -p data/node-$$n/{db,p2p}; \
		cp ../submodule/relayer/env.example data/node-$$n/.env; \
		if [ -f ../initialized/tss/node$$n/config/config.yaml ]; then \
			cp ../initialized/tss/node$$n/config/config.yaml data/node-$$n/config.yaml; \
		else \
			cp ../config.yaml.example data/node-$$n/config.yaml; \
		fi; \
	done
compose-clean:
	rm -rf ./data