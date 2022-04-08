// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

interface ICurveExchange {
    function get_registry() external view returns (address);

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
