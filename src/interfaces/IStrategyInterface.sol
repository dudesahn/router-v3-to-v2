// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IBaseHealthCheck} from "@periphery/Bases/HealthCheck/IBaseHealthCheck.sol";

interface IStrategyInterface is IBaseHealthCheck {
    function V2_VAULT() external view returns (address);

    function balanceOfAsset() external view returns (uint256);

    function balanceOfVault() external view returns (uint256);

    function valueOfVault() external view returns (uint256);

    function claimableProfits() external view returns (uint256);

    function setAllowed(address _address, bool _allowed) external;

    function setMaxLoss(uint256 _maxLoss) external;
}
