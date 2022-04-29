// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

interface CurveExchange {
    function registry() external view returns (address);

    function get_address(uint256 id) external view returns (address);

    function get_best_rate(
        address from,
        address to,
        uint256 amount
    ) external view returns (address, uint256);

    function factory_registry() external view returns (address);

    function exchange(
        address _pool,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _expected,
        address _receiver
    ) external payable returns (uint256);
}

interface Registry {
    function address_provider() external view returns (address);

    function get_A(address _pool) external view returns (uint256);

    function get_fees(address _pool) external view returns (uint256[] memory);

    function get_n_coins(address _pool) external view returns (uint256[] memory);

    function get_coin_indices(
        address _pool,
        address _from,
        address _to
    )
        external
        view
        returns (
            int128,
            int128,
            bool
        );

    function get_coins(address _pool) external view returns (address[] memory);

    function get_underlying_coins(address _pool) external view returns (address[8] memory);

    function get_underlying_balances(address _pool) external view returns (uint256[] memory);

    function get_balances(address _pool) external view returns (uint256[] memory);

    function find_pool_for_coins(
        address _from,
        address _to,
        uint256 i
    ) external view returns (address);

    function get_rates(address _pool) external view returns (uint256[] memory);

    function get_decimals(address _pool) external view returns (uint256[] memory);

    function get_underlying_decimals(address _pool) external view returns (uint256[] memory);

    function get_lp_token(address _pool) external view returns (address);

    function is_meta(address _pool) external view returns (bool);
}

interface LendingPool {
    struct ReserveData {
        //stores the reserve configuration
        address configuration;
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //the current stable borrow rate. Expressed in ray
        uint128 currentStableBorrowRate;
        uint40 lastUpdateTimestamp;
        //tokens addresses
        address aTokenAddress;
        address stableDebtTokenAddress;
        address variableDebtTokenAddress;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint8 id;
    }

    function getReserveData(address asset) external view returns (ReserveData memory);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

interface CurvePoolHelper {
    function exchange(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable;

    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy
    ) external payable;

    function exchange_underlying(
        address pool,
        int128 i,
        int128 j,
        uint256 dx,
        uint256 min_dy,
        address receiver
    ) external payable returns (uint256);

    function get_dy(
        int128 i,
        int128 j,
        uint256 amount
    ) external view returns (uint256);

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 amount
    ) external view returns (uint256);

    function coins(uint256 i) external view returns (address);
}
