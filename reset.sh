#!/bin/sh

docker-composed down
rm -rf build
rm -rf data/regtest data/goat data/geth
