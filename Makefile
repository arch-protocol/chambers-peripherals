# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
install:; forge install
update:; forge update

# Build & test
build  :; forge build
test   :; forge test
test-polygon-fork :; forge test --fork-url https://polygon-mainnet.g.alchemy.com/v2/$(ALCHEMY_POLY_API_KEY) --ffi -vvv
test-trade-issuer-integration-mainnet-fork :; FOUNDRY_FUZZ_RUNS=5 forge test --match-path "./test/integration/TradeIssuerV2/*.sol" --fork-url https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_ETH_API_KEY) --ffi -vvv
test-unit-mainnet-fork :; forge test --match-path "./test/unit/**/*.sol" --fork-url https://eth-mainnet.g.alchemy.com/v2/$(ALCHEMY_ETH_API_KEY) --ffi -vvv
trace   :; forge test -vvv
clean  :; forge clean
snapshot :; forge snapshot
fmt    :; forge fmt