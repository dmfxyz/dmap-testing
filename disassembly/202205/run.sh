#!/bin/bash

# FNAME="BasicSet.sol"; SIG="set()"; ./run.sh $FNAME $SIG

RUST_BACKTRACE="full"
ETH_RPC_URL="https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
forge run -f $ETH_RPC_URL -vvvv --debug $1 --sig $2
