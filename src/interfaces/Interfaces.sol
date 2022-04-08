// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

interface ISynthereumLiquidityPool {
    struct MintParams {
        // Minimum amount of synthetic tokens that a user wants to mint using collateral (anti-slippage)
        uint256 minNumTokens;
        // Amount of collateral that a user wants to spend for minting
        uint256 collateralAmount;
        // Expiration time of the transaction
        uint256 expiration;
        // Address to which send synthetic tokens minted
        address recipient;
    }

    struct RedeemParams {
        // Amount of synthetic tokens that user wants to use for redeeming
        uint256 numTokens;
        // Minimium amount of collateral that user wants to redeem (anti-slippage)
        uint256 minCollateral;
        // Expiration time of the transaction
        uint256 expiration;
        // Address to which send collateral tokens redeemed
        address recipient;
    }

    struct ExchangeParams {
        // Derivative of source pool
        address derivative;
        // Destination pool
        address destPool;
        // Derivative of destination pool
        address destDerivative;
        // Amount of source synthetic tokens that user wants to use for exchanging
        uint256 numTokens;
        // Minimum Amount of destination synthetic tokens that user wants to receive (anti-slippage)
        uint256 minDestNumTokens;
        // Maximum amount of fees in percentage that user is willing to pay
        uint256 feePercentage;
        // Expiration time of the transaction
        uint256 expiration;
        // Address to which send synthetic tokens exchanged
        address recipient;
    }

    /**
     * @notice Mint synthetic tokens using fixed amount of collateral
     * @notice This calculate the price using on chain price feed
     * @notice User must approve collateral transfer for the mint request to succeed
     * @param mintParams Input parameters for minting (see MintParams struct)
     * @return syntheticTokensMinted Amount of synthetic tokens minted by a user
     * @return feePaid Amount of collateral paid by the user as fee
     */
    function mint(MintParams calldata mintParams) external returns (uint256 syntheticTokensMinted, uint256 feePaid);

    /**
     * @notice Redeem amount of collateral using fixed number of synthetic token
     * @notice This calculate the price using on chain price feed
     * @notice User must approve synthetic token transfer for the redeem request to succeed
     * @param redeemParams Input parameters for redeeming (see RedeemParams struct)
     * @return collateralRedeemed Amount of collateral redeem by user
     * @return feePaid Amount of collateral paid by user as fee
     */
    function redeem(RedeemParams calldata redeemParams) external returns (uint256 collateralRedeemed, uint256 feePaid);

    function syntheticToken() external view returns (address);

    function getAllDerivatives() external view returns (address[] memory);

    function getFeeInfo()
        external
        view
        returns (
            uint256,
            address,
            address,
            uint256,
            uint256
        );

    /**
     * @notice Exchange a fixed amount of synthetic token of this pool, with an amount of synthetic tokens of an another pool
     * @notice This calculate the price using on chain price feed
     * @notice User must approve synthetic token transfer for the redeem request to succeed
     * @param exchangeParams Input parameters for exchanging (see ExchangeParams struct)
     * @return destNumTokensMinted Amount of collateral redeem by user
     * @return feePaid Amount of collateral paid by user as fee
     */
    function exchange(ExchangeParams calldata exchangeParams)
        external
        returns (uint256 destNumTokensMinted, uint256 feePaid);
}

interface IDerivative {
    function tokenCurrency() external view returns (address);

    function getPoolMembers() external view returns (address[] memory);
}
