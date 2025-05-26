// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {IStrategy} from "@tokenized-strategy/interfaces/IStrategy.sol";

interface IStrategyInterface is IStrategy {
    function v2Vault() external view returns (address);

    function balanceOfAsset() external view returns (uint256);

    function balanceOfVault() external view returns (uint256);

    function valueOfVault() external view returns (uint256);
}
