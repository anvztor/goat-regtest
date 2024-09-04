#!/bin/sh

set -ex

DIR=$(pwd)

mkdir -p build

go build -o build ./cmd/...

cd $DIR/submodule/goat && make build && cp build/goatd ../../build
cd $DIR/submodule/geth && make geth && cp build/bin/geth ../../build
cd $DIR/submodule/contracts && npm ci
