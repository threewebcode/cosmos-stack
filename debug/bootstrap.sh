#!/usr/bin/env bash

git clone -b v0.43.0 https://gitee.com/wonderfan/cosmos-sdk.git
cd cosmos-sdk
make build

./build/simd init mychain --home mychain --chain-id mychain

./build/simd keys add alice --home mychain --keyring-backend test
cosmos1qm6ygukulj7xp92r4c60s76lvd0xtw74sefxn2
./build/simd keys add bob --home mychain --keyring-backend test
cosmos129ggjn9u8h0huue2rhzvtfqrmazlz0s9cj5m75

./build/simd add-genesis-account alice "1000000000stake,10000000000token" --home mychain --keyring-backend test
./build/simd gentx alice 1000000000stake --chain-id=mychain --home mychain --keyring-backend test
./build/simd collect-gentxs --home mychain

./build/simd unsafe-reset-all --home mychain
./build/simd start --consensus.create_empty_blocks=false --home mychain 

./build/simd query bank balances cosmos1qm6ygukulj7xp92r4c60s76lvd0xtw74sefxn2 --home mychain
./build/simd query bank balances cosmos129ggjn9u8h0huue2rhzvtfqrmazlz0s9cj5m75 --home mychain
