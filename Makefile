.DEFAULT_GOAL := l 


# Variable
eth_rpc := https://polygon-rpc.com

install:; yarn && forge install

clean:; rm -rf build/

# Utils
l:;		yarn lint && forge build

myth:
	forge flatten src/CurveFxRouter.sol > flat/CurveFxRouter.sol
	docker run -v $(shell pwd):/tmp mythril/myth analyze /tmp/flat/CurveFxRouter.sol

# Forge
tf:; 		forge test 
t:; 		forge test -vvv --fork-url $(eth_rpc) --match-contract "JarvisPoolRouterV2Test"

# Brownie Related
compile:; brownie compile
test:; brownie test --network polygon-fork -s
deploy:;  make clean && brownie run scripts/deploy.py --network polytend
