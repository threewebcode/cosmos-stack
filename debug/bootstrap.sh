#!/usr/bin/env bash

function install_dependencies(){
  sudo apt update
  sudo apt install jq
}

function clone_code(){

}

function lanuch_solo(){

}

git clone -b v0.43.0 https://gitee.com/wonderfan/cosmos-sdk.git
cd cosmos-sdk
make build

./build/simd init mychain --home mychain --chain-id mychain

./build/simd keys add alice --home mychain --keyring-backend test
# alice cosmos19wlfffyx6azhuzrpu4rl54mnddnyktzr0rt8zq
./build/simd keys add bob --home mychain --keyring-backend test
# bob cosmos1r0ffxtdcv3s27wvsfsck7swxt308y8qq4w5jgr

./build/simd add-genesis-account alice "1000000000stake,10000000000token" --home mychain --keyring-backend test
./build/simd gentx alice 1000000000stake --chain-id=mychain --home mychain --keyring-backend test
./build/simd collect-gentxs --home mychain

./build/simd unsafe-reset-all --home mychain
sed -i '357s/true/false/g' mychain/config/config.toml
sed -i '358s/0s/5s/g' mychain/config/config.toml
./build/simd start --consensus.create_empty_blocks=false --consensus.create_empty_blocks_interval 5s --home mychain --log_level debug

./build/simd query bank balances cosmos1qm6ygukulj7xp92r4c60s76lvd0xtw74sefxn2 --home mychain
./build/simd query bank balances cosmos129ggjn9u8h0huue2rhzvtfqrmazlz0s9cj5m75 --home mychain

# Tendermint

git clone -b v0.34.12 https://gitee.com/wonderfan/tendermint.git
cd tendermint
make build
./build/tendermint init --home mychain
./build/tendermint start --proxy_app=kvstore --home mychain --log_level=debug
