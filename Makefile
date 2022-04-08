.DEFAULT_GOAL := l 


# Variable
eth_rpc := https://polygon-rpc.com

install:; yarn && forge install

clean:; rm -rf build/

# Utils
l:;		yarn lint && forge build

myth:
	forge flatten src/JarvisPoolRouter.sol > flat/JarvisPoolRouter.sol
	docker run -v $(shell pwd):/tmp mythril/myth analyze /tmp/flat/JarvisPoolRouter.sol

# Forge
tf:; 		forge test 
t:; 		forge test -vvv --fork-url $(eth_rpc) --gas-report

# Brownie Related
compile:; brownie compile
deploy:;  make clean && brownie run scripts/deploy.py --network polytend
