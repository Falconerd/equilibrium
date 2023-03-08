#!/bin/bash
source .env
# Run this after copying the addresses into the DeployPart2 file.
forge script script/DeployPart2.s.sol:Deploy --chain-id 4002 --rpc-url $RPC_URL \
    --etherscan-api-key $FTMSCAN_API_KEY --verifier-url https://api-testnet.ftmscan.com/api \
    --broadcast --verify -vvvv
