.PHONY: compose-init compose-clean

compose-init:
	rm -rf ./data
	mkdir -p ./data
	rsync -a ../initialized/ ./data/
	rsync -a --delete --exclude='.github' ../submodule/contracts/ ./data/deploy-contract/
	cd ./data/deploy-contract && rm -rf .git && git init -q
	./scripts/generate_relayer_abi.sh

compose-clean:
	rm -rf ./data
