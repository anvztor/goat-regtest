#!/bin/sh

docker-compose down
rm -rf build
rm -rf data/regtest data/goat data/geth
