# include .env file and export its env vars
-include .env

.PHONY: deploy-testnet deploy-local test

test:
	forge test -vvvv --optimize --optimizer-runs 30000

deploy:
	forge script script/Deploy.s.sol:Deploy --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-with-demo:
	forge script script/DeployWithDemoTxs.s.sol:DeployWithDemoTxs --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-local:
	forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key 26e86e45f6fc45ec6e2ecd128cec80fa1d1505e5507dcd2ae58c3130a7a97b48 --broadcast -vvvv

deploy-test-token-local:
	forge script script/DeployTestToken.s.sol:DeployTestToken --rpc-url http://localhost:8545 --private-key 26e86e45f6fc45ec6e2ecd128cec80fa1d1505e5507dcd2ae58c3130a7a97b48 --broadcast -vvvv

playground-local:
	forge script script/Playground.s.sol:Playground --rpc-url http://localhost:8545 --private-key 26e86e45f6fc45ec6e2ecd128cec80fa1d1505e5507dcd2ae58c3130a7a97b48 --broadcast -vvvv
