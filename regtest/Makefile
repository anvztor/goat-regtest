.PHONY: compose-init compose-clean

compose-init:
	cp ../.env.example .env
	cp -rf ../initialized ./data

compose-clean:
	rm -rf ./data
	rm .env